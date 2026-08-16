# Phase 4 — Performance, Scalability & Traffic-Hardening Report

**Phase:** 4 (Performance + Scalability + ~3,000 concurrent users)
**Baseline commit:** `21fef5d` (Phase 3B)
**Companion document:** `PERFORMANCE_AUDIT.md` (root) — full findings + fix plan

---

## Scope

Phase 4 hardens Route2Go for scalable production traffic (~3,000 concurrent active
users) using **measured, safe optimizations only**:

- No rearchitecting, no fabricated routes/POIs/ETAs, no fake GPS, no paid APIs.
- No load tests were run against public Photon/Overpass/Valhalla instances; no
  load-test numbers are claimed anywhere in this report.
- Off-route policy (300 m trigger / 120 m recovery / 3-sample confirm / dedup /
  backoff), guest-mode behavior, and all 25 regression items are unchanged.
- Degradation is honest: typed `retryable` errors, unchanged friendly copy,
  `nearbyDegraded` still returned.

## Gate results after this phase

| Gate | Baseline | After Phase 4 |
|---|---|---|
| `flutter analyze lib test` | 0 errors / 9 info | 0 errors / **7 info** (all pre-existing; formatting resolved one) |
| `flutter test` | 68/68 | **74/74** |
| `flutter build apk --debug` | green | green |
| `flutter build web` | green | green |
| `deno check` (all 19 function dirs) | clean | clean |
| `deno test` | 76/76 | **87/87** |
| `deno fmt --check` (changed files) | — | clean |
| `dart format` (changed files) | — | clean |

## Backend (Supabase Edge Functions)

### Request-level rate limits (per-isolate, keyed on the trusted client IP)
| Function | Rate limit |
|---|---|
| `route-nav` | 30/min |
| `itinerary-generate` | 30/min |
| `trip-calculate` | 60/min |
| `places-near-route` | 120/min |
| `stays-near-route` | 120/min |
| `search` | 120/min |
| `geocode` | 120/min (pre-existing) |
| `poi-search` | 60/min (pre-existing) |

- **Client-key hardening:** `clientKey` now uses the **last** `x-forwarded-for`
  hop (gateway-appended and trusted). Leading hops are spoofable and are no
  longer honored — a spoofed `x-forwarded-for` can no longer bypass a limit.
  Covered by tests.
- New `rateLimitGuard(req, max, windowMs, reqId)` helper returns a typed 429
  `Response` with `Retry-After` (replacing the inline reject pattern in the
  search function). Covered by tests.

### Network reduction / provider load
- **Routing:** Valhalla now uses a single request (`alternates: 0`, no second
  no-toll call) via new `getSingleRoute` on the provider interface (Mock returns
  `recommended`). Still retries once on network/5xx only.
- **Tolls:** N+1 per-road queries replaced by **one batched query** with a union
  bounding box (pad 0.05°, `limit=500`). Provider failure → `confidence:
  "unavailable"` (honest degradation, unchanged contract).
- **POI / Overpass:** query timeout aligned to the client's abort budget (15 s → 10 s).
- **Geocoding:** 6 s timeouts via `fetchWithTimeout` on both Photon and Nominatim
  adapters; in-memory `GeocoderCache` (TTL 30 min, 64 entries, LRU-style eviction,
  injectable clock + `clear()` for tests) covers forward and reverse lookups.

### SQL pushdown
- `places-near-route`: bounding-box filter pushed into PostgREST instead of
  post-filtering every row. Box is computed superset-safe
  (`padDeg = min(radiusKm/100, 5)`) so results are unchanged.
- `stays-near-route`: same bbox pushdown, **gated on a finite `maxDistanceKm`**
  so the legacy path (no distance filter) behaves exactly as before.
- `search`: ilike pattern is sanitized before entering PostgREST filters
  (`%`, `*`, `,`, `(`, `)`, `.`, quotes, backslashes → text). Filter injection
  and full-table wildcard widening are both prevented. Pure helper lives in
  `_shared/searchSanitize.ts` and is unit-tested. Geocode + POI now run in
  parallel (single combined latency instead of serial).

### Concurrency
- `trip-calculate`: routing, phase flags, and fuel price resolve concurrently
  (was serial). `resolveFuelPrice` never rejects.

### Database migration `0008_performance_indexes.sql`
All indexes are justified by real query shapes:
- `pg_trgm` GIN indexes on `places(name)`, `hotels(name)`, `hotels(city)` — for
  `ilike '%term%'` search.
- `notifications(user_id, created_at DESC)` + partial `(user_id) WHERE read_at IS NULL`
  — for the inbox and unread badge.
- `audit_logs(action, created_at DESC)` — for the admin action feed.
- No affiliate index: affiliate rows are count-only queries.

## Flutter app

### Search (home map screen)
- **Debounce:** keystrokes are debounced 300 ms before querying (a burst of
  typing fires one request). Tested with a counting stub.
- **Stale-guard:** a monotonic request token drops out-of-order responses, so a
  slow previous query can never overwrite a newer one.

### HTTP layer (`api_client.dart`)
- **In-flight dedup:** identical concurrent GETs share one HTTP round-trip.
- **Short memo:** successful GET answers are memoized for 2 s (keyed by path +
  sorted query params + guest flag), so repeated reads within the TTL skip the
  network. Mutations are never cached or deduped.
- Covered by a fake-`HttpClientAdapter` test that counts transport requests.

### Providers
- `navigation_provider`: per-GPS-tick writes are coalesced into a single
  `copyWith` (position, status, progress, next maneuver, distance) instead of N
  separate notifications. Voice announcements still bucket via the original
  distance logic.
- `places_provider`: places + categories fetched in parallel (record `.wait`),
  categories cached so the nearby list can repaint without refetching.

### Launch
- `main.dart`: `Supabase.initialize` is wrapped in a 3 s timeout and its failure
  is tolerated (no lib code reads Supabase directly), so launch can never be
  blocked by a slow/unreachable Supabase.

## Deferred (documented, not implemented)

These remain LOW/no-regression-risk items from the audit and were deliberately
deferred; they are captured here so they can be picked up later:

1. **Trip GET `?summary=1`** (geometry stripping on list responses) — the trips
   list is bounded and the response is small; keep for a later data-shape pass.
2. **Provider `.select()` rollout** on home/route-results/trip-detail/confirm
   screens — touches many widgets; the tables already return only the needed
   columns via views where it matters.
3. **O(n) projection segment-index cache** — bounded screens; the hot path was
   already reduced by per-tick coalescing.
4. **Valhalla capacity README** (`infra/valhalla/README.md`) — operational
   documentation to write when the Valhalla host is provisioned.
5. **`ListView.builder` for notifications/expenses** — backend caps these lists
   at ≤100 rows; a mixed header+items sliver refactor carries regression risk
   disproportionate to the LOW impact.

## Honest limits

- Rate limits are **per-isolate**, in-memory fixed-window counters. They protect
  each warm instance and prevent accidental bursts; they are not a distributed
  quota system. Supabase scales isolates per region, so capacity at ~3,000
  concurrent users comes from Supabase's edge function scaling plus these
  per-instance guards — not from this app's code alone.
- No load test was executed in this phase (would require controlled infra we own
  and a non-public Valhalla/Overpass target). The above are structural
  improvements with unit-level proof (dedup, debounce, caching, batching,
  SQL pushdown, concurrency), not a measured throughput claim.
- GNSS validation on the physical OnePlus device remains **pending** (requires
  the user to take the phone outdoors); it is independent of this phase's changes.

## Tests added in this phase

- `supabase/functions/phase4_perf_test.ts` — 10 tests:
  `GeocoderCache` (hit, TTL expiry, exact keying, eviction), `sanitizeSearchPattern`
  (plain, filter chars, wildcards, whitespace), `rateLimitGuard` (under/over cap,
  429 + `Retry-After`, last-hop trust).
- `apps/mobile/test/api_client_dedup_test.dart` — 4 tests: concurrent dedup,
  memo hit, query-parameter keying, cross-path separation.
- `apps/mobile/test/maps_mode_test.dart` — 2 new widget tests: keystroke burst
  → one request, pause-then-type fires again (via counting stub).
