# ROUTE2GO PRODUCTION COMPLETION REPORT

Phase: Maps-mode UX / product completeness + production scalability.
Baseline checkpoint: `1a5ab87` ("perf: harden Route2Go for scalable production traffic").
Date: 2026-08-17.

This report is deliberately honest, per the project rule: **do not fake
unavailable functionality.** Every item below is either implemented and
verified, or explicitly marked not-run / blocked.

---

## 1. What changed in this phase (no rewrite)

The audit confirmed the existing Flutter + Supabase Edge Functions + Valhalla +
Photon/Overpass + OSM architecture already delivers most of the maps-mode
surface. This phase **improved and extended it**; no engine, provider, policy or
schema was rewritten.

### 1.1 Start Navigation bug fix (highest-value item)

**Before:** tapping the Map tab's "Start Navigation" called
`liveTripProvider.startDirect()` with a zeroed synthetic route
(`geometry: null`, `steps: []`, `provider: 'test'`) and **never pushed the
live-trip screen** — navigation started invisibly with no route geometry, no
ETA, no drawn route.

**After:** the Map tab shares one `_prepareRoute()` helper between Directions and
Start Navigation:

1. Resolves the origin (current GPS via the existing `GeocodingRepository`, or
   the location picker with the same `PermissionExplainer` flow).
2. Primes the shared `TripPlanningForm` and runs `tripCalculationProvider.calculate()`
   → real Valhalla route with alternatives.
3. Directions → pushes `AppRoutes.routeResults` (existing preview + alternatives).
4. Start Navigation → `startDirect()` with the **real selected route**, then
   pushes `AppRoutes.liveTrip`.

The in-app navigation engine (`NavigationNotifier`), off-route policy (300 m
trigger / 120 m recovery / 3-sample confirm / 20 s cooldown), reroute-from-
current-location, TTS and arrival detection are all **unchanged** — this fix
only feeds them a real route and actually opens the screen.

### 1.2 Destination sheet completeness

- **Distance from you**: straight-line distance (`GeoMath.haversineKm`) shown
  when a current location exists; re-computed per selection, never cached.
  Honest by construction — no distance line when location is off.
- **Save to favorites**: full-width action for `place` results via the existing
  `favorites.save_place` endpoint; guests get the standard sign-in gate. Hotels
  and routes are intentionally not saveable here (the schema only persists
  saved_places and saved_trips; see `supabase/functions/favorites/index.ts`).
- **Share honesty**: the share payload previously ended with a fabricated
  `"Route: Calculating..."` (nothing was being calculated). It now carries
  name, address and coordinates only.

### 1.3 Map zoom controls

- Zoom in/out buttons on the map tab (pinch/scroll zoom still works). They are
  hidden while the inline search-results sheet is open so the controls never
  sit on top of the sheet and swallow its taps (a regression found by the
  widget tests during this pass).

### 1.3 What was already working (reused, not rebuilt)

- Search bar with 300 ms debounce + monotonic stale-guard; worldwide search via
  `/search` (Photon + Overpass, `nearbyDegraded` honesty signal).
- Share payload from the destination sheet.
- Route preview with alternatives (`route_results_screen.dart`).
- Recenter + current-location marker on the map.
- OSM tiles via `Route2GoTileLayer` (styled → OSM fallback).
- `LiveTripScreen`, `startDirect`, maneuver engine, off-route policy, TTS.

### 1.4 Maps-mode completion prompt pass (features 1–10, additive)

Applied additively on top of the maps-mode pass. No rewrites, no Phase 5, no
second GPS stream / engine / `LocationMarker`, no Google APIs, no fake data.

1. **SearchResult category + city** — `/search` now enriches every result kind:
   DB places → real place-category name; hotels → `Hotel` + DB `city`; Photon
   geocodes → `osm_value`/`type` + first `city/town/village/state/country`
   property (new pure helpers `photonCategory`/`photonCity`); Overpass POIs →
   OSM category + `addr:city` (`PoiResult.city`). Never fabricated: absent when
   the provider returns nothing.
