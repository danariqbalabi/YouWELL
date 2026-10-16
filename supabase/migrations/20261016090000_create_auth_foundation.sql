-- Phase 1: identity and moderator authorization only.
-- No existing table, auth user or participant data is deleted.
begin;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

-- Managed only by trusted SQL/service-side operations. Never by the app.
create table if not exists private.youwell_admins (
  email text primary key check (email = lower(btrim(email))),
  created_at timestamptz not null default now()
);
alter table private.youwell_admins enable row level security;
revoke all on private.youwell_admins from public, anon, authenticated;

-- No real Google name/email and no admin role in the participant profile.
create table if not exists public.youwell_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  alias text not null check (char_length(alias) between 2 and 30),
  created_at timestamptz not null default now()
);
alter table public.youwell_profiles enable row level security;
revoke all on public.youwell_profiles from public, anon, authenticated;
grant select, insert on public.youwell_profiles to authenticated;
grant update (alias) on public.youwell_profiles to authenticated;

drop policy if exists "Read own alias" on public.youwell_profiles;
create policy "Read own alias" on public.youwell_profiles for select
  to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "Insert own alias" on public.youwell_profiles;
create policy "Insert own alias" on public.youwell_profiles for insert
  to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "Update own alias" on public.youwell_profiles;
create policy "Update own alias" on public.youwell_profiles for update
  to authenticated using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- Returns only the caller's access. It never reveals the whitelist.
-- This is authorization groundwork, not a substitute for policies on future
-- posts/reactions/reports tables: every moderation operation must check AAL2.
create or replace function public.youwell_admin_access()
returns text language sql stable security definer set search_path = '' as $$
  select case
    when not exists (
      select 1 from private.youwell_admins a
      join auth.users u on lower(u.email) = a.email
      where u.id = (select auth.uid())
        and u.email_confirmed_at is not null
        and exists (select 1 from auth.identities i
                    where i.user_id = u.id and i.provider = 'google')
    ) then 'denied'
    when (select auth.jwt()->>'aal') = 'aal2' then 'allowed'
    else 'needs_mfa'
  end;
$$;
revoke all on function public.youwell_admin_access() from public, anon, authenticated;
grant execute on function public.youwell_admin_access() to authenticated;

commit;
