// Run from the repo root after installing the isolated test dependency:
// npm install --prefix .tools/sql-check --no-audit --no-fund @electric-sql/pglite
// node scripts/check-supabase-migrations.cjs
// Uses an in-memory PostgreSQL database, never a real Supabase project.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { PGlite } = require('../.tools/sql-check/node_modules/@electric-sql/pglite');

const owner = '11111111-1111-4111-8111-111111111111';
const reader = '22222222-2222-4222-8222-222222222222';
const admin = '33333333-3333-4333-8333-333333333333';
const approved = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const pending = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

async function main() {
  const db = await PGlite.create();
  try {
    // Only the Auth/Storage interfaces referenced by our migrations are mocked.
    // Roles, grants, RLS and SECURITY DEFINER use PostgreSQL's real behavior.
    await db.exec(`
      create role anon;
      create role authenticated;
      create schema auth;
      create schema storage;
      create table auth.users (
        id uuid primary key, email text, email_confirmed_at timestamptz
      );
      create table auth.identities (
        user_id uuid references auth.users(id) on delete cascade, provider text
      );
      create function auth.uid() returns uuid language sql stable as $$
        select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
      $$;
      create function auth.jwt() returns jsonb language sql stable as $$
        select coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb;
      $$;
      create table storage.buckets (
        id text primary key, name text, public boolean,
        file_size_limit bigint, allowed_mime_types text[]
      );
      create table storage.objects (
        id uuid primary key default gen_random_uuid(),
        bucket_id text references storage.buckets(id), name text
      );
      create function storage.foldername(name text) returns text[]
      language sql immutable as $$
        select (string_to_array(name, '/'))[1:array_length(string_to_array(name, '/'), 1) - 1];
      $$;
      alter table storage.objects enable row level security;
      grant usage on schema auth, storage to anon, authenticated;
      grant select, insert, delete on storage.objects to authenticated;
    `);
    const migrations = path.join(__dirname, '../supabase/migrations');
    for (const file of fs.readdirSync(migrations).filter(f => f.endsWith('.sql')).sort()) {
      await db.exec(fs.readFileSync(path.join(migrations, file), 'utf8'));
      console.log(`Migration passed: ${file}`);
    }
    await db.exec(`
      insert into auth.users(id, email, email_confirmed_at) values
        ('${owner}', 'owner@example.test', now()),
        ('${reader}', 'reader@example.test', now()),
        ('${admin}', 'admin@example.test', now());
      insert into auth.identities values ('${admin}', 'google');
      insert into private.youwell_admins(email) values ('admin@example.test');
      insert into storage.buckets(id, name, public) values ('other', 'other', false);
      insert into storage.objects(bucket_id, name) values
        ('community', '${owner}/approved.png'),
        ('community', '${owner}/pending.png'),
        ('community', '${owner}/orphan.png'),
        ('other', '${owner}/secret.png');
      insert into public.youwell_posts(id, author, alias, body, status, image_path) values
        ('${approved}', '${owner}', 'owner', 'Approved photo', 'approved', '${owner}/approved.png'),
        ('${pending}', '${owner}', 'owner', 'Pending photo', 'pending', '${owner}/pending.png');
    `);
    async function asUser(id, aal, callback, role = 'authenticated') {
      await db.query("select set_config('request.jwt.claim.sub', $1, false)", [id]);
      await db.query("select set_config('request.jwt.claims', $1, false)", [JSON.stringify({ sub: id, aal })]);
      await db.exec(`set role ${role}`);
      try { return await callback(); }
      finally { await db.exec('reset role'); }
    }
    const photos = async () => (await db.query('select name from storage.objects order by name')).rows.map(r => r.name);
    const denied = action => assert.rejects(action, error => error.code === '42501');

    await asUser(owner, 'aal1', async () => {
      assert.deepEqual(await photos(), [
        `${owner}/approved.png`, `${owner}/orphan.png`, `${owner}/pending.png`,
      ]);
      await denied(() => db.query('select * from public.youwell_posts'));
    });
    await asUser(reader, 'aal1', async () => {
      assert.deepEqual(await photos(), [`${owner}/approved.png`]);
      await denied(() => db.query('select * from public.youwell_posts'));
      await denied(() => db.query('select public.youwell_admin_progress_overview()'));
    });
    await asUser(admin, 'aal1', async () => {
      assert.deepEqual(await photos(), [`${owner}/approved.png`]);
      await denied(() => db.query('select public.youwell_admin_progress_overview()'));
    });
    await asUser(admin, 'aal2', async () => {
      assert.equal((await photos()).length, 3);
      await db.query('select public.set_youwell_participant_code($1, $2)', [owner, 'P1']);
      await assert.rejects(
        () => db.query('select public.set_youwell_participant_code($1, $2)', [reader, 'P1']),
        error => error.code === '23505',
      );
    });
    await asUser('', 'aal1', async () => {
      await denied(() => db.query('select public.youwell_community_photo_readable($1)', [`${owner}/approved.png`]));
    }, 'anon');
    console.log('Photo access passed: owner, reader, MFA admin, anonymous, private tables and other buckets.');

    const payload = {
      schemaVersion: 1, version: 3,
      profile: { alias: 'owner', path: 'wellness', started: '2026-10-16', companionName: 'Welli' },
      days: {}, capacity: {}, mobileRewards: {}, achievements: {},
      openedDays: [], activityDays: [], workoutSessions: [], mealCheckIns: [], habitDelays: [], habitSwaps: [],
    };
    await asUser(owner, 'aal1', async () => {
      assert.equal((await db.query('select public.save_youwell_progress($1, 0) as result', [payload])).rows[0].result.saved, true);
      payload.profile.alias = 'renamed';
      assert.equal((await db.query('select public.save_youwell_progress($1, 1) as result', [payload])).rows[0].result.saved, true);
      await assert.rejects(
        () => db.query('select public.react_youwell_post($1, $2)', [approved, '👏']),
        error => error.code === 'P0002',
      );
    });
    assert.deepEqual((await db.query('select distinct alias from public.youwell_posts')).rows, [{ alias: 'renamed' }]);
    await asUser(admin, 'aal2', async () => {
      const rows = (await db.query('select public.youwell_admin_progress_overview() as result')).rows[0].result;
      assert.equal(rows.length, 1);
      assert.equal(rows[0].code, 'P1');
      assert.equal(rows[0].alias, 'renamed');
    });
    await asUser(reader, 'aal1', async () => {
      await assert.rejects(() => db.query('select public.delete_youwell_post($1)', [pending]), error => error.code === 'P0002');
    });
    await asUser(owner, 'aal1', async () => {
      assert.equal((await db.query('select public.delete_youwell_post($1) as photo', [pending])).rows[0].photo, `${owner}/pending.png`);
    });
    console.log('Account operations passed: sync names, alias propagation, participant codes, self-reaction denial and author-only deletion.');
  } finally { await db.close(); }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
