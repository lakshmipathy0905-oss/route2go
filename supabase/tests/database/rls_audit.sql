-- Route2Go RLS audit — permanent regression checks.
--
-- These run under `supabase test db` alongside rls_trips.sql and guard the
-- two failure classes that bite locally-scaffolded Supabase projects:
--
--   A. Helper-function recursion: a policy on table T calling a helper that
--      queries T recurses infinitely under the `authenticated` role unless the
--      helper is SECURITY DEFINER. current_app_user_id() queries `users`;
--      current_admin_role() queries `admin_users`. Both must stay SECURITY
--      DEFINER (migration 0006).
--   B. Over-broad anon grants: `anon` must have DML (INSERT/UPDATE/DELETE) on
--      NOTHING in the app schema, and SELECT only on the seven public-read
--      catalog tables. The "broad grants + RLS guards rows" model gives
--      `authenticated` full DML; `anon` stays read-only.

begin;
set search_path = extensions, public;
select plan(4);

-- A1. current_app_user_id() is SECURITY DEFINER (queries RLS-protected users)
select is(
  (select prosecdef from pg_proc
   where proname = 'current_app_user_id'
     and pronamespace = 'public'::regnamespace),
  true,
  'current_app_user_id() is SECURITY DEFINER (prevents policy recursion on users)'
);

-- A2. current_admin_role() is SECURITY DEFINER (queries RLS-protected admin_users)
select is(
  (select prosecdef from pg_proc
   where proname = 'current_admin_role'
     and pronamespace = 'public'::regnamespace),
  true,
  'current_admin_role() is SECURITY DEFINER (prevents policy recursion on admin_users)'
);

-- B1. anon has zero INSERT/UPDATE/DELETE grants on any app table
select is(
  (select count(*)::int from information_schema.role_table_grants
   where grantee = 'anon'
     and privilege_type in ('INSERT', 'UPDATE', 'DELETE')
     and table_schema = 'public'),
  0,
  'anon has no DML grants on public tables'
);

-- B2. anon SELECT is limited to the seven public-read catalog tables
select is(
  (select count(*)::int from information_schema.role_table_grants
   where grantee = 'anon'
     and privilege_type = 'SELECT'
     and table_schema = 'public'),
  7,
  'anon SELECT grants exist only on the seven catalog tables'
);

select * from finish();
rollback;