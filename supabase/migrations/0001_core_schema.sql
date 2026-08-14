-- Route2Go Core Schema (MVP)
-- Migration: 0001_core_schema.sql
-- Applies to: Supabase Postgres
-- Identity source of truth is Firebase Auth. We store firebase_uid, NOT Supabase auth.uid().
-- Every privileged write happens through server-side functions that have already verified
-- the Firebase ID token; RLS below is defense-in-depth for direct table access.

create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- ============================================================
-- USERS / PROFILES
-- ============================================================

create table if not exists public.users (
  id uuid primary key default gen_random_uuid(),
  firebase_uid text unique not null,
  email text,
  phone text,
  auth_provider text not null default 'unknown', -- google | email | phone
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz -- soft delete for account deletion workflow
);

create index if not exists idx_users_firebase_uid on public.users (firebase_uid);

create table if not exists public.profiles (
  user_id uuid primary key references public.users(id) on delete cascade,
  name text,
  photo_url text,
  language text default 'en',
  home_location_lat numeric(9,6),
  home_location_lng numeric(9,6),
  travel_pref text default 'balanced', -- budget | balanced | premium
  accommodation_pref text,
  analytics_opt_out boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ============================================================
-- VEHICLES
-- ============================================================

create table if not exists public.vehicles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  label text not null,
  fuel_type text not null check (fuel_type in ('petrol','diesel','ev','cng')),
  mileage_kmpl numeric(6,2) check (mileage_kmpl is null or (mileage_kmpl > 0 and mileage_kmpl < 100)),
  ev_battery_kwh numeric(6,2),
  ev_efficiency_kwh_per_km numeric(6,3),
  cng_mileage_km_per_kg numeric(6,2),
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_vehicles_user_id on public.vehicles (user_id);

-- ============================================================
-- TRIPS
-- ============================================================

create table if not exists public.trips (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete cascade, -- nullable: guest draft trips (server session only, never persisted for guests)
  origin_label text not null,
  origin_lat numeric(9,6) not null,
  origin_lng numeric(9,6) not null,
  destination_label text not null,
  destination_lat numeric(9,6) not null,
  destination_lng numeric(9,6) not null,
  trip_type text not null check (trip_type in ('one_way','round_trip')),
  start_date date,
  end_date date,
  travellers int not null default 1 check (travellers > 0 and travellers <= 20),
  vehicle_id uuid references public.vehicles(id),
  manual_fuel_type text check (manual_fuel_type in ('petrol','diesel','ev','cng')),
  manual_mileage_kmpl numeric(6,2),
  fuel_price_per_litre numeric(8,2),
  budget_total numeric(10,2) check (budget_total is null or budget_total >= 0),
  status text not null default 'draft' check (status in ('draft','calculated','confirmed','completed','cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint chk_origin_destination_distinct check (
    origin_lat is distinct from destination_lat or origin_lng is distinct from destination_lng
  )
);

create index if not exists idx_trips_user_id on public.trips (user_id);
create index if not exists idx_trips_status on public.trips (status);

create table if not exists public.trip_participants (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips(id) on delete cascade,
  name text not null,
  paid_amount numeric(10,2) not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists idx_trip_participants_trip_id on public.trip_participants (trip_id);

-- ============================================================
-- ROUTES / SEGMENTS / TOLLS
-- ============================================================

create table if not exists public.routes (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips(id) on delete cascade,
  route_type text not null check (route_type in ('fastest','cheapest','shortest','no_toll','recommended')),
  distance_km numeric(8,2) not null,
  duration_min int not null,
  fuel_cost numeric(10,2) not null default 0,
  toll_cost numeric(10,2) not null default 0,
  total_cost numeric(10,2) not null default 0,
  geometry jsonb, -- encoded polyline / geojson from routing provider
  provider text not null,
  fetched_at timestamptz not null default now(),
  freshness_note text,
  created_at timestamptz not null default now()
);

create index if not exists idx_routes_trip_id on public.routes (trip_id);

create table if not exists public.route_segments (
  id uuid primary key default gen_random_uuid(),
  route_id uuid not null references public.routes(id) on delete cascade,
  sequence int not null,
  start_lat numeric(9,6) not null,
  start_lng numeric(9,6) not null,
  end_lat numeric(9,6) not null,
  end_lng numeric(9,6) not null,
  distance_km numeric(8,2) not null
);

create index if not exists idx_route_segments_route_id on public.route_segments (route_id);

create table if not exists public.toll_plazas (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  lat numeric(9,6) not null,
  lng numeric(9,6) not null,
  vehicle_category text not null, -- car | bike | truck | bus
  charge numeric(8,2) not null,
  source_confidence text not null default 'estimated' check (source_confidence in ('verified','community','estimated')),
  last_updated timestamptz not null default now()
);

create index if not exists idx_toll_plazas_geo on public.toll_plazas (lat, lng);

create table if not exists public.route_tolls (
  route_id uuid not null references public.routes(id) on delete cascade,
  toll_plaza_id uuid not null references public.toll_plazas(id),
  primary key (route_id, toll_plaza_id)
);

-- ============================================================
-- FUEL / CHARGING / CNG REFERENCE DATA
-- ============================================================

create table if not exists public.fuel_prices (
  id uuid primary key default gen_random_uuid(),
  region text not null,
  fuel_type text not null check (fuel_type in ('petrol','diesel','cng')),
  price numeric(8,2) not null,
  last_updated timestamptz not null default now(),
  unique (region, fuel_type)
);

create table if not exists public.charging_stations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  lat numeric(9,6) not null,
  lng numeric(9,6) not null,
  network text,
  price_per_kwh numeric(8,2)
);

-- ============================================================
-- PLACES / STAYS / RESTAURANTS
-- ============================================================

create table if not exists public.place_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique
);

create table if not exists public.places (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category_id uuid references public.place_categories(id),
  lat numeric(9,6) not null,
  lng numeric(9,6) not null,
  photos jsonb default '[]'::jsonb,
  hours text,
  entry_fee numeric(8,2),
  rating numeric(2,1),
  description text,
  created_at timestamptz not null default now()
);

create index if not exists idx_places_geo on public.places (lat, lng);

create table if not exists public.affiliate_partners (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  partner_type text not null, -- hotel | activity | insurance
  created_at timestamptz not null default now()
);

create table if not exists public.hotels (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  lat numeric(9,6) not null,
  lng numeric(9,6) not null,
  price_range text,
  rating numeric(2,1),
  amenities jsonb default '[]'::jsonb,
  partner_id uuid references public.affiliate_partners(id)
);

create index if not exists idx_hotels_geo on public.hotels (lat, lng);

create table if not exists public.restaurants (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  lat numeric(9,6) not null,
  lng numeric(9,6) not null,
  category text,
  price_range text
);

-- ============================================================
-- ITINERARY
-- ============================================================

create table if not exists public.itinerary_items (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips(id) on delete cascade,
  day_number int not null check (day_number > 0),
  sequence int not null,
  item_type text not null check (item_type in ('place','hotel','restaurant','drive','rest')),
  ref_id uuid,
  start_time timestamptz,
  end_time timestamptz,
  est_cost numeric(10,2) default 0,
  created_at timestamptz not null default now()
);

create index if not exists idx_itinerary_items_trip_id on public.itinerary_items (trip_id);

-- ============================================================
-- EXPENSES
-- ============================================================

create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips(id) on delete cascade,
  category text not null check (category in ('fuel','toll','stay','food','misc')),
  estimated_amount numeric(10,2) not null default 0,
  actual_amount numeric(10,2),
  paid_by text,
  split_type text default 'equal',
  created_at timestamptz not null default now()
);

create index if not exists idx_expenses_trip_id on public.expenses (trip_id);

create table if not exists public.expense_participants (
  expense_id uuid not null references public.expenses(id) on delete cascade,
  trip_participant_id uuid not null references public.trip_participants(id) on delete cascade,
  share_amount numeric(10,2) not null default 0,
  primary key (expense_id, trip_participant_id)
);

-- ============================================================
-- SAVED / FAVORITES / NOTIFICATIONS
-- ============================================================

create table if not exists public.saved_trips (
  user_id uuid not null references public.users(id) on delete cascade,
  trip_id uuid not null references public.trips(id) on delete cascade,
  saved_at timestamptz not null default now(),
  primary key (user_id, trip_id)
);

create table if not exists public.saved_places (
  user_id uuid not null references public.users(id) on delete cascade,
  place_id uuid not null references public.places(id) on delete cascade,
  saved_at timestamptz not null default now(),
  primary key (user_id, place_id)
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  type text not null,
  payload jsonb default '{}'::jsonb,
  sent_at timestamptz,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists idx_notifications_user_id on public.notifications (user_id);

-- ============================================================
-- REVIEWS / COMMUNITY (Phase 2 shell, flagged off)
-- ============================================================

create table if not exists public.community_reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete set null,
  entity_type text not null,
  entity_id uuid not null,
  report_type text not null,
  payload jsonb default '{}'::jsonb,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamptz not null default now()
);

-- ============================================================
-- ADMIN / AUDIT / FEATURE FLAGS
-- ============================================================

create table if not exists public.admin_users (
  id uuid primary key default gen_random_uuid(),
  firebase_uid text unique not null,
  role text not null check (role in ('super_admin','content_manager','support','moderator','finance')),
  created_at timestamptz not null default now()
);

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_firebase_uid text not null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  request_id text,
  before_summary jsonb,
  after_summary jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_audit_logs_created_at on public.audit_logs (created_at desc);

create table if not exists public.feature_flags (
  key text primary key,
  enabled boolean not null default false,
  description text,
  updated_at timestamptz not null default now()
);

insert into public.feature_flags (key, enabled, description) values
  ('phase2_group_split', false, 'Group expense splitting'),
  ('phase2_ev', false, 'EV mode'),
  ('phase2_cng', false, 'CNG mode'),
  ('phase2_offline', false, 'Offline route packages'),
  ('phase2_weather', false, 'Weather/road alerts'),
  ('phase3_ai', false, 'AI trip assistant'),
  ('phase3_voice', false, 'Voice commands'),
  ('maintenance_mode', false, 'Global maintenance mode')
on conflict (key) do nothing;

create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete set null,
  subject text not null,
  message text not null,
  status text not null default 'open' check (status in ('open','in_progress','closed')),
  created_at timestamptz not null default now()
);

create table if not exists public.consent_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  consent_type text not null, -- analytics | marketing
  granted boolean not null,
  recorded_at timestamptz not null default now()
);

create table if not exists public.privacy_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  request_type text not null check (request_type in ('delete','export','correction','question')),
  status text not null default 'pending' check (status in ('pending','in_progress','completed','rejected')),
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

-- ============================================================
-- updated_at trigger helper
-- ============================================================

create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_users_updated_at on public.users;
create trigger trg_users_updated_at before update on public.users
  for each row execute function public.set_updated_at();

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();

drop trigger if exists trg_vehicles_updated_at on public.vehicles;
create trigger trg_vehicles_updated_at before update on public.vehicles
  for each row execute function public.set_updated_at();

drop trigger if exists trg_trips_updated_at on public.trips;
create trigger trg_trips_updated_at before update on public.trips
  for each row execute function public.set_updated_at();
