-- Phase 3: moderated Community, weekly research logs, account deletion, and
-- a stricter progress privacy filter. Run after the phase 1 and 2 migrations.
-- No existing data is deleted.
--
-- Every table below is reachable only through the functions in this file:
-- no direct table privileges are granted, so RLS has no policies to get
-- wrong and clients cannot read user IDs, reporters, or other people's rows.
begin;

-- ---------------------------------------------------------------------------
-- Progress privacy: raw smoking/vaping data must never reach the server
-- (CLAUDE.md §6). The client strips these keys; the server rejects them too.
create or replace function private.youwell_cloud_fields_safe(value jsonb)
returns boolean language plpgsql immutable set search_path = '' as $$
declare entry record;
begin
  if jsonb_typeof(value) = 'object' then
    for entry in select * from jsonb_each(value) loop
      if lower(entry.key) = any(array[
        'photopath','photo','image','bytes','base64','latitude','longitude',
        'coordinates','route','note','noteeditedat','email','user_id',
        'researchparticipation','participant_code','access_token','refresh_token',
        'product','trigger','outcome','activity','eventid','cigarette','vape',
        'nicotinedays','reductionsettings','reductionplans','reductiontargets'
      ]) or not private.youwell_cloud_fields_safe(entry.value) then
        return false;
      end if;
    end loop;
  elsif jsonb_typeof(value) = 'array' then
    for entry in select jsonb_array_elements(value) as item loop
      if not private.youwell_cloud_fields_safe(entry.item) then return false; end if;
    end loop;
  end if;
  return true;
end;
$$;
revoke all on function private.youwell_cloud_fields_safe(jsonb) from public, anon, authenticated;

-- Raises unless the caller is an allowlisted Google admin with MFA (AAL2).
create or replace function private.youwell_require_admin()
returns void language plpgsql stable security definer set search_path = '' as $$
begin
  if public.youwell_admin_access() <> 'allowed' then
    raise exception 'Admin access required' using errcode = '42501';
  end if;
end;
$$;
revoke all on function private.youwell_require_admin() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Community: alias-only posts, pre-moderated; reactions as aggregate counts.
create table if not exists public.youwell_posts (
  id uuid primary key default gen_random_uuid(),
  author uuid not null references auth.users(id) on delete cascade,
  alias text not null,
  body text not null check (char_length(body) between 3 and 280),
  status text not null default 'pending'
    check (status in ('pending','approved','rejected')),
  moderation_note text check (char_length(moderation_note) <= 200),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);
create index if not exists youwell_posts_status_created
  on public.youwell_posts(status, created_at desc);
create index if not exists youwell_posts_author on public.youwell_posts(author);

create table if not exists public.youwell_reactions (
  post_id uuid not null references public.youwell_posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  reaction text not null check (reaction in ('👏','🌱','✨')),
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create table if not exists public.youwell_reports (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.youwell_posts(id) on delete cascade,
  reporter uuid not null references auth.users(id) on delete cascade,
  reason text not null check (reason in ('unsafe','spam')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  unique (post_id, reporter)
);

alter table public.youwell_posts enable row level security;
alter table public.youwell_reactions enable row level security;
alter table public.youwell_reports enable row level security;
revoke all on public.youwell_posts, public.youwell_reactions, public.youwell_reports
  from public, anon, authenticated;

-- Approved posts plus the caller's own posts, newest first. Author IDs and
-- reporters are never returned; reactions are counts plus the caller's own.
create or replace function public.youwell_community_feed()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(item order by created_at desc), '[]'::jsonb)
  from (
    select p.created_at, jsonb_build_object(
      'id', p.id,
      'alias', p.alias,
      'body', p.body,
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

-- The alias comes from the caller's synced profile, never from the client.
create or replace function public.submit_youwell_post(p_body text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  caller uuid := (select auth.uid());
  caller_alias text;
  clean text := btrim(coalesce(p_body, ''));
  created uuid;
begin
  if caller is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  if char_length(clean) not between 3 and 280 then
    raise exception 'Post must be 3-280 characters' using errcode = '22023';
  end if;
  select alias into caller_alias from public.youwell_profiles where user_id = caller;
  if caller_alias is null then
    raise exception 'Profile not synced yet' using errcode = 'P0002';
  end if;
  -- A small queue cap keeps one account from flooding moderators.
  if (select count(*) from public.youwell_posts
      where author = caller and status = 'pending') >= 3 then
    raise exception 'Too many posts waiting for review' using errcode = '54000';
  end if;
  insert into public.youwell_posts(author, alias, body)
  values (caller, caller_alias, clean) returning id into created;
  return created;
end;
$$;

-- p_reaction null removes the caller's reaction. Only approved posts.
create or replace function public.react_youwell_post(p_post uuid, p_reaction text)
returns void language plpgsql security definer set search_path = '' as $$
declare caller uuid := (select auth.uid());
begin
  if caller is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  if not exists (select 1 from public.youwell_posts where id = p_post and status = 'approved') then
    raise exception 'Post not available' using errcode = 'P0002';
  end if;
  if p_reaction is null then
    delete from public.youwell_reactions where post_id = p_post and user_id = caller;
  else
    insert into public.youwell_reactions(post_id, user_id, reaction)
    values (p_post, caller, p_reaction)
    on conflict (post_id, user_id) do update set reaction = excluded.reaction, created_at = now();
  end if;
end;
$$;

-- Returns false when the caller already reported this post.
create or replace function public.report_youwell_post(p_post uuid, p_reason text)
returns boolean language plpgsql security definer set search_path = '' as $$
declare caller uuid := (select auth.uid());
begin
  if caller is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  if not exists (select 1 from public.youwell_posts where id = p_post and status = 'approved') then
    raise exception 'Post not available' using errcode = 'P0002';
  end if;
  insert into public.youwell_reports(post_id, reporter, reason)
  values (p_post, caller, p_reason)
  on conflict (post_id, reporter) do nothing;
  return found;
end;
$$;

-- Moderator view: pending posts and open reports, without any user IDs.
create or replace function public.youwell_moderation_queue()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.youwell_require_admin();
  return jsonb_build_object(
    'pending', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', p.id, 'alias', p.alias, 'body', p.body, 'created_at', p.created_at
      ) order by p.created_at)
      from public.youwell_posts p where p.status = 'pending'
    ), '[]'::jsonb),
    'reports', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', r.id, 'post_id', r.post_id, 'reason', r.reason,
        'created_at', r.created_at, 'alias', p.alias, 'body', p.body,
        'status', p.status
      ) order by r.created_at)
      from public.youwell_reports r join public.youwell_posts p on p.id = r.post_id
      where r.resolved_at is null
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function public.moderate_youwell_post(
  p_post uuid, p_status text, p_note text default null
)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform private.youwell_require_admin();
  if p_status not in ('approved','rejected') then
    raise exception 'Invalid status' using errcode = '22023';
  end if;
  update public.youwell_posts
  set status = p_status, moderation_note = nullif(btrim(coalesce(p_note, '')), ''),
      reviewed_at = now()
  where id = p_post;
  if not found then raise exception 'Post not found' using errcode = 'P0002'; end if;
  -- Hiding a reported post settles its open reports in the same step.
  if p_status = 'rejected' then
    update public.youwell_reports set resolved_at = now()
    where post_id = p_post and resolved_at is null;
  end if;
end;
$$;

create or replace function public.resolve_youwell_report(p_report uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform private.youwell_require_admin();
  update public.youwell_reports set resolved_at = now()
  where id = p_report and resolved_at is null;
end;
$$;

revoke all on function public.youwell_community_feed() from public, anon, authenticated;
revoke all on function public.submit_youwell_post(text) from public, anon, authenticated;
revoke all on function public.react_youwell_post(uuid, text) from public, anon, authenticated;
revoke all on function public.report_youwell_post(uuid, text) from public, anon, authenticated;
revoke all on function public.youwell_moderation_queue() from public, anon, authenticated;
revoke all on function public.moderate_youwell_post(uuid, text, text) from public, anon, authenticated;
revoke all on function public.resolve_youwell_report(uuid) from public, anon, authenticated;
grant execute on function public.youwell_community_feed() to authenticated;
grant execute on function public.submit_youwell_post(text) to authenticated;
grant execute on function public.react_youwell_post(uuid, text) to authenticated;
grant execute on function public.report_youwell_post(uuid, text) to authenticated;
grant execute on function public.youwell_moderation_queue() to authenticated;
grant execute on function public.moderate_youwell_post(uuid, text, text) to authenticated;
grant execute on function public.resolve_youwell_report(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Research logs (CLAUDE.md §3.6): numbers and a P1-P10 code only.
-- Deliberately no user_id, email, alias, free text, photo, or location.
-- Insert-only for participants; read it from the dashboard (one researcher).
-- A week can be sent again while it is still running; analyse the latest
-- row per (participant_code, week).
create table if not exists public.youwell_research_logs (
  id bigserial primary key,
  participant_code text not null check (participant_code ~ '^P([1-9]|10)$'),
  week int not null check (week between 1 and 4),
  week_complete boolean not null,
  opened_days int not null check (opened_days between 0 and 7),
  active_days int not null check (active_days between 0 and 7),
  active boolean not null,
  quests_done int not null check (quests_done between 0 and 500),
  ladder_gerak int check (ladder_gerak between 1 and 10),
  ladder_istirahat int check (ladder_istirahat between 1 and 10),
  ladder_tidur int check (ladder_tidur between 1 and 10),
  ladder_hidrasi int check (ladder_hidrasi between 1 and 10),
  ladder_makan int check (ladder_makan between 1 and 10),
  ladder_jeda int check (ladder_jeda between 1 and 10),
  delay_craving_count int not null check (delay_craving_count between 0 and 1000),
  delay_craving_completed int not null check (delay_craving_completed between 0 and 1000),
  habit_swap_count int not null check (habit_swap_count between 0 and 1000),
  submitted_at timestamptz not null default now()
);
alter table public.youwell_research_logs enable row level security;
revoke all on public.youwell_research_logs from public, anon, authenticated;
revoke all on sequence public.youwell_research_logs_id_seq from public, anon, authenticated;

create or replace function public.submit_youwell_research_log(
  p_code text, p_week_complete boolean, p_summary jsonb
)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if p_summary is null or jsonb_typeof(p_summary) <> 'object' or p_summary - array[
    'week','opened_days','active_days','active','quests_done','ladder_gerak',
    'ladder_istirahat','ladder_tidur','ladder_hidrasi','ladder_makan',
    'ladder_jeda','delay_craving_count','delay_craving_completed','habit_swap_count'
  ] <> '{}'::jsonb then
    raise exception 'Only the agreed summary columns are accepted' using errcode = '22023';
  end if;
  insert into public.youwell_research_logs(
    participant_code, week, week_complete, opened_days, active_days, active,
    quests_done, ladder_gerak, ladder_istirahat, ladder_tidur, ladder_hidrasi,
    ladder_makan, ladder_jeda, delay_craving_count, delay_craving_completed,
    habit_swap_count
  ) values (
    p_code, (p_summary->>'week')::int, coalesce(p_week_complete, false),
    (p_summary->>'opened_days')::int, (p_summary->>'active_days')::int,
    (p_summary->>'active')::boolean, (p_summary->>'quests_done')::int,
    (p_summary->>'ladder_gerak')::int, (p_summary->>'ladder_istirahat')::int,
    (p_summary->>'ladder_tidur')::int, (p_summary->>'ladder_hidrasi')::int,
    (p_summary->>'ladder_makan')::int, (p_summary->>'ladder_jeda')::int,
    (p_summary->>'delay_craving_count')::int,
    (p_summary->>'delay_craving_completed')::int,
    (p_summary->>'habit_swap_count')::int
  );
end;
$$;
revoke all on function public.submit_youwell_research_log(text, boolean, jsonb) from public, anon, authenticated;
grant execute on function public.submit_youwell_research_log(text, boolean, jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- Account deletion (UU PDP Pasal 8 & 9). Deleting the auth user cascades to
-- profiles, progress, posts, reactions and reports. Research logs hold no
-- user link and are deleted after analysis, as stated in the proposal.
create or replace function public.delete_youwell_account()
returns void language plpgsql security definer set search_path = '' as $$
declare caller uuid := (select auth.uid());
begin
  if caller is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  delete from auth.users where id = caller;
end;
$$;
revoke all on function public.delete_youwell_account() from public, anon, authenticated;
grant execute on function public.delete_youwell_account() to authenticated;

commit;
