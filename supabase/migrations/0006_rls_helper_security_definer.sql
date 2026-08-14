-- Route2Go — RLS helper functions must be SECURITY DEFINER
-- Migration: 0006_rls_helper_security_definer.sql
--
-- Bug found by the pgTAP RLS suite (supabase/tests/database/rls_trips.sql):
-- when a query runs as a NON-superuser role (e.g. `authenticated`, the role
-- PostgREST uses), `current_app_user_id()` caused infinite recursion.
--
-- Why: `current_app_user_id()` does `select id from public.users where
-- firebase_uid = current_firebase_uid()`. `users` is RLS-enabled with the
-- `users_select_own` policy, and that policy itself calls
-- `current_app_user_id()`. Under a superuser that inner lookup bypasses RLS,
-- so the recursion was invisible. Under `authenticated`, RLS applies to the
-- inner query, so each policy evaluation re-entered the policy -> stack depth
-- exceeded.
--
-- Fix: mark the identity-lookup helpers SECURITY DEFINER (the standard
-- Supabase pattern) so the internal lookup runs as the function owner and is
-- exempt from RLS. `set search_path = public` prevents search-path hijack of
-- unqualified references inside the function body.
--
-- Same problem and fix for `current_admin_role()`, which reads
-- `public.admin_users` (RLS-protected by `admin_users_admin_only`).

create or replace function public.current_app_user_id()
returns uuid as $$
  select id from public.users where firebase_uid = public.current_firebase_uid()
$$ language sql stable security definer set search_path = public;

create or replace function public.current_admin_role()
returns text as $$
  select role from public.admin_users where firebase_uid = public.current_firebase_uid()
$$ language sql stable security definer set search_path = public;