-- Route2Go — Phase 4 performance indexes (migration 0008)
--
-- Every index here is justified by a real, planner-visible query pattern from
-- the edge functions / app. No blanket or speculative indexes.
--
--   1. pg_trgm GIN indexes for /search's leading-wildcard `ilike` filters
--      (search/index.ts): `name.ilike.%q%` and `city.ilike.%q%` cannot use a
--      B-tree, so on a large catalog they would seq-scan. A trigram GIN index
--      makes `%q%` index-backed.
--   2. notifications composite indexes for the two read paths in
--      notifications/index.ts: the unread count (`user_id AND read_at IS NULL`)
--      and the list (`user_id ORDER BY created_at DESC LIMIT 100`).
--   3. audit_logs composite index for the admin audit viewer
--      (admin/index.ts:58-66), which filters by action then orders by
--      created_at. The existing idx_audit_logs_created_at already covers the
--      unfiltered path.

create extension if not exists pg_trgm;

-- 1. Catalog search (places + hotels, from /search)
create index if not exists idx_places_name_trgm
  on public.places using gin (name gin_trgm_ops);

create index if not exists idx_hotels_name_trgm
  on public.hotels using gin (name gin_trgm_ops);

create index if not exists idx_hotels_city_trgm
  on public.hotels using gin (city gin_trgm_ops);

-- 2. Notifications read paths
create index if not exists idx_notifications_user_created
  on public.notifications (user_id, created_at desc);

create index if not exists idx_notifications_user_unread
  on public.notifications (user_id) where read_at is null;

-- 3. Audit log viewer
create index if not exists idx_audit_logs_action_created
  on public.audit_logs (action, created_at desc);