2. **Destination sheet category · city** — rendered as `Cafe · Bengaluru`;
   `Place · <city>` is the honest unknown-category fallback.
3. **Compass** — map rotation enabled; needle tracks the real camera bearing
   (`mapEventStream` + `camera.rotation`); tap → north-up (`moveAndRotate`);
   recenter also re-orients north.
4. **Layer switcher** — `Route2GoTileLayer` gained `styleMode`; map-tab button
   toggles Standard/Styled, persisted locally (`PreferencesStore.map_style`),
   attribution + OSM fallback preserved; `MapTileConfig` gained an injectable
   `styledTileProviderFactory` for fully-offline tests.
5. **Route share** — destination-sheet share stays place+coords (no route exists
   there); the route-results screen (a real route always exists) gained a share
   action emitting route info + both coordinates; saved-trip share now includes
   distance + duration. `buildDestinationShareText`/`buildRouteShareText` are
   pure, unit-tested. **No `route2go://` deeplink** — the app has no URL-scheme
   config, so a non-functional link is never emitted.
6. **Inline route preview** — SKIPPED: the destination sheet opens before any
   route exists; a preview would be fabricated or force an expensive Valhalla
   call. Directions/Start Navigation already surface the real route.
7. **Current-location UX** — already one-shot by design (last-known position,
   immediate recenter, no second GPS stream); verified, unchanged.
8. **Recent searches** — `PreferencesStore.recent_searches` (cap 10,
   case-insensitive dedupe, device-only); map-tab search records queries and
   shows a "Recent searches" sheet on empty, interacted search.
9. **Performance targets** — `docs/PERFORMANCE_TARGETS.md` (map first frame
   <1 s, search p50 <400 ms, route p95 <2 s), stated as targets, never claims.
10. **Load-test plan** — `LOAD_TEST_PLAN.md` (k6 scenarios, Valhalla scaling +
    LB, latency/error thresholds, node-kill recovery, results template). The 3K
    figure remains a target, not a measurement.

---

## 2. Files changed / created

| File | Change |
|---|---|
| `apps/mobile/lib/presentation/screens/home/home_screen.dart` | `_prepareRoute()` shared helper; Start Navigation now fetches the real route + pushes `AppRoutes.liveTrip`; destination sheet gains distance + Save + category/city; compass; layer switcher; recent searches sheet; honest share payload |
| `apps/mobile/test/maps_mode_test.dart` | 5 → 17 tests (router-backed harness + fakes; distance/Save/Start Navigation/zoom/category·city/compass/layer/recent-searches/route-results share) |
| `apps/mobile/lib/presentation/screens/trip_planning/route_results_screen.dart` | AppBar "Share route" action (route info + coordinates) |
| `apps/mobile/lib/presentation/screens/trips/trip_detail_screen.dart` | Share payload now includes distance + duration |
| `apps/mobile/lib/presentation/widgets/sharing_widgets.dart` | Pure `buildDestinationShareText` / `buildRouteShareText` helpers |
| `apps/mobile/lib/core/local/preferences_store.dart` | `recent_searches` (cap 10) + `map_style` persistence |
| `apps/mobile/lib/core/config/map_tile_config.dart` | `Route2GoTileLayer.styleMode` + injectable `styledTileProviderFactory` |
| `apps/mobile/lib/domain/entities/misc_entities.dart` | `SearchResult.category` / `city` |
| `supabase/functions/_shared/providers/geocodingProvider.ts` | `photonCategory`/`photonCity` + `GeocodedPlace.category`/`city` |
| `supabase/functions/_shared/providers/poiProvider.ts` | `PoiResult.city` (from `addr:city`) |
| `supabase/functions/search/index.ts` | `category`/`city` on all result kinds |
| Deno tests | `geocodingProvider_test.ts` +3, `poiProvider_test.ts` +1 |
| `apps/mobile/test/share_payloads_test.dart` | New — 6 pure payload unit tests |
| `docs/PERFORMANCE_TARGETS.md` | New — performance targets (as targets) |
| `LOAD_TEST_PLAN.md` | New — k6 load-test plan + acceptance criteria |
| `BUILD_STATUS.md` | New "Maps-mode completion prompt pass (2026-08-17)" section |
| `ROUTE2GO_PRODUCTION_COMPLETION_REPORT.md` | This report (incl. load-test plan, section 5) |

No migration or schema files changed.

---

## 3. Verification (all gates green on this phase's tree)

| Gate | Result |
|---|---|
| `flutter analyze lib test` | 0 errors, **7 infos** (exact baseline parity — all pre-existing `use_build_context_synchronously` in untouched files; **no new lints**) |
| `flutter test` | **91/91** (baseline 78 + 13 new) |
| `dart format --set-exit-if-changed` | clean |
| `flutter build apk --debug` | ✓ |
| `flutter build web` | ✓ |
| `deno check` on all 19 function dirs | clean |
| `deno test --allow-env` | **91/91** (baseline 87 + 4 new) |

### Prior-phase context (unchanged facts, recorded here once)

- Supabase project `ginurkwywgqpcvzpfaop` (ap-northeast-2) ACTIVE_HEALTHY,
  linked; all 20 edge functions deployed ACTIVE; `VALHALLA_BASE_URL` server-side.
- `route-nav` live-verified `provider: valhalla` (148.4 km / 230 min, 31
  maneuvers); `/trip-calculate` 2 alternatives; `/search` worldwide (Hawaii, no
  India bias); `/poi-search` 40 Overpass results; invalid Firebase token → 401.
- Configured QA APK (same dart-defines: `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
  `SUPABASE_FUNCTIONS_URL`), SHA256 `cb8ca2d00018e084ed2a24dc0c3e5265959c8956217be6aeebe3c9dfd5d97da8`,
  installed on OnePlus CPH2375 (serial `1fe29b18`): launch clean, no crashes,
  permissions granted, mem ~394–407 MB PSS (debug), CPU idle, no secrets in APK.
- Screenshots for human review: `/tmp/route2go_qa/`.

---

## 4. Honest limitations (not code-blockers)

1. **GPS / TTS / moving-navigation validation blocked by environment.** The QA
   device was indoors (satellites=0, last fix ~9 days old). The full live-navigation
   experience (turn-by-turn, TTS, reroute, arrival) needs a human to take the
   OnePlus outdoors. This model also has no image input, and Flutter's map
   surface exposes no accessibility tree to uiautomator, so in-app visuals must
   be confirmed by a person from the `/tmp/route2go_qa/` screenshots.
2. **3K concurrent-user performance is NOT proven.** Unit/integration tests do
   not demonstrate load. It requires the controlled load test in `LOAD_TEST_PLAN.md`
   on owned infrastructure. This report does not claim it.
3. **No route deep-link.** Route2Go has no URL-scheme configuration, so shared
   routes carry coordinates instead of a `route2go://` link (which would be
   non-functional). Adding app deep links is a separate platform-config task.

---

## 5. Production scalability: architecture + load-test plan (not yet run)

### 5.1 Target and honesty rule

Target: 3,000 concurrent users. The rule: **3K may only be claimed after a
controlled load test on owned infra** (self-hosted Valhalla, not the public
`valhalla1.openstreetmap.de` demo). Until then the number is a target, not a
result.

### 5.2 Realistic load profile (3K users)

Assume a 1-hour drive-phase during peak: not all 3K users route simultaneously.
A realistic profile:

- 3,000 concurrent sessions; navigation (continuous GPS to the app, no routing
  provider traffic) dominates.
- Route requests burst around drive start: ~10% start a route in the same
  minute → ~300 `route-nav`/`trip-calculate` calls/min ≈ **5 req/s** sustained,
  ~12 req/s peak (p99 user actions).
- Search/geocode/POI: ~1,500 searches/min (~25 req/s) spread over the day.
- Reroutes during travel: ~1–2 per user per trip → ~60–100/min additional
  `route-nav`.

Every user action maps to exactly one edge-function call; no client polling,
no WebSocket, no background refresh loops (verified in Phase 4 audit).

### 5.3 Component capacity plan

| Component | Sizing / strategy | Owner |
|---|---|---|
| Edge Functions (Supabase) | Stateless, per-isolate; scale horizontally with Supabase function instances. Rate limits already keyed to the last `x-forwarded-for` hop (`_shared/rateLimit.ts`) so open endpoints can't be proxied | Supabase |
| Valhalla | **Multi-instance + load balancer.** Request-level routing: one LB in front of N Valhalla containers (healthcheck `GET /status` already in `infra/valhalla/docker-compose.yml`); scale by req/s measured in the load test. Do NOT use the public demo for production | Self-hosted infra |
| Postgres | `0008_performance_indexes.sql` (pg_trgm GIN etc.) already in place; DB traffic is light (edge functions → Valhalla dominate) | Supabase |
| Client | GET dedup + 2 s memo (`api_client.dart`), 300 ms search debounce + stale guard, no per-frame provider calls (all verified) | Done |

### 5.4 Load test plan (to run before claiming 3K)

The full, runnable procedure now lives in **`LOAD_TEST_PLAN.md`** (root): k6
scenarios for the 5.2 profile, Valhalla scaling + LB setup, latency
p50/p95/p99 + error-rate acceptance criteria, a node-kill recovery drill, and a
mandatory results template. Summary of the procedure:

1. **Environment**: owned Valhalla cluster (1 → N nodes) + Supabase project.
   Record node CPU/RAM and req/s per node; never test against the public demo.
2. **Tooling**: k6 (or similar) scripts generating the 5.2 profile, not uniform
   fire-and-forget.
3. **Metrics**: req/s, p50/p95/p99 latency, error rate per endpoint
   (`route-nav`, `trip-calculate`, `search`, `geocode`, `poi-search`), Valhalla
   CPU/RAM, edge-function cold-start overhead, rate-limit 429 count.
4. **Pass criteria**: p95 ≤ 3 s for route calculation, p95 ≤ 1.5 s for
   search/geocode, error rate < 1%, no Valhalla node saturation at 3K.
5. **Recovery test**: kill a Valhalla node mid-test; confirm LB drains it and
   `502`/reroute retry behavior is bounded (existing 10 s AbortSignal + bounded
   retry policy).
6. **Report honestly**: results table or explicit "not run" — never extrapolate.

### 5.5 Performance architecture notes (no code changed)

- Routing: `route-nav`/`trip-calculate` → `ValhallaRoutingProvider` (10 s timeout,
  bounded retry, never retries 4xx). Client GET dedup + memo prevents duplicate
  in-flight calls. Search debounce + stale-guard prevents per-keystroke upstream
  load. Rate limiting protects Photon/Overpass.
- Deferred (documented in `PHASE_4_PERFORMANCE_REPORT.md`, not blocking): trip
  GET `?summary=1`, provider `.select()` rollout, O(n) projection cache,
  `ListView.builder` for notifications/expenses.

---

## 6. Accessibility / web / security posture (audit conclusions)

- **Accessibility**: existing icon+tooltip+label pairs; the new compass, layer
  switcher and zoom controls are 44×44+ `IconButton`s with tooltips. The map
  surface itself still exposes no OS accessibility tree (flutter_map
  limitation) — a full WCAG pass is a separate, human-led task, not silently
  claimed here.
- **Responsive web**: `flutter build web` green; layout uses the existing
  responsive patterns.
- **Security**: no service-role JWT, Valhalla creds or private keys in Flutter;
  config via `--dart-define`. Public anon config is embeddable by design. No
  new secrets introduced.
- **No Google quota bypass** and **no Google proprietary APIs** used; all
  providers are open-source or self-hosted. No fabricated traffic / ETA /
  ratings — provider failures degrade to honest copy ("temporarily
  unavailable"), never "No results".

---

## 7. Recommended follow-ups (explicitly not done here)

1. Physical-device drive test (GPS/TTS/reroute) — needs a human outdoors.
2. Run the section 5.4 load test on owned infra; publish results.
3. Human review of `/tmp/route2go_qa/` screenshots for visual QA.
4. WCAG/44×44 accessibility pass as a separate human-led item.