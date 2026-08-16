# Route2Go — Performance Audit (Phase 4)

Audit target: prepare Route2Go for **~3,000 concurrent active users** without
rearchitecting the app, the navigation engine, or the routing/POI/geocoding
providers (Valhalla, OSM, Photon, Overpass). Every finding below is measured or
directly observable from code; every fix must be a safe, behavior-preserving
optimization and must not trade correctness (honest routing, degradation, and
the 25-item regression list) for a few microseconds.

Audit date: 2026-08-16 · Baseline commit: `21fef5d` · Gates baseline:
`flutter analyze` 0 errors/warnings (9 info), `flutter test` 68/68, `deno test`
76/76, APK debug + web builds green.

Legend for severity:
- **CRITICAL** — will break or seriously degrade at 3k concurrent users.
- **HIGH** — measurable latency/load multiplier under concurrency.
- **MEDIUM** — bounded impact, worth fixing cheaply.
- **LOW** — hygiene/cosmetic; fix only if trivial.

---

## 1. Backend — Supabase Edge Functions (Deno)

### 1.1 Geocoding has no timeout and no cache — Photon/Nominatim
- **Files:** `supabase/functions/_shared/providers/geocodingProvider.ts`
- **Severity: CRITICAL.**
- **Finding:** The provider `fetch`es Photon (or Nominatim) with no
  `AbortSignal.timeout`. A slow/unresponsive public geocoder can hold a worker
  isolate (and its client connection) for minutes. Combined with no request
  caching, repeated identical searches (debounced typing) re-hit the public
  endpoint every keystroke — both a latency cliff and a load generator against
  a shared public service (we must never hammer Photon).
- **Impact:** Worst-case worker-lease exhaustion under bursty search; higher
  p95 search latency; unnecessary egress.
- **Fix (planned):** `fetchWithTimeout` (≈6s), plus a bounded in-memory TTL
  cache (identical `q`/`lat/lng` keys) mirroring the Overpass provider pattern.
  Degradation stays honest: timeout/failure surfaces `GEOCODER_UNAVAILABLE`,
  never fabricated results.

### 1.2 `/route-nav` issues the full 5-alternative Valhalla request
- **Files:** `supabase/functions/route-nav/index.ts:43-49`,
  `_shared/providers/routingProvider.ts:143-225`
- **Severity: HIGH.**
- **Finding:** `route-nav` calls `getRouteAlternatives` which (a) requests up
  to 3 alternatives on the tolls profile (`postRoute(true, 3)`), then (b) makes
  a **second** sequential Valhalla call for the no-toll profile. Live navigation
  only consumes `routeAlternatives[0]` (route-nav/index.ts:59). Every reroute —
  already a rare-but-critical event — therefore costs 2 sequential Valhalla
  round-trips and 4-5 route solutions we discard. Under concurrency each reroute
  doubles Valhalla queue pressure.
- **Impact:** Reroute latency ~2× worse than necessary; Valhalla CPU 2× per
  reroute for zero user-visible benefit.
- **Fix (planned):** Add a `getSingleRoute` method (one tolls call,
  `alternates: 0`, no no-toll) and have `route-nav` use it. `trip-calculate`
  keeps the full alternatives behavior unchanged.

### 1.3 Toll lookup N+1
- **Files:** `supabase/functions/_shared/providers/tollProvider.ts:45-66`
- **Severity: HIGH** (live-toll mode; mocked in dev).
- **Finding:** `SupabaseTollProvider.getTollsForRoute` issues **one REST query
  per route segment** against `toll_plazas`. A 40-segment route = 40 sequential
  HTTP round-trips to PostgREST. Each is bounded only by `route` shape and the
  pad box — and they run serially (`for ... of`).
- **Impact:** Live-toll trip calculation latency scales O(segments); 40+ ms ×
  segment count just in query time, plus PostgREST connection churn.
