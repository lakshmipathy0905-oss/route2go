-- Route2Go — post-confirm database verification
-- Run this after confirming a trip from the app to verify the live
-- persistence path actually writes to Supabase.

-- 1. Recent trips (filtered to last 30 minutes so we know we're looking
--    at the right test run, not whatever was already there)
SELECT
  id,
  origin_label,
  destination_label,
  trip_type,
  budget_total,
  status,
  created_at
FROM trips
WHERE created_at > NOW() - INTERVAL '30 minutes'
ORDER BY created_at DESC;

-- 2. Routes for those trips
SELECT
  r.trip_id,
  r.route_type,
  r.distance_km,
  r.duration_min,
  r.fuel_cost,
  r.toll_cost,
  r.total_cost,
  r.provider,
  r.freshness_note
FROM routes r
JOIN trips t ON r.trip_id = t.id
WHERE t.created_at > NOW() - INTERVAL '30 minutes'
ORDER BY t.created_at DESC, r.route_type;

-- 3. Itinerary items for those trips
SELECT
  i.trip_id,
  i.day_number,
  i.sequence,
  i.item_type,
  i.name,
  i.est_cost,
  i.start_time,
  i.end_time
FROM itinerary_items i
JOIN trips t ON i.trip_id = t.id
WHERE t.created_at > NOW() - INTERVAL '30 minutes'
ORDER BY t.created_at DESC, i.day_number, i.sequence;

-- 4. Row counts for sanity
SELECT 'trips' AS table_name, COUNT(*) AS total_rows FROM trips
UNION ALL
SELECT 'routes', COUNT(*) FROM routes
UNION ALL
SELECT 'itinerary_items', COUNT(*) FROM itinerary_items;
