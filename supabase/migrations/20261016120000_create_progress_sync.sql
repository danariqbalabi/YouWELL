-- Phase 2: per-account progress snapshots and optimistic concurrency.
-- Run after 20261016090000_create_auth_foundation.sql. No existing data is deleted.
begin;

create table if not exists public.youwell_progress (
  user_id uuid primary key references auth.users(id) on delete cascade,
  revision bigint not null check (revision > 0),
  payload jsonb not null check (jsonb_typeof(payload) = 'object'),
  updated_at timestamptz not null default now()
);
alter table public.youwell_progress enable row level security;
revoke all on public.youwell_progress from public, anon, authenticated;
grant select on public.youwell_progress to authenticated;
drop policy if exists "Read own progress" on public.youwell_progress;
create policy "Read own progress" on public.youwell_progress for select
  to authenticated using ((select auth.uid()) = user_id);

-- Recursively reject fields which must stay on the device. This helper is
-- private and not callable from the Data API.
create or replace function private.youwell_cloud_fields_safe(value jsonb)
returns boolean language plpgsql immutable set search_path = '' as $$
declare entry record;
begin
  if jsonb_typeof(value) = 'object' then
    for entry in select * from jsonb_each(value) loop
      if lower(entry.key) = any(array[
        'photopath','photo','image','bytes','base64','latitude','longitude',
        'coordinates','route','note','noteeditedat','email','user_id',
        'researchparticipation','participant_code','access_token','refresh_token'
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

-- No user ID argument: identity always comes from the signed JWT.
-- All writes (including the alias) are one transaction. Direct table writes
-- are not granted, so clients cannot bypass revision checking.
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
       or profile - array['alias','path','pace','lowImpact','companion','started','waterGoal','ageGroup'] <> '{}'::jsonb
       or coalesce(profile->>'alias','') !~ '^[a-zA-Z][a-zA-Z0-9_]{2,19}$'
       or coalesce(profile->>'path','') not in ('wellness','reduction') then
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
  end if;
  return jsonb_build_object('saved', true, 'snapshot',
    jsonb_build_object('revision', existing.revision, 'payload', existing.payload, 'updated_at', existing.updated_at));
end;
$$;
revoke all on function public.save_youwell_progress(jsonb,bigint) from public, anon, authenticated;
grant execute on function public.save_youwell_progress(jsonb,bigint) to authenticated;

-- Alias is now written atomically with its progress snapshot via the RPC.
-- Read-own policy from migration 1 remains; no direct client writes.
revoke insert, update on public.youwell_profiles from authenticated;
revoke update (alias) on public.youwell_profiles from authenticated;

commit;
