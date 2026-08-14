-- Route2Go RLS test — TRIPS isolation between two users.
--
-- Why `set role authenticated`: `supabase test db` runs pg_prove as the
-- `postgres` superuser, which BYPASSES row-level security. If this test ran
-- entirely as postgres, every assertion would pass even with every policy in
-- 0002_row_level_security.sql commented out. So we:
--   1. insert fixtures as postgres (superuser, RLS bypassed, can create data)
--   2. `set role authenticated` — the same non-superuser role PostgREST uses in
--      production, where RLS policies genuinely apply
--   3. run all RLS assertions as `authenticated`
--   4. switch back to postgres for `finish()` (pgTAP bookkeeping)
--
-- The whole block runs inside begin ... rollback, so no test data persists.

begin;

-- Note: extensions schema must be on the search path for plan()/is()/finish().
-- Supabase puts `extensions` on the search path by default; if it is not,
-- prefix the calls with `extensions.` or `set search_path`.
set search_path = extensions, public;

select plan(6);

-- ============================================================
-- Fixtures (as postgres — superuser bypasses RLS, which is required here
-- because `users` has no client INSERT policy by design).
-- ============================================================

insert into public.users (firebase_uid, email, auth_provider)
values ('test-uid-user-a', 'a@test.local', 'email'),
       ('test-uid-user-b', 'b@test.local', 'email');

insert into public.trips (
  user_id, origin_label, origin_lat, origin_lng,
  destination_label, destination_lat, destination_lng, trip_type
)
select id, 'Bengaluru', 12.9716, 77.5946, 'Goa', 15.2993, 74.1240, 'one_way'
from public.users where firebase_uid = 'test-uid-user-a';

-- ============================================================
-- RLS assertions (as `authenticated`, where RLS genuinely applies)
-- ============================================================

set role authenticated;

-- Act as user A: can see their own trip
select set_config('request.firebase_uid', 'test-uid-user-a', true);

select is(
  (select count(*)::int from public.trips t
   join public.users u on u.id = t.user_id
   where u.firebase_uid = 'test-uid-user-a'),
  1,
  'User A can see their own trip'
);

-- Switch to user B: should see zero of A's trips
select set_config('request.firebase_uid', 'test-uid-user-b', true);

select is(
  (select count(*)::int from public.trips),
  0,
  'User B cannot see user A''s trip via RLS'
);

-- User B attempts to update A's trip — should affect 0 rows
with attempted_update as (
  update public.trips set status = 'confirmed'
  where origin_label = 'Bengaluru'
  returning id
)
select is(
  (select count(*)::int from attempted_update),
  0,
  'User B cannot update user A''s trip'
);

-- User B attempts to delete A's trip — should affect 0 rows
with attempted_delete as (
  delete from public.trips
  where origin_label = 'Bengaluru'
  returning id
)
select is(
  (select count(*)::int from attempted_delete),
  0,
  'User B cannot delete user A''s trip'
);

-- Switch back to user A: trip should still exist untouched
select set_config('request.firebase_uid', 'test-uid-user-a', true);

select is(
  (select status from public.trips where origin_label = 'Bengaluru'),
  'draft',
  'User A''s trip is untouched after user B''s attempts'
);

-- No session var set at all (simulates a bypassed server function): should see nothing
select set_config('request.firebase_uid', '', true);

select is(
  (select count(*)::int from public.trips),
  0,
  'No firebase_uid set means zero visibility, not a default-allow'
);

-- Back to postgres for pgTAP bookkeeping
set role postgres;

select * from finish();

rollback;