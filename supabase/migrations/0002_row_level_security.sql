-- Route2Go RLS Policies
-- Migration: 0002_row_level_security.sql
--
-- IMPORTANT CONTEXT:
-- Identity comes from Firebase, not Supabase Auth. The mobile app NEVER talks to
-- Supabase directly with a user-editable key for privileged writes; all privileged
-- reads/writes go through server-side functions (see supabase/functions/) that:
--   1. Verify the Firebase ID token server-side (Firebase Admin SDK)
--   2. Resolve firebase_uid -> public.users.id
--   3. Use the SUPABASE_SERVICE_ROLE_KEY (server-only) to perform the operation,
--      explicitly filtering by the verified user id.
--
-- RLS below is defense-in-depth in case a table is ever queried with a lesser key,
-- and it deliberately does NOT trust any client-supplied user_id column.
-- Because identity is Firebase-based, RLS here uses a session variable
-- ('request.firebase_uid') set by the server function via `set_config`, rather than
-- Supabase's built-in auth.uid(). If a request path bypasses the server function,
-- no firebase_uid session var is set, and these policies deny access by default.

create or replace function public.current_firebase_uid()
returns text as $$
  select nullif(current_setting('request.firebase_uid', true), '')
$$ language sql stable;

create or replace function public.current_app_user_id()
returns uuid as $$
  select id from public.users where firebase_uid = public.current_firebase_uid()
$$ language sql stable;

-- ============================================================
alter table public.users enable row level security;
alter table public.profiles enable row level security;
alter table public.vehicles enable row level security;
alter table public.trips enable row level security;
alter table public.trip_participants enable row level security;
alter table public.expenses enable row level security;
alter table public.expense_participants enable row level security;
alter table public.itinerary_items enable row level security;
alter table public.saved_trips enable row level security;
alter table public.saved_places enable row level security;
alter table public.notifications enable row level security;
alter table public.privacy_requests enable row level security;
alter table public.consent_records enable row level security;
alter table public.support_tickets enable row level security;
alter table public.audit_logs enable row level security;
alter table public.admin_users enable row level security;

-- Reference/catalog tables (places, hotels, tolls, fuel prices, etc.) are public-read,
-- server-write-only; RLS enabled with a permissive select and no client write policy.
alter table public.places enable row level security;
alter table public.hotels enable row level security;
alter table public.restaurants enable row level security;
alter table public.toll_plazas enable row level security;
alter table public.fuel_prices enable row level security;
alter table public.charging_stations enable row level security;
alter table public.feature_flags enable row level security;

-- ============================================================
-- USERS / PROFILES: a user may only see/edit their own row
-- ============================================================

create policy users_select_own on public.users
  for select using (id = public.current_app_user_id());

create policy users_update_own on public.users
  for update using (id = public.current_app_user_id());
-- No client insert/delete policy: account creation and deletion go through
-- server-side functions using the service role, never a direct client insert.

create policy profiles_select_own on public.profiles
  for select using (user_id = public.current_app_user_id());

create policy profiles_upsert_own on public.profiles
  for insert with check (user_id = public.current_app_user_id());

create policy profiles_update_own on public.profiles
  for update using (user_id = public.current_app_user_id());

-- ============================================================
-- VEHICLES: strictly owner-scoped
-- ============================================================

create policy vehicles_select_own on public.vehicles
  for select using (user_id = public.current_app_user_id());

create policy vehicles_insert_own on public.vehicles
  for insert with check (user_id = public.current_app_user_id());

create policy vehicles_update_own on public.vehicles
  for update using (user_id = public.current_app_user_id());

create policy vehicles_delete_own on public.vehicles
  for delete using (user_id = public.current_app_user_id());

-- ============================================================
-- TRIPS: strictly owner-scoped. Guest (user_id null) trips are never
-- readable via RLS-governed paths -- guest drafts live only in the
-- authenticated server session / client-local state, never persisted
-- to this table until the user has an account.
-- ============================================================

create policy trips_select_own on public.trips
  for select using (user_id is not null and user_id = public.current_app_user_id());

create policy trips_insert_own on public.trips
  for insert with check (user_id = public.current_app_user_id());

create policy trips_update_own on public.trips
  for update using (user_id = public.current_app_user_id());

create policy trips_delete_own on public.trips
  for delete using (user_id = public.current_app_user_id());

-- trip-scoped child tables: ownership is derived through the parent trip,
-- never through a client-supplied user_id on the child row itself.

create policy trip_participants_via_trip on public.trip_participants
  for all using (
    exists (select 1 from public.trips t where t.id = trip_id and t.user_id = public.current_app_user_id())
  ) with check (
    exists (select 1 from public.trips t where t.id = trip_id and t.user_id = public.current_app_user_id())
  );

create policy expenses_via_trip on public.expenses
  for all using (
    exists (select 1 from public.trips t where t.id = trip_id and t.user_id = public.current_app_user_id())
  ) with check (
    exists (select 1 from public.trips t where t.id = trip_id and t.user_id = public.current_app_user_id())
  );

create policy expense_participants_via_expense on public.expense_participants
  for all using (
    exists (
      select 1 from public.expenses e
      join public.trips t on t.id = e.trip_id
      where e.id = expense_id and t.user_id = public.current_app_user_id()
    )
  );

create policy itinerary_items_via_trip on public.itinerary_items
  for all using (
    exists (select 1 from public.trips t where t.id = trip_id and t.user_id = public.current_app_user_id())
  ) with check (
    exists (select 1 from public.trips t where t.id = trip_id and t.user_id = public.current_app_user_id())
  );

-- ============================================================
-- SAVED / FAVORITES / NOTIFICATIONS: owner scoped
-- ============================================================

create policy saved_trips_own on public.saved_trips
  for all using (user_id = public.current_app_user_id());

create policy saved_places_own on public.saved_places
  for all using (user_id = public.current_app_user_id());

create policy notifications_own on public.notifications
  for select using (user_id = public.current_app_user_id());

create policy notifications_update_own on public.notifications
  for update using (user_id = public.current_app_user_id());

create policy privacy_requests_own on public.privacy_requests
  for all using (user_id = public.current_app_user_id());

create policy consent_records_own on public.consent_records
  for all using (user_id = public.current_app_user_id());

create policy support_tickets_own on public.support_tickets
  for all using (user_id = public.current_app_user_id());

-- ============================================================
-- REFERENCE / CATALOG DATA: public read, no client write
-- ============================================================

create policy places_public_read on public.places for select using (true);
create policy hotels_public_read on public.hotels for select using (true);
create policy restaurants_public_read on public.restaurants for select using (true);
create policy toll_plazas_public_read on public.toll_plazas for select using (true);
create policy fuel_prices_public_read on public.fuel_prices for select using (true);
create policy charging_stations_public_read on public.charging_stations for select using (true);
create policy feature_flags_public_read on public.feature_flags for select using (true);
-- Writes to all of the above happen only via server-side admin functions using the
-- service role key, which bypasses RLS by design (never exposed to the client).

-- ============================================================
-- ADMIN / AUDIT: only readable by verified admin_users rows, never by end users
-- ============================================================

create or replace function public.current_admin_role()
returns text as $$
  select role from public.admin_users where firebase_uid = public.current_firebase_uid()
$$ language sql stable;

create policy admin_users_admin_only on public.admin_users
  for select using (public.current_admin_role() is not null);

create policy audit_logs_admin_only on public.audit_logs
  for select using (public.current_admin_role() is not null);
-- Audit log inserts happen exclusively from server-side functions with the
-- service role; there is intentionally no client insert/update/delete policy.
