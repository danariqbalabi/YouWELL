-- Phase 6: editable alias + companion name, authors deleting their posts
-- (and no longer reacting to them),
-- and participant codes assigned by admins. Run after phase 5.
-- Only reactions that authors left on their own posts are removed.
begin;

-- ---------------------------------------------------------------------------
-- Sync accepts profile.companionName (1-20 characters) and keeps the alias
-- on the author's Community posts in step when the alias is edited.
create or replace function public.save_youwell_progress(
  p_payload jsonb, p_expected_revision bigint
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  caller uuid := (select auth.uid());
  existing public.youwell_progress%rowtype;
  profile jsonb;
  field text;
begin
  if caller is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  if p_expected_revision is null or p_expected_revision < 0 then
    raise exception 'Invalid revision' using errcode = '22023';
  end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object'
     or octet_length(p_payload::text) > 2097152
     or (p_payload->>'schemaVersion') is distinct from '1'
     or (p_payload->>'version') is distinct from '3' then
    raise exception 'Invalid progress schema or payload size' using errcode = '22023';
  end if;
  if p_payload - array[
    'schemaVersion','version','profile','days','capacity','mobileRewards',
    'achievements','openedDays','activityDays','levelFloor','themeMode',
    'reduceMotion','haptics','companionAccessory','companionBackground',
    'workoutSessions','mealCheckIns','habitDelays','habitSwaps'
  ] <> '{}'::jsonb or not private.youwell_cloud_fields_safe(p_payload) then
    raise exception 'Device-only or unknown fields are not allowed' using errcode = '22023';
  end if;
  foreach field in array array['days','capacity','mobileRewards','achievements'] loop
    if jsonb_typeof(p_payload->field) is distinct from 'object' then
      raise exception 'Invalid progress map: %', field using errcode = '22023';
    end if;
  end loop;
  foreach field in array array['openedDays','activityDays','workoutSessions','mealCheckIns','habitDelays','habitSwaps'] loop
    if jsonb_typeof(p_payload->field) is distinct from 'array' then
      raise exception 'Invalid progress list: %', field using errcode = '22023';
    end if;
  end loop;
  profile := p_payload->'profile';
  if profile is null then raise exception 'Profile field required' using errcode = '22023'; end if;
  if profile <> 'null'::jsonb then
    if jsonb_typeof(profile) <> 'object'
       or profile - array['alias','path','pace','lowImpact','companion','started','waterGoal','ageGroup','companionName'] <> '{}'::jsonb
       or coalesce(profile->>'alias','') !~ '^[a-zA-Z][a-zA-Z0-9_]{2,19}$'
       or coalesce(profile->>'path','') not in ('wellness','reduction')
       or (profile ? 'companionName' and (
             jsonb_typeof(profile->'companionName') <> 'string'
             or char_length(btrim(profile->>'companionName')) not between 1 and 20
             or profile->>'companionName' ~ '[[:cntrl:]]'
          )) then
      raise exception 'Invalid profile' using errcode = '22023';
    end if;
  end if;

  -- Serialize even the first insert, where there is no row to lock yet.
  perform pg_advisory_xact_lock(hashtextextended(caller::text, 0));
  select * into existing from public.youwell_progress where user_id = caller for update;
  if coalesce(existing.revision, 0) <> p_expected_revision then
    if existing.revision is null then
      return jsonb_build_object('saved', false, 'snapshot', null);
    end if;
    return jsonb_build_object('saved', false, 'snapshot',
      jsonb_build_object('revision', existing.revision, 'payload', existing.payload, 'updated_at', existing.updated_at));
  end if;

  insert into public.youwell_progress as target(user_id, revision, payload, updated_at)
  values(caller, p_expected_revision + 1, p_payload, now())
  on conflict (user_id) do update
    set revision = excluded.revision, payload = excluded.payload, updated_at = excluded.updated_at
  returning * into existing;

  if profile = 'null'::jsonb then
    -- Explicit "reset synced progress" clears only the caller's profile,
    -- not the auth account, allowlist, other participants or research data.
    delete from public.youwell_profiles where user_id = caller;
  else
    insert into public.youwell_profiles(user_id, alias)
    values(caller, profile->>'alias')
    on conflict (user_id) do update set alias = excluded.alias;
    -- An edited alias also renames the author's own posts.
    update public.youwell_posts set alias = profile->>'alias'
    where author = caller and alias is distinct from profile->>'alias';
  end if;
  return jsonb_build_object('saved', true, 'snapshot',
    jsonb_build_object('revision', existing.revision, 'payload', existing.payload, 'updated_at', existing.updated_at));
end;
$$;
revoke all on function public.save_youwell_progress(jsonb,bigint) from public, anon, authenticated;
grant execute on function public.save_youwell_progress(jsonb,bigint) to authenticated;

-- ---------------------------------------------------------------------------
-- Authors delete their own post. Reactions and reports go with it (cascade).
-- Returns the photo path so the app can delete the file as well.
create or replace function public.delete_youwell_post(p_post uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare
  caller uuid := (select auth.uid());
  photo text;
begin
  if caller is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  delete from public.youwell_posts
  where id = p_post and author = caller
  returning image_path into photo;
  if not found then raise exception 'Post not available' using errcode = 'P0002'; end if;
  return photo;
end;
$$;
revoke all on function public.delete_youwell_post(uuid) from public, anon, authenticated;
grant execute on function public.delete_youwell_post(uuid) to authenticated;

-- Authors cannot react to their own posts; any reaction they left is removed.
delete from public.youwell_reactions r
using public.youwell_posts p
where p.id = r.post_id and p.author = r.user_id;

create or replace function public.react_youwell_post(p_post uuid, p_reaction text)
returns void language plpgsql security definer set search_path = '' as $$
declare caller uuid := (select auth.uid());
begin
  if caller is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  if not exists (select 1 from public.youwell_posts
                 where id = p_post and status = 'approved' and author <> caller) then
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
revoke all on function public.react_youwell_post(uuid, text) from public, anon, authenticated;
grant execute on function public.react_youwell_post(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Participant codes P1-P10, assigned by admins in the researcher dashboard
-- (team decision 16 Oct 2026; consent is collected on paper per proposal).
create table if not exists public.youwell_participant_codes (
  user_id uuid primary key references auth.users(id) on delete cascade,
  code text not null unique check (code ~ '^P([1-9]|10)$'),
  assigned_at timestamptz not null default now()
);
alter table public.youwell_participant_codes enable row level security;
revoke all on public.youwell_participant_codes from public, anon, authenticated;

-- p_code null removes the account's code.
create or replace function public.set_youwell_participant_code(
  p_account uuid, p_code text
)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform private.youwell_require_admin();
  if p_code is null then
    delete from public.youwell_participant_codes where user_id = p_account;
    return;
  end if;
  if p_code !~ '^P([1-9]|10)$' then
    raise exception 'Invalid participant code' using errcode = '22023';
  end if;
  if exists (select 1 from public.youwell_participant_codes
             where code = p_code and user_id <> p_account) then
    raise exception 'Code already assigned' using errcode = '23505';
  end if;
  insert into public.youwell_participant_codes(user_id, code)
  values (p_account, p_code)
  on conflict (user_id) do update set code = excluded.code, assigned_at = now();
end;
$$;
revoke all on function public.set_youwell_participant_code(uuid, text) from public, anon, authenticated;
grant execute on function public.set_youwell_participant_code(uuid, text) to authenticated;

-- The dashboard overview now carries an account key (for assigning codes)
-- and the assigned code.
create or replace function public.youwell_admin_progress_overview()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.youwell_require_admin();
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'account', p.user_id,
      'code', c.code,
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
    ) order by c.code nulls last, p.updated_at desc)
    from public.youwell_progress p
    left join public.youwell_profiles pr on pr.user_id = p.user_id
    left join public.youwell_participant_codes c on c.user_id = p.user_id
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.youwell_admin_progress_overview() from public, anon, authenticated;
grant execute on function public.youwell_admin_progress_overview() to authenticated;

commit;
