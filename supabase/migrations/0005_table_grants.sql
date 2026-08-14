-- Route2Go — Table grants for anon/authenticated/service_role
-- Migration: 0005_table_grants.sql
--
-- Supabase's model: broad table-level GRANTs + RLS for row-level control.
-- The default ACLs in this project's local reset were inherited from the
-- `postgres` role and only carried TRUNCATE/TRIGGER/REFERENCES, so direct
-- (PostgREST / RLS-policy) access was impossible for non-superuser roles.
--
-- This migration mirrors production Supabase defaults:
--   - `authenticated`: full DML on the app's tables (row scope enforced by
--     the RLS policies in 0002/0003)
--   - `anon`: read access to the public-read reference/catalog tables
--     (enforced by the *_public_read policies)
--   - `service_role`: full access (bypasses RLS server-side by design)
--
-- RLS is unchanged; these grants only open the door that the policies guard.

grant usage on schema public to anon, authenticated, service_role;

-- Authenticated users: full DML across user-owned tables. The RLS policies in
-- 0002/0003 restrict every operation to rows the actor actually owns.
grant select, insert, update, delete on all tables in schema public to authenticated;
grant all on all sequences in schema public to authenticated;

-- Anonymous (guest) users: read-only access to reference/catalog data and
-- feature flags. These tables carry *_public_read policies; no anon DML is
-- granted (writes go through Edge Functions only).
grant select on public.places to anon;
grant select on public.hotels to anon;
grant select on public.restaurants to anon;
grant select on public.toll_plazas to anon;
grant select on public.fuel_prices to anon;
grant select on public.charging_stations to anon;
grant select on public.feature_flags to anon;

-- Service role: full access (used by Edge Functions; bypasses RLS by design).
grant all on all tables in schema public to service_role;
grant all on all sequences in schema public to service_role;

-- Make the grants apply to tables created later in this schema too.
alter default privileges in schema public grant select, insert, update, delete on tables to authenticated;
alter default privileges in schema public grant select on tables to anon;
alter default privileges in schema public grant all on tables to service_role;