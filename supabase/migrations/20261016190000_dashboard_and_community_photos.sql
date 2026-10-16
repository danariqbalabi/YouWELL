-- Phase 5: researcher dashboard and Community photos. Run after phase 4.
-- No existing data is deleted.
--
-- Part A, dashboard: admins (allowlist + MFA) read every participant's
-- synced progress by alias. Read-only.
--
-- Team decision 16 Oct 2026: this widens admin access beyond the proposal
-- (Tabel 3.3 / §3.7), so the proposal and consent form must say so.
-- Only what sync already holds is returned: no email, user_id, photo, note,
-- route, or raw smoking/vaping data ever reaches the server. Each day is
-- reduced to the fields the dashboard counts.
begin;

create or replace function public.youwell_admin_progress_overview()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.youwell_require_admin();
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'alias', coalesce(pr.alias, p.payload->'profile'->>'alias'),
      'updated_at', p.updated_at,
      'payload', (p.payload - 'days') || jsonb_build_object('days', coalesce((
        select jsonb_object_agg(d.key, jsonb_strip_nulls(jsonb_build_object(
          'quests', d.value->'quests',
          'water', d.value->'water',
          'ladderSteps', d.value->'ladderSteps'
        )))
        from jsonb_each(p.payload->'days') d
      ), '{}'::jsonb))
    ) order by p.updated_at desc)
    from public.youwell_progress p
    left join public.youwell_profiles pr on pr.user_id = p.user_id
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.youwell_admin_progress_overview() from public, anon, authenticated;
grant execute on function public.youwell_admin_progress_overview() to authenticated;

-- ---------------------------------------------------------------------------
-- Part B, Community photos. One optional photo per post, in a PRIVATE
-- bucket. The app re-encodes every photo to PNG first, which drops EXIF
-- metadata such as GPS location. A photo is readable by its author and by
-- admins, and by everyone signed in once its post is approved. Objects live
-- at '<author uid>/<random uuid>.png'.
alter table public.youwell_posts add column if not exists image_path text;

-- The posts table intentionally has no client SELECT grant. Check photo
-- visibility through a narrow definer function instead of a policy subquery
-- that would fail with permission denied for authenticated users.
create or replace function public.youwell_community_photo_readable(p_name text)
returns boolean language sql stable security definer set search_path = '' as $$
  select (select auth.uid()) is not null and (
    (storage.foldername(p_name))[1] = (select auth.uid())::text
    or exists (
      select 1 from public.youwell_posts p
      where p.image_path = p_name and p.status = 'approved'
    )
    or public.youwell_admin_access() = 'allowed'
  );
$$;
revoke all on function public.youwell_community_photo_readable(text) from public, anon, authenticated;
grant execute on function public.youwell_community_photo_readable(text) to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('community', 'community', false, 3145728, array['image/png'])
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Community photo upload own folder" on storage.objects;
create policy "Community photo upload own folder" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'community'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "Community photo read" on storage.objects;
create policy "Community photo read" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'community'
    and public.youwell_community_photo_readable(name)
  );

drop policy if exists "Community photo delete own or admin" on storage.objects;
create policy "Community photo delete own or admin" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'community'
    and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or public.youwell_admin_access() = 'allowed'
    )
  );

alter table public.youwell_posts drop constraint if exists youwell_posts_body_check;
alter table public.youwell_posts drop constraint if exists youwell_posts_body_or_photo;
-- With a photo the caption is optional; without one it needs 3+ characters.
alter table public.youwell_posts add constraint youwell_posts_body_or_photo check (
  char_length(body) <= 280
  and (image_path is not null or char_length(body) >= 3)
);

create or replace function public.youwell_community_feed()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(item order by created_at desc), '[]'::jsonb)
  from (
    select p.created_at, jsonb_build_object(
      'id', p.id,
      'alias', p.alias,
      'body', p.body,
      'image_path', p.image_path,
      'status', p.status,
      'moderation_note', case when p.author = (select auth.uid()) then p.moderation_note end,
      'created_at', p.created_at,
      'mine', p.author = (select auth.uid()),
      'reactions', coalesce((
        select jsonb_object_agg(r.reaction, r.total)
        from (select reaction, count(*) as total from public.youwell_reactions
              where post_id = p.id group by reaction) r
      ), '{}'::jsonb),
      'my_reaction', (select reaction from public.youwell_reactions
                      where post_id = p.id and user_id = (select auth.uid())),
      'reported', exists (select 1 from public.youwell_reports
                          where post_id = p.id and reporter = (select auth.uid()))
    ) as item
    from public.youwell_posts p
    where (select auth.uid()) is not null
      and (p.status = 'approved' or p.author = (select auth.uid()))
    order by p.created_at desc
    limit 100
  ) feed;
$$;

drop function if exists public.submit_youwell_post(text);
create or replace function public.submit_youwell_post(
  p_body text, p_image_path text default null
)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  caller uuid := (select auth.uid());
  caller_alias text;
  clean text := btrim(coalesce(p_body, ''));
  created uuid;
begin
  if caller is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  if char_length(clean) > 280 or (p_image_path is null and char_length(clean) < 3) then
    raise exception 'Post must be 3-280 characters' using errcode = '22023';
  end if;
  if p_image_path is not null and (
    p_image_path !~ ('^' || caller::text || '/[0-9a-f-]{36}\.png$')
    or not exists (select 1 from storage.objects o
                   where o.bucket_id = 'community' and o.name = p_image_path)
  ) then
    raise exception 'Photo not uploaded by this account' using errcode = '22023';
  end if;
  select alias into caller_alias from public.youwell_profiles where user_id = caller;
  if caller_alias is null then
    raise exception 'Profile not synced yet' using errcode = 'P0002';
  end if;
  if (select count(*) from public.youwell_posts
      where author = caller and status = 'pending') >= 3 then
    raise exception 'Too many posts waiting for review' using errcode = '54000';
  end if;
  insert into public.youwell_posts(author, alias, body, image_path)
  values (caller, caller_alias, clean, p_image_path) returning id into created;
  return created;
end;
$$;

create or replace function public.youwell_moderation_queue()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.youwell_require_admin();
  return jsonb_build_object(
    'pending', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', p.id, 'alias', p.alias, 'body', p.body,
        'image_path', p.image_path, 'created_at', p.created_at
      ) order by p.created_at)
      from public.youwell_posts p where p.status = 'pending'
    ), '[]'::jsonb),
    'reports', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', r.id, 'post_id', r.post_id, 'reason', r.reason,
        'created_at', r.created_at, 'alias', p.alias, 'body', p.body,
        'image_path', p.image_path, 'status', p.status
      ) order by r.created_at)
      from public.youwell_reports r join public.youwell_posts p on p.id = r.post_id
      where r.resolved_at is null
    ), '[]'::jsonb)
  );
end;
$$;

-- Now returns the photo path of a rejected post, so the admin app can delete
-- the file (storage files cannot be removed from SQL).
drop function if exists public.moderate_youwell_post(uuid, text, text);
create or replace function public.moderate_youwell_post(
  p_post uuid, p_status text, p_note text default null
)
returns text language plpgsql security definer set search_path = '' as $$
declare photo text;
begin
  perform private.youwell_require_admin();
  if p_status not in ('approved','rejected') then
    raise exception 'Invalid status' using errcode = '22023';
  end if;
  select image_path into photo from public.youwell_posts where id = p_post for update;
  if not found then raise exception 'Post not found' using errcode = 'P0002'; end if;
  update public.youwell_posts
  set status = p_status, moderation_note = nullif(btrim(coalesce(p_note, '')), ''),
      reviewed_at = now(),
      image_path = case when p_status = 'rejected' then null else image_path end
  where id = p_post;
  if p_status = 'rejected' then
    update public.youwell_reports set resolved_at = now()
    where post_id = p_post and resolved_at is null;
    return photo;
  end if;
  return null;
end;
$$;

revoke all on function public.youwell_community_feed() from public, anon, authenticated;
revoke all on function public.submit_youwell_post(text, text) from public, anon, authenticated;
revoke all on function public.youwell_moderation_queue() from public, anon, authenticated;
revoke all on function public.moderate_youwell_post(uuid, text, text) from public, anon, authenticated;
grant execute on function public.youwell_community_feed() to authenticated;
grant execute on function public.submit_youwell_post(text, text) to authenticated;
grant execute on function public.youwell_moderation_queue() to authenticated;
grant execute on function public.moderate_youwell_post(uuid, text, text) to authenticated;

commit;
