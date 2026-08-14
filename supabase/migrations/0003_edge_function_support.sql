-- Route2Go — 0003_edge_function_support.sql
--
-- Bridges the original core schema to the capabilities the mobile app and
-- edge functions actually need (per the product spec):
--   * notification_prefs  — per-user FCM token registry (spec 2.10)
--   * affiliate_clicks    — server-side click logging for partner CTAs (spec 2.5)
--   * profiles.home_location_label — label for the user's home location
--   * hotels.*            — fields the stays experience exposes (price, city,
--                           partner attribution, booking URL)
-- This migration is additive; it never alters existing columns or drops data.

-- ------------------------------------------------------------
-- NOTIFICATION PREFS (FCM tokens per user)
-- ------------------------------------------------------------
create table if not exists public.notification_prefs (
  user_id uuid primary key references public.users(id) on delete cascade,
  fcm_tokens jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- AFFILIATE CLICKS (partner CTA attribution, spec 2.5)
-- ------------------------------------------------------------
create table if not exists public.affiliate_clicks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete set null,
  stay_id text not null,
  partner_id uuid references public.affiliate_partners(id) on delete set null,
  trip_id uuid,
  clicked_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- PROFILES: home location label
-- ------------------------------------------------------------
alter table public.profiles
  add column if not exists home_location_label text;

-- ------------------------------------------------------------
-- HOTELS: fields needed by the stays experience
-- ------------------------------------------------------------
alter table public.hotels
  add column if not exists city text,
  add column if not exists category text,
  add column if not exists price_per_night numeric,
  add column if not exists partner_name text,
  add column if not exists commission numeric,
  add column if not exists is_sponsored boolean not null default false,
  add column if not exists booking_url text;

-- ------------------------------------------------------------
-- ITINERARY ITEMS: human-readable name for schedule rows
-- ------------------------------------------------------------
alter table public.itinerary_items
  add column if not exists name text;

-- ------------------------------------------------------------
-- RLS: extend existing defense-in-depth to the new tables
-- ------------------------------------------------------------
alter table public.notification_prefs enable row level security;
alter table public.affiliate_clicks enable row level security;

create policy notification_prefs_own on public.notification_prefs
  for all using (user_id = public.current_app_user_id());

create policy affiliate_clicks_select_own on public.affiliate_clicks
  for select using (user_id = public.current_app_user_id());
-- No client insert policy: click logging happens only server-side via the
-- service role, which bypasses RLS by design.