- **Fix (planned):** Replace with a single query over the union bounding box of
  all segments (min/max lat/lng with the same `0.05` pad). The union box is a
  superset of every per-segment box, so the result set is identical or a strict
  superset — correctness preserved, one query total. Cap result count to bound
  response size.

### 1.4 `/places-near-route` and `/stays-near-route` full-table scans
- **Files:** `supabase/functions/places-near-route/index.ts:100-103`,
  `supabase/functions/stays-near-route/index.ts:75-78`
- **Severity: HIGH.**
- **Finding:** Both fetch **every** row (`places`, `hotels`) and filter in JS
  memory (`pointToSegmentKm`). `places` already has a `(lat,lng)` index, but the
  query never constrains it, so the index is dead weight here and the edge
  function transfers the entire table on every request. `stays-near-route`
  also `limit(200)` only after the full fetch.
- **Impact:** DB CPU + network payload grow linearly with catalog size; at 3k
  users every "places along route" refresh scans the whole table.
- **Fix (planned):** Push a bounding-box filter into SQL
  (`lat >= minLat-pad AND lat <= maxLat+pad AND lng >= minLng-pad AND lng <=
  maxLng-pad`) using the origin/dest extremes. Because filtering is done on the
  straight-line corridor segment, the SQL box is a superset of the JS filter —
  identical results, index-backed. Add a similar bbox to `stays-near-route`
  (its distance filter is also segment-based, so the box is a safe superset).

### 1.5 Missing rate limits on hot endpoints
- **Files:** `route-nav/index.ts`, `trip-calculate/index.ts`,
  `places-near-route/index.ts`, `stays-near-route/index.ts`,
  `itinerary-generate/index.ts`; limiter in `_shared/rateLimit.ts`
- **Severity: HIGH.**
- **Finding:** Only `search` (and a few others) call `checkRateLimit`. The
  routing/POI-forwarding endpoints (`route-nav`, `trip-calculate`,
  `places-near-route`, `stays-near-route`, `itinerary-generate`) are unlimited —
  a single client can saturate the shared Valhalla/Overpass/DB budget. Also,
  `clientKey` in `_shared/rateLimit.ts` trusts the **first** `x-forwarded-for`
  value, which a caller can spoof (Supabase injects its own hop after user
  input); per-isolate state means the limit does not span isolates either.
- **Impact:** Unbounded amplification of upstream provider load; abusable
  identity for bypass.
- **Fix (planned):** Add bounded per-key limits to the five endpoints (e.g.
  30/min route-nav, 60/min trip-calculate, 120/min places/stays,
  30/min itinerary). Switch `clientKey` to the **last** hop of
  `x-forwarded-for` (the untrusted user-supplied prefix is ignored) falling back
  to `x-real-ip` / `cf-connecting-ip`. Document the per-isolate caveat rather
  than fake cross-isolate precision. Limits are generous enough to never break
  a legit user's navigation or planning flow.

### 1.6 `/search` — sequential geocode + POI and injectable ilike filter
- **Files:** `supabase/functions/search/index.ts:70-91,132-175`
- **Severity: MEDIUM.**
- **Finding:** (a) `getGeocodingProvider().forward(q)` runs fully before the
  Overpass POI call — they are independent and could run in parallel. (b) The
  `q` value is interpolated raw into PostgREST `.or(...ilike.${pattern})`
  filters; a query containing `,` or `(`/`)`/`.` can be interpreted as extra
  filter expressions (filter injection), and a `%` in the query widens the match
  beyond intent.
- **Impact:** ~2× search latency when both geocoding and POI apply; a
  correctness/security footgun in the DB filter path.
- **Fix (planned):** `Promise.all` the geocode + POI calls (POI only when
  lat/lng present). Normalize/sanitize the search pattern: strip PostgREST
  filter-significant characters (`,` `(` `)` `.` `'` `"`) and collapse `%`/
  `*` to plain text before building `%...%`.

### 1.7 `/trip-calculate` — routing, phase flags, and fuel price are sequential
- **Files:** `supabase/functions/trip-calculate/index.ts` (routing at ~L110,
  flags read ~L126, fuel price resolution)
- **Severity: MEDIUM.**
- **Finding:** Routing is awaited before phase flags and fuel price are
  resolved, though none depend on the routing output (fuel price depends only on
  the vehicle's fuel type; flags depend on nothing). Serializing them adds the
  slowest of the three to the critical path on top of routing.
- **Impact:** Wasted wall-clock per trip calculation.
- **Fix (planned):** Resolve routing, phase flags, and fuel price concurrently
  (`Promise.all`); results consumed exactly as today. Order of writes to the DB
  stays unchanged.

### 1.8 Overpass client/server timeout mismatch
- **Files:** `_shared/providers/poiProvider.ts:136` (`[timeout:15]`) vs
  `poiProvider.ts:260` (client abort 10s)
- **Severity: LOW** (correctness-of-protection only).
- **Finding:** Overpass is told to work for up to 15s but we abort at 10s; a
  server could still be computing for 15s while we've moved on (the wasted work
  and the partial response are dropped on abort, but the public server still
  burned 15s of CPU for nothing).
- **Fix (planned):** Align server timeout to the client budget (`[timeout:10]`)
  so we never ask a public server to work longer than we'll wait.

### 1.9 `/trip GET` embeds full route geometry on every fetch
- **Files:** trip detail retrieval (list/GET of trips + routes/segments)
- **Severity: MEDIUM.**
- **Finding:** Fetching a saved trip returns the entire stored route geometry
  (routes + segments) even when the caller only needs the trip card fields.
- **Fix (planned):** Add `?summary=1` (or similar) so the trip list avoids
  embedding geometry; detail keeps full geometry. Client uses summary for lists.

### 1.10 Geocoding `.or()` / full-scan patterns in admin & misc functions
- **Severity: LOW.** Admin-only endpoints with `ilike` leading-wildcard remain
  acceptable given their very low call rate; noted for the DB section below.

---

## 2. Database — Postgres schema

### 2.1 Leading-wildcard `ilike` has no trigram index
- **Files:** `supabase/migrations/0001_core_schema.sql`; used by
  `search/index.ts` (`places.name`, `hotels.name`, `hotels.city`)
- **Severity: MEDIUM.**
- **Finding:** `%q%` cannot use a B-tree index. On a large catalog this is a
  seq scan per search. `pg_trgm` GIN indexes make `%q%` index-backed.
- **Fix (planned):** New migration: `CREATE EXTENSION IF NOT EXISTS pg_trgm;`
  + GIN trgm indexes on `places(name)`, `hotels(name)`, `hotels(city)`, plus
  functional indexes where query patterns justify them. Only add indexes that a
  query planner actually uses (documented per index); do not index blindly.

### 2.2 Missing query-path indexes
- **Files:** migrations 0001-0007
- **Severity: MEDIUM.**
- **Finding:** Write-heavy path indexes exist (trips.user_id, routes.trip_id,
  trip_participants.trip_id, itinerary_items.trip_id, expenses.trip_id, …).
  Observed gaps: `audit_logs` reads (by actor/entity/time), `notifications` for
  a user's unread list, `affiliate_clicks`/`itinerary_items` by `trip_id`,
  `places`/`hotels` bbox queries already covered by `(lat,lng)`.
- **Fix (planned):** Index `audit_logs(actor_firebase_uid, created_at)`,
  `audit_logs(entity_type, entity_id, created_at)`, `notifications(user_id,
  read, created_at)`, `affiliate_clicks(trip_id)` if the table is queried by
  trip. Justify each with the actual query.

---

## 3. Flutter client

### 3.1 Home-map search: no debounce, no stale-response guard
- **Files:** `apps/mobile/lib/presentation/screens/home/home_screen.dart`
  (`_onSearch`, maps mode added in Phase 3B)
- **Severity: HIGH.**
- **Finding:** Every keystroke triggers `searchProvider.search()` with no
  debounce, and a slow earlier response can overwrite a newer one (classic race:
  out-of-order resolution). Under typing this multiplies requests to the edge
  functions (and thus Photon/Overpass) and can show stale results.
- **Fix (planned):** 300ms debounce timer in `_onSearch` + a monotonically
  increasing query token; only the latest token's response may write state.

### 3.2 Whole-provider watches at rebuild hotspots
- **Files:** `home_screen.dart:96-97,265` (`_HomeTab`/`_MapTab` watch whole
  `tripsProvider`), `route_results_screen.dart:61-62` (whole
  `tripCalculationProvider`), `trip_detail_screen.dart:29` (whole
  `tripsProvider`), `confirm_trip_screen.dart:26-30` (5 whole providers)
- **Severity: MEDIUM.**
- **Finding:** Only 14 `.select()` uses exist, all in `live_trip_screen.dart`.
  Watching a whole `AsyncValue` rebuilds a subtree when *any* field changes
  (e.g. route results list re-rendering on a progress/status tweak).
- **Impact:** Unnecessary widget rebuilds; CPU frames under churn.
- **Fix (planned):** `.select()` the specific fields each widget renders
  (identity/list length, status, etc.). Behavior identical; rebuild count drops.

### 3.3 Navigation state written 3× per GPS tick
- **Files:** `navigation_provider.dart:_onLocation` (position write at
  `copyWith(position:)`, progress write at `copyWith(status:,progress:)`,
  plus `_updateManeuver`/`_updateArrival`/`_updateOffRoute` writes)
- **Severity: MEDIUM.**
- **Finding:** Each GPS update (1-3/s) triggers 2-3 `state = state.copyWith(...)`
  writes; every write notifies listeners. Most ticks are no-ops for
  maneuver/arrival/off-route yet still publish state.
- **Fix (planned):** Coalesce the always-fired writes (position + progress +
  status) into a single `copyWith` per tick; keep maneuver/arrival/off-route as
  conditional writes only when they actually change. Behavior identical
  (progressive values unchanged); listener notifications reduced ~3×.

### 3.4 O(n) full-polyline projection every tick
- **Files:** progress engine (route projection: `progressAt` / projection of
  position against the full polyline per GPS tick)
- **Severity: MEDIUM.**
- **Finding:** Re-projecting the current position against every segment of the
  route each tick is O(n) in polyline length. For long routes that is a few
  thousand segment-distance calls per second per active navigator.
- **Fix (planned):** Cache the running segment index: carry the previous
  nearest-segment index and only scan a small window around it (points move
  slowly relative to the polyline). Bounded, monotone advancement keeps
  correctness (a forward-progress assumption that always holds while
  navigating).

### 3.5 Provider field fetches: categories fetched on every places load
- **Files:** `places_provider.dart:49-67` (`placesNearRoute` then `categories()`
  await, serial)
- **Severity: MEDIUM.**
- **Finding:** `categories()` is awaited after the places list (serial) on every
  load and re-fetched on every refresh even though categories are static catalog
  data.
- **Fix (planned):** Fetch places + categories in parallel (`Future.wait`);
  cache categories at the repository/provider level (short TTL) so repeated
  loads don't re-query the DB.

### 3.6 `Supabase.initialize` awaited before first paint in `main()`
- **Files:** `apps/mobile/lib/main.dart:42-46`
- **Severity: LOW** (no app code reads Supabase; see note).
- **Finding:** Launch awaits `Supabase.initialize` (anon key) before
  `runApp`. If it ever stalls (network), first paint is delayed. Note: no `lib/`
  code uses the Supabase client directly today — all data flows through Edge
  Functions via `ApiClient` — so initialization is effectively unused.
- **Fix (planned):** Wrap in a `Future.timeout` (e.g. 3s) and make it
  non-blocking / tolerate failure so launch is never delayed by it. If a future
  feature uses Supabase directly, revisit.

### 3.7 Non-lazy list widgets
- **Files:** notifications, expenses, itinerary lists (where `ListView` children
  are built eagerly)
- **Severity: LOW.**
- **Finding:** Eagerly-built item children render all rows on every frame.
- **Fix (planned):** `ListView.builder` for non-trivial lists.

### 3.8 No in-flight dedup / short cache on idempotent GETs
- **Files:** `apps/mobile/lib/data/datasources/api_client.dart`
- **Severity: MEDIUM.**
- **Finding:** Two widgets firing the same GET concurrently (or a re-fetch right
  after mount) each issue a full HTTP round-trip; identical reads are repeated
  with no sharing.
- **Fix (planned):** In-flight dedup for identical `GET path+query` while a
  request is running (share one future), plus a tiny TTL memo (e.g. 2s) for
  idempotent reads. Never caches mutations.

---

## 4. Infrastructure — Valhalla

- **Status: already production-shaped.** `infra/valhalla/docker-compose.yml`
  provides `restart: unless-stopped`, a `/status` healthcheck (30s interval,
  5s timeout, 3 retries, 30s start period), `deploy.resources` limits
  (memory 4g / cpus 4 default, overridable), reservations, and json-file log
  rotation (10m × 3). The Dockerfile pins a versioned Valhalla image and the
  entrypoint downloads the extract and builds tiles exactly once.
- **Finding (LOW):** no documented capacity math. Under 3k concurrent users the
  assumed workload is: trip planning + navigation reroutes hitting Valhalla
  rarely (not per-tick), so a single mid-size instance is plausible, but nothing
  states expected RPS or how many replicas/cores are needed.
- **Fix (planned):** Document expected capacity, unit sizing guidance, and
  scaling signals in `infra/valhalla/README.md` (metrics to watch, when to add
  replicas / raise cpus & memory). No code change.

---

## 5. Degradation & honesty contract (must survive every change)

- Provider failures surface as typed errors with `retryable` flags and the
  friendly copy already used today: "Route data is temporarily unavailable…",
  "Search is temporarily unavailable", "Nearby places are temporarily
  unavailable". No change to copy or status codes.
- No fabricated routes/POIs/ETAs; `nearbyDegraded` continues to be returned so
  the client never claims "no places found" when the provider is down.
- No GPS coordinates, tokens, API keys, or private data in logs (dev navDiag
  logs metrics only, not raw coordinates — unchanged).
- Rate limits and caches are documented, bounded, and never so tight that a
  legitimate user's navigation (sparse reroutes), planning, or search (debounced
  typing) is blocked.

---

## 6. Fix plan (priority order)

1. **Backend CRITICAL/HIGH:** geocoding timeouts + cache (1.1); route-nav single
   route (1.2); toll batch (1.3); places/stays bbox pushdown (1.4); rate limits
   + clientKey (1.5); search parallelize + sanitize (1.6); trip-calculate
   parallelize (1.7); Overpass timeout align (1.8).
2. **DB (2.x):** new migration with justified indexes incl. `pg_trgm`.
3. **Flutter HIGH/MEDIUM:** search debounce + stale guard (3.1), provider
   `.select()` (3.2), nav tick coalescing (3.3), projection index cache (3.4),
   places parallel + category cache (3.5), Supabase init non-blocking (3.6),
   lazy lists (3.7), ApiClient GET dedup (3.8).
4. **Docs (4.x):** Valhalla capacity README.
5. **Tests:** dedup, cache expiry/key correctness, search debounce, provider
   degradation, rate limiting, route-request dedup, reroute protection,
   concurrent-request protection, response parsing, error handling.
6. **Report:** `PHASE_4_PERFORMANCE_REPORT.md` with measured before/after and
   honest limits (per-isolate limiter, no load-test claim without a controlled
   test against infra we own).
