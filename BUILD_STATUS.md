# BUILD_STATUS.md

Generated: 2026-08-14. This document is deliberately honest about scope — per the
project's own rule: "do not fake unavailable functionality."

## What's implemented (real, reviewed code)

| Area | Status |
|---|---|
| Firebase config: `firebase_options.dart` has real values for project `route2go-da5c3` (Android + iOS `com.route2go.route2go`); `google-services.json` present | Done |
| Google Sign-In (real OAuth): `google_sign_in` wired in `AuthRepository.signInWithGoogle()`; SHA-1 debug fingerprint registered in the Firebase console; verified live (account picker + 2-Step completed by user) | Done |
| Supabase linked to correct project `ginurkwywgqpcvzpfaop`; all 6 migrations pushed; all 18 Edge Functions deployed | Done |
| `route-nav` verify_jwt fixed to `false` (Supabase gateway was rejecting Firebase tokens) | Done |
| Secrets set: `FIREBASE_PROJECT_ID`, `ROUTING_PROVIDER_BASE_URL`, `GEOCODING_PROVIDER_KEY=nominatim`, `USE_LIVE_FUEL_PRICES=true`, `USE_LIVE_TOLL_DATA=true` | Done |
| Live providers verified: Valhalla routing (Bengaluru→Mysuru + London→Manchester + waypoints + round trip, 5 labeled options), Nominatim geocoding (forward + reverse), fuel/toll flags on | Done |
| Map tiles verified rendering on emulator (OSM; real cause of blank map was emulator DNS — fixed with `-dns-server 8.8.8.8`) | Done |
| `flutter analyze` clean; `flutter test` green (**63 tests**: original 18 + auth/back-nav/router suites + 2 new critical-path E2E tests) | Done |
| Critical-path E2E integration test (`apps/mobile/test/critical_path_integration_test.dart`): calculate → compare (selectRoute) → places → stays → itinerary → save via real repositories + fake ApiClient, 2 tests | Done |
| `dart format` — repo was never format-clean (106 files); formatted so CI's `--set-exit-if-changed` gate passes; fixed 2 latent `curly_braces` lints the formatter surfaced | Done |
| Deno: `deno check` clean across all 18 functions + shared modules; **16 unit tests** pass (10 itinerary scheduler + 6 new fuel-cost engine) | Done |
| Database CI validated locally: `supabase start` → `db reset` (6 migrations apply) → pgTAP RLS suite **10/10** pass | Done |
| CI workflows (`mobile_ci`, `functions_ci`, `database_ci`, `release`) — fixed gaps (functions_ci now typechecks `route-nav` + tests fuel engine); each validated locally; not yet executed in GitHub Actions | Written, locally validated |
| iOS ATT runtime prompt: `TrackingPermissionService` requests tracking authorization at first launch and disables analytics unless authorized (no-op on Android; conservative disabled-on-failure) | Done |
| Android release signing: `build.gradle.kts` reads `android/key.properties` when present, falls back to debug keystore otherwise; `key.properties.template` with keystore generation steps (gitignored) | Done |
| Legal docs: Privacy Policy + Terms of Service rewritten comprehensively (DPDP Act 2023, IT Act 2000 + Intermediary Rules, Consumer Protection Act 2019, BNS framing) with real contact details — **Together (Lakshmipathy and Team)**, route2go1@gmail.com, JP Nagar Kothanuru Dinne, Bengaluru 560076 | Done (draft, needs legal review) |
| Phase 2 EV/CNG cost paths: `computeFuelCost` extracted to `_shared/fuelCostEngine.ts` (pure, unit-tested); `trip-calculate` reads `phase2_ev`/`phase2_cng` flags live; EV cost = kWh × ₹/kWh, CNG cost = kg × ₹/kg; gated + honest (null/unavailable when off); live-verified flag off→unavailable, on→₹182.53 | Done |
| App EV/CNG wiring: `trip_repository` sends `ev_efficiency_kwh_per_km`/`cng_mileage_km_per_kg` instead of `mileage_kmpl`; `ev_price_per_kwh` passed through; plan screen labels adapt (kWh/km, km/kg, per-kWh) | Done |
| Supabase schema (29 tables), RLS, pgTAP RLS suite (`rls_trips.sql` + `rls_audit.sql`), 17+1 Edge Functions, Firebase token verification, itinerary scheduler | Done (from prior phase) |
| Flutter app surface: onboarding, home, plan trip, route results, budget tracker, places/stays/itinerary/confirm/live trip, vehicle garage, expenses (group-split shell), notifications+FCM, profile/settings/privacy/terms/help/delete-account, favorites/search, admin dashboard (server-gated RBAC) | Done |
| Phase-2 gates: `Phase2Gate` widget gated on `/feature-flags`; group-split, offline cache, weather are gated shells | Done (shells) |
| **OSRM → Valhalla migration**: `_shared/providers/valhalla.ts` (pure request build + response parse + polyline6/GeoJSON shape decoding + maneuver/segment mapping + metric-based labelling + dedupe/cap-5); `ValhallaRoutingProvider` behind `getRoutingProvider()` (activated by `VALHALLA_BASE_URL`, legacy `ROUTING_PROVIDER_BASE_URL` alias); no-route error codes → empty → caller 404, other errors → 502; round trip = honest out-and-back; instructions verbatim from Valhalla; 2 requests (tolls + no-tolls), toll-free failure non-fatal | Done |
| Valhalla live-verified: Bengaluru→Mysuru (recommended 146.2 km/224 min + no_toll/fastest/shortest), London→Manchester (5 labelled options), waypoints, round trip (288.3 km out-and-back) on the dev demo (`valhalla1.openstreetmap.de`) | Done |
| Valhalla Deno tests: `valhalla_test.ts` (22) + `routingProvider_test.ts` (6) — request build, polyline6 round-trip, both shape forms, maneuvers verbatim, segments, labelling/dedupe/cap, no-route codes, provider selection, bearer auth, worldwide coordinates | Done |
| Self-hosted Valhalla: `infra/valhalla/` Dockerfile + compose + entrypoint (download extract → build admin/tiles/extract once → serve :8002) | Done |
| Map tiles: `MapTileConfig` abstraction (`core/config/map_tile_config.dart`) with `MAP_TILE_URL_TEMPLATE`/`MAP_TILE_ATTRIBUTION` dart-defines + `TransparentTileProvider`; all 3 map screens read it; widget tests offline (no 400 noise from flutter_test's mock HttpClient); attribution + UA now single-source | Done |
| Geocoding: client-side `GeocodingProvider` abstraction (`data/datasources/geocoding_providers.dart`; Supabase default, mock offline, `GEOCODING_PROVIDER` dart-define); no autocomplete-on-keystroke to public Nominatim (350 ms debounce + proxy via `/geocode` edge function) | Done |
| Docs: `VALHALLA_SETUP.md`, `MAP_ARCHITECTURE.md`, `GEOCODING_SETUP.md`, `TILE_PROVIDER_SETUP.md`, `infra/valhalla/README.md`; README/BUILD_STATUS/API_SETUP_GUIDE/CREDENTIALS_REQUIRED/PRIVACY_POLICY updated OSRM→Valhalla | Done |

## Tests run in this session

- `flutter analyze` → No issues found.
- `flutter test` → **63/63** pass.
- `deno check` on all 18 functions + shared modules → clean.
- `deno test` → itinerary scheduler **10/10**, fuel-cost engine **6/6**, Valhalla **22/22**, routingProvider **6/6** (44 total).
- Database CI (local): `supabase start` + `db reset` (6 migrations) + `supabase test db` → **10/10** (rls_trips 6 + rls_audit 4).
- Live provider smoke: Valhalla routing (Bengaluru→Mysuru + London→Manchester + waypoints + round trip, 5 labeled options); Nominatim geocoding (forward + reverse); fuel/toll flags on.
- `flutter build apk --debug` + `flutter build web` → both succeed.
- Live EV gating: `phase2_ev` off → `fuel_cost: null` / `unavailable`; on → `fuel_cost: 182.53` / `calculated`; restored to off.

## Known gaps to close before this is production-safe

1. **Service-role key** was pasted into chat during setup (user kept the old
   key; **must rotate before go-live**). The key is only used server-side
   (Supabase injects `SUPABASE_SERVICE_ROLE_KEY` into Edge Functions) and is
   never in the app or committed.
2. **iOS `DEVELOPMENT_TEAM` not set** in the Xcode project — add the Apple Team
   ID before `flutter build ipa` (release blocker).
3. **Android release keystore** — `key.properties` does not exist yet; release
   builds fall back to debug signing (rejected by Play Console). Generate a
   keystore and fill `android/key.properties` (see template).
4. **Legal docs are comprehensive drafts** with real contact details; still need
   a qualified legal review before store submission.
5. **CI workflows not yet executed in GitHub Actions** — validated locally; run
   them once on a real push/PR to confirm the runner environment (deno version,
   Docker for database_ci).
6. **DB-backed tables empty** — `places`, `hotels`, `fuel_prices`, `stays` have
   no data (licensed feeds/API keys not in repo); DB-backed functions return
   honest empty/unavailable results via ConfidenceBadge until feeds are wired.
   Trip calculation, trip saving and route saving all work; fuel cost shows
   "unavailable" (stored as NULL in `routes.fuel_cost`, which is now nullable)
   until a licensed fuel-price feed is wired.
7. **Phase 2 bodies** (group split, offline cache, weather) remain gated shells
   behind `phase2_*` flags; EV/CNG cost paths are now implemented.
8. **Physical-device testing** of the full Live Trip flow (background location)
   still recommended; currently verified on emulator.
9. **Google 2-Step** — real-device sign-in needs the user's phone approval
   (completed on emulator).

## Fixed 2026-08-14 (post-rotation verification pass)

- **Lazy user provisioning**: first authenticated call now creates the
  internal `users` row (and default profile) from the verified Firebase
  identity, instead of 404ing with USER_NOT_FOUND. All 18 functions redeployed
  (fixed in `_shared/auth.ts` + `trip-calculate/index.ts`).
- **Routes insert failure**: `routes.fuel_cost`/`toll_cost` are now nullable
  (migration `0007_routes_nullable_costs.sql`), so a trip with an unavailable
  fuel price saves cleanly instead of erroring "Could not save route options".
- **Onboarding skip**: returning users who finished onboarding now go straight
  to Home; `onboarding_complete` was written but never read. Fixed in
  `splash_screen.dart` + `onboarding_screen.dart`.
- End-to-end verified on emulator: Plan a Trip (Mysuru→Bengaluru) → route
  options + comparison table → trip saved → Trips list → trip detail →
  share/expense/rename → vehicles add → search → profile → map.

## Required external credentials (cannot be created for you)

- Firebase project (done: route2go-da5c3, Auth providers enabled, SHA-1 added)
- Supabase project (done: ginurkwywgqpcvzpfaop, linked + deployed)
- Apple Developer account + signing certificate + **Team ID** (for iOS release)
- Google Play Console account + **release keystore** (for Android release)
- Hotel/affiliate partner account(s) for the Stays flow (optional for launch)

## Production hardening pass (2026-08-14)

Applied on top of the OSRM→Valhalla migration. No behavioral change to Phase 1/2
navigation. Baseline + results all green (analyze clean, Flutter 63/63, Deno
50/50, APK + Web builds PASS).

- **Routing failure handling**: `ValhallaRoutingProvider` now uses a 10 s
  `AbortSignal.timeout` per attempt and bounded retry — the tolls-allowed
  request retries at most once after 500 ms; the toll-free request never
  retries. Retries only on network errors/timeouts/5xx, **never 4xx**
  (Valhalla no-route codes map straight to `404 NO_ROUTE_FOUND`; other failures
  surface as retryable `502`). Covered by `routingProvider_test.ts` (5xx → one
  bounded retry, 4xx → no retry).
- **Geometry coverage**: `valhalla_test.ts` now 26 tests, including
  antimeridian polyline decode (unchanged across ±180), BLR→Mysuru lng/lat
  integrity, London→Manchester negative-longitude, and A→stop1→stop2→B waypoint
  ordering + seam dedupe.
- **Self-host hardening**: `infra/valhalla/docker-compose.yml` gained a
  `GET /status` healthcheck, memory/CPU limits + reservations (overridable via
  `VALHALLA_MEM_LIMIT`/`VALHALLA_CPU_LIMIT`), capped logging. README rewritten
  with region options A (India-only), B (regional), C (worldwide) and realistic
  infra sizing. See `infra/valhalla/README.md`.
- **Honesty/error UX**: production never falls back to the mock provider; a
  Valhalla outage yields a clear `502`, and turn-by-turn falls back to the
  honest "Following the highlighted route" text — no fabricated instructions.
- **Test fix**: `router_back_navigation_test.dart` now taps the field's InkWell
  (the real hit target) instead of the floating label text, removing the
  "would not hit test" warning without `warnIfMissed: false`.
- **Live integration check** (manual, against `valhalla1.openstreetmap.de`):
  BLR→Mysuru returned HTTP 200 in ~1 s; parsed 148.4 km / 230 min, 31 valid
  steps, 1958 valid geometry points.
- **Security scan**: no `.env`/private keys/service-role JWTs in tracked files;
  Firebase client config is public-by-design (not secrets).
- **Not verified / release blockers**: iOS `DEVELOPMENT_TEAM` still unset
  (Apple signing required); no physical-device Live Trip test yet.

## Emulator validation fixes (2026-08-14)

Findings from on-device validation (emulator-5554, Android 17, running the
`8fa1327` build with correct `--dart-define`s):

- **Route calculation "network issue" (fixed)**: `/trip-calculate` took
  12–14.5 s (Dio `receiveTimeout` is 15 s), so any variance pushed the call
  past the timeout and surfaced as `NETWORK_UNAVAILABLE`. Root cause: the
  `USE_LIVE_TOLL_DATA=true` / `USE_LIVE_FUEL_PRICES=true` secrets routed costs
  through `SupabaseTollProvider`, which ran an unindexed bounding-box query on
  `public.toll_plazas` per route segment × up to 6 route alternatives (~10 s
  total). Both flags were set back to `false` (honest, clearly "estimated"
  fallbacks) and the function was redeployed — calc now returns 2 real
  Valhalla routes in ~2 s. The toll_plazas query needs a spatial/btree index
  before re-enabling `USE_LIVE_TOLL_DATA`.
- **Search region bias (fixed)**: the Nominatim forward query had no country
  restriction, so generic queries like "temple" resolved to US places. The
  geocode provider now sends `countrycodes=in` + `accept-language=en,hi,kn`,
  and falls back to the place term after "near" when a proximity-phrased query
  returns nothing ("college near Bengaluru" → Bengaluru colleges). Nominatim
  data quality still does not match Google Maps; that is expected and
  documented.
- **"Use my location" on emulator**: no code defect — this Android 17 emulator
  image does not deliver GPS fixes via `adb emu geo fix`; use Android Studio
  Extended Controls → Location instead. Requires a real device to validate
  GPS properly.

Verification after fixes: `deno check` clean, `deno test` 50/50
(`--allow-env --allow-net`). No Flutter code changed, so the running app needs
no rebuild to pick these up.

## Saved-trip route maps (2026-08-14)

The Home → Map tab was a static placeholder ("Map view is available on your
saved trips"). It now renders a real interactive map:

- `/trip` GET (list) now returns `origin_lat/lng`, `destination_lat/lng` and
  the best route's GeoJSON `geometry` (previously only labels + cost summary,
  so no map could be drawn).
- `TripSummary` gained those fields + a `bestRouteCoordinates` getter that
  parses the GeoJSON LineString the same way `RouteOption` does.
- Map tab (`home_screen.dart`): FlutterMap with OSM tiles, one colored route
  polyline + start (trip_origin) and drop (location_on) markers per saved
  trip, auto-fit bounds, and a horizontal row of tappable trip cards
  (origin → destination, duration, distance, est. cost) opening the trip
  detail.
- Trip detail (`trip_detail_screen.dart`): added a route-map card with the
  route line, start/drop markers and an endpoint label chip.

Turn-by-turn instructions are intentionally not shown here: saved trips don't
persist maneuver steps (only geometry + metrics), and the app never fabricates
instructions — turn-by-turn remains a live-navigation feature.

## Realistic next steps for "go live"

1. ✅ Rotate the Supabase service-role key before publishing — **DONE 2026-08-14**:
   created secret key `route2go_backend`, migrated all 18 edge functions to
   resolve it from `SUPABASE_SECRET_KEYS` (fallback to legacy), redeployed,
   then **disabled the legacy anon/service_role keys**. The previously exposed
   `service_role` JWT now returns 401. The app is unaffected (it makes no
   direct Supabase DB calls; all data flows through edge functions).
2. Execute the CI workflows once in GitHub Actions and fix anything that
   surfaces on the runner.
3. Create the Android release keystore + `key.properties`; add the iOS
   `DEVELOPMENT_TEAM`; build and sign release artifacts.
4. Have the legal drafts reviewed and approved; fill the "Last updated" dates.
5. Capture store screenshots and fill Play/App Store metadata (checklist:
   `docs/STORE_COMPLIANCE.md`).
6. Test the full Live Trip flow on a physical device.
---

## Open-Source Parity Pass (2026-08-15)

Checkpoint `8fa1327` preserved; this pass adds the open-source search/tile
upgrades and verifies every screen flow. All checks green.

| Item | Status |
|---|---|
| **Photon geocoding (worldwide, no bias)**: `PhotonGeocodingProvider` in `_shared/providers/geocodingProvider.ts` is the default live adapter (`GEOCODING_PROVIDER_KEY` set); Nominatim (India-biased) stays available via `GEOCODING_BACKEND=nominatim`; "near" phrasing handled (`cafes near me` → POI search, `cafes near MG Road` → searches the place) | Done, deployed, live-verified |
| **Overpass POI search**: `poiProvider.ts` (category matcher, pure query builder/parser), `/poi-search` edge function (`verify_jwt=false`), 4-mirror failover, 30-min TTL cache, 90s failure cooldown | Done, deployed, live-verified (5/5 reliable) |
| **POI wired into UI**: LocationPicker merges Overpass POIs for category queries near the map pin; global search `/search` surfaces Photon + Overpass results as `kind: "nearby"` | Done, on-device verified ("cafes near me" → real cafes) |
| **Server tests**: `geocodingProvider_test.ts` + `poiProvider_test.ts` (photon label/map/near-phrase, category match, query build, response parse, selection, mock) | Done — deno 69 tests pass |
| **Tiles**: `MapTileConfig` gained optional styled provider (`MAP_TILE_STYLE_URL_TEMPLATE`/`MAP_TILE_STYLE_ATTRIBUTION`); new `Route2GoTileLayer` renders styled first, auto-falls back to OSM on tile error; all 5 map screens use it | Done, analyze/tests green |
| **Honesty pass**: route comparison + live-trip label disclaimers ("no live traffic data", "Est. arrival"); confirmed no traffic/real-time/guarantee claims; ratings show "No rating yet"; offline packages honest "Coming soon." | Done |
| **On-device verification**: fresh APK (correct dart-defines) installed on emulator-5554; verified Home, Map tab (saved routes + locate + permission explainer), global search (worldwide results), LocationPicker (worldwide + POI merge), honest error states | Done |
| Docs: `docs/API_PROVIDER_MATRIX.md`, `docs/DATA_SOURCES.md` new; `GEOCODING_SETUP.md` + `TILE_PROVIDER_SETUP.md` updated | Done |
| Verification: `flutter analyze` clean, `flutter test` 63/63, `flutter build apk` ✓, `flutter build web` ✓, `deno check` clean, `deno test` 69/69 | Done |

### Reliability & honesty fix (same session, committed separately)

- **POI mirror hardening**: dropped dead `overpass.kumi.systems`; ordered mirrors
  by measured responsiveness (`maps.mail.ru` → `overpass-api.de` →
  `overpass.openstreetmap.fr` → `overpass.private.coffee`); per-mirror timeout
  tightened 15s→10s; cooldown shortened 90s→45s. Measured `/search` POI success
  went from **~1/4 to 5/5**.
- **Honest degradation signal**: `PoiProvider.isDegraded()` distinguishes
  "provider unreachable" from "no POIs exist"; `/search` returns
  `nearbyDegraded`, `/poi-search` returns 502 `POI_SEARCH_UNAVAILABLE` on the
  degraded path. The Search screen now shows "Nearby places are unavailable
  right now…" instead of the misleading "No matches found."
- `jsonOk` gained a backwards-compatible optional extra-field arg.
- On-device re-verified: global search "cafes near me" → 10 real Mysuru cafes.
- Deno tests 71/71 (2 new); flutter analyze/test green; apk rebuilt + reinstalled.

### Review-feedback fixes (same session, committed separately)

- **Public-endpoint rate limiting**: `/geocode`, `/poi-search`, `/search` now
  enforce a lightweight per-isolate, IP-keyed fixed-window limit
  (`_shared/rateLimit.ts`, 429 + `Retry-After`), so the open (verify_jwt=false)
  functions can't be used as an unmetered proxy to hammer Overpass/Photon —
  if abused, the public mirrors would ban *our* function IP, not the caller's.
- **Honest cost display**: when the fuel estimate is unavailable, the Confirm
  screen shows "Unavailable" (was "₹0" — read as a free trip) and the route
  comparison "Total"/delta rows show "—" instead of a toll-only partial total.
  Root cause of the on-device ₹0: a transient fuel-prices table lookup failure;
  re-verified on-device: Confirm now shows Est. cost ₹1082 for BLR→Mysuru.
- `jsonError` gained an optional headers param (Retry-After); deno tests 76/76.

---

## Maps-mode completion pass (2026-08-17)

Checkpoint `1a5ab87` frozen; this pass closes the Maps-mode product gaps found in
the Phase 4 audit. Backend untouched; all changes are in `home_screen.dart` +
`maps_mode_test.dart`.

| Item | Status |
|---|---|
| **Start Navigation actually navigates (bug fix)**: the Map-tab Start Navigation button previously called `startDirect()` with a zeroed synthetic route (geometry `null`, steps `[]`, provider `'test'`) and never pushed `LiveTripScreen` — the navigation engine started invisibly with no route. It now shares a `_prepareRoute()` helper with Directions: resolves the origin (GPS or location picker), primes the shared trip form, calculates the real Valhalla route (alternatives), then `startDirect()`s the selected route and pushes `AppRoutes.liveTrip`. No new engine, no second GPS stream — the existing `startDirect`/navigation engine/off-route/TTS machinery is reused unchanged | Done |
| **Destination sheet: distance from you**: straight-line distance (`GeoMath.haversineKm`, re-computed per selection, never cached) shown when a current location exists — honest by construction, no distance line when location is off | Done |
| **Destination sheet: Save to favorites**: full-width "Save to favorites" for `place` results → `favorites.save_place` (existing endpoint); guests get the standard sign-in gate instead | Done |
| **Share honesty fix**: the destination-sheet share payload no longer emits a fabricated `"Route: Calculating…"` (nothing is being calculated at that point) — it now carries name, address and coordinates only, per the no-fake-data rule | Done |
| **Map zoom controls**: zoom in/out buttons on the map tab (pinch/scroll still works); hidden while the search-results sheet is open so the controls never sit on top of the sheet and swallow its taps | Done |
| **Maps-mode widget tests**: `maps_mode_test.dart` 5 → 9 (destination sheet shows distance + Save; guest Save → sign-in gate; Start Navigation resolves the real route and reaches the live-trip screen via a router-backed harness; zoom controls present and actionable) | Done |
| Verification: `flutter analyze` 0 errors / 7 pre-existing infos (baseline parity), `flutter test` **78/78**, `dart format` clean, `flutter build apk --debug` ✓, `flutter build web` ✓, `deno check` clean on all 19 function dirs, `deno test --allow-env` **87/87** | Done |
| Backend/QA context from the earlier Phase-4 gate: project `ginurkwywgqpcvzpfaop` ACTIVE_HEALTHY, all 20 functions deployed, `route-nav` provider=valhalla live-verified (148.4 km / 230 min, 31 maneuvers); configured QA APK installed on OnePlus CPH2375 (SHA256 `cb8ca2d0…7da8`) — launch/crash/perf snapshots passed; GPS/TTS/moving-navigation validation **BLOCKED BY ENVIRONMENT** (indoor device) | Partial |
| Load test (3K target): **NOT run** — requires a controlled test on owned Supabase + Valhalla infra. Never claimed. Plan + acceptance criteria documented in `ROUTE2GO_PRODUCTION_COMPLETION_REPORT.md` | Deferred |

---

## Maps-mode completion prompt pass (2026-08-17)

Checkpoint `1a5ab87` + the uncommitted maps-mode pass preserved; this pass
implements the 10-item "Maps Mode Completion" master prompt additively (no
rewrites, no Phase 5, no second GPS stream / engine / LocationMarker, no Google
APIs, no fake data). All gates green.

| Item | Status |
|---|---|
| **FEATURE 1+2 — SearchResult category + city enrichment**: `/search` now returns `category`/`city` on every result kind: DB places → their real place-category name; hotels → `Hotel` + the DB `city`; Photon geocodes → `osm_value`/`type` + the first `city/town/village/state/country` property; Overpass POIs → their OSM category + `addr:city` when tagged. New pure helpers `photonCategory`/`photonCity` (geocodingProvider.ts) + `PoiResult.city` (poiProvider.ts). Never fabricated: absent when the provider returned nothing | Done, deployed-ready, deno 91/91 |
| **Destination sheet shows category · city**: rendered between title/subtitle and coordinates as `Cafe · Bengaluru`; `Place · <city>` is the honest fallback for an unknown category (never a made-up label) | Done |
| **FEATURE 3 — Compass**: map rotation enabled (`InteractiveFlag.all`); needle tracks the real camera bearing via `mapController.mapEventStream` + `camera.rotation`; tap → `moveAndRotate(center, zoom, 0)` (north-up); recenter also re-orients north | Done |
| **FEATURE 4 — Layer switcher**: `Route2GoTileLayer` gained `styleMode` (`styled` = styled-first with auto OSM fallback, `standard` = OSM always, `null` = historical auto); map-tab layers button toggles Standard/Styled, persisted locally (`PreferencesStore.map_style`, default `styled`); attribution + OSM fallback always preserved; `MapTileConfig` gained injectable `styledTileProviderFactory` so tests run fully offline | Done |
| **FEATURE 5 — Route share**: destination-sheet share stays place+coords (no route exists there — never fabricates "Calculating…"); the route-results screen (a real route always exists) gained an AppBar share action emitting route info + both coordinates; saved-trip share now includes distance + duration. Pure `buildDestinationShareText`/`buildRouteShareText` helpers, unit-tested. **No `route2go://` deeplink**: the app has no URL-scheme config, so a non-functional link is never emitted | Done |
| **FEATURE 6 — Inline route preview**: SKIPPED and documented — the destination sheet is opened before any route calculation, so there is no route to preview; adding one would either fabricate a preview or force an expensive Valhalla call on selection. Directions/Start Navigation already surface the real calculated route | Done (skip, documented) |
| **FEATURE 7 — Current-location UX**: already one-shot by design — `_useMyLocation` fetches the last-known position once, moves the camera; tapping again with a known position recenters immediately (no second GPS stream, no continuous subscription) | Done |
| **FEATURE 8 — Recent searches**: `PreferencesStore` gained `recent_searches` (most-recent-first, case-insensitive dedupe, capped 10, local device only); the map-tab search records each completed query and shows a "Recent searches" sheet when the (interacted) field is empty; tapping a recent re-runs it | Done |
| **FEATURE 9 — Performance targets documented**: `docs/PERFORMANCE_TARGETS.md` (map first frame <1 s, search p50 <400 ms, route p95 <2 s) — stated as targets, never as claims | Done |
| **FEATURE 10 — Load-test plan**: `LOAD_TEST_PLAN.md` (root) — k6 scenarios, Valhalla scaling + LB, latency p50/p95/p99 + error-rate thresholds, capacity planning, node-kill recovery, where results are recorded; the 3K concurrency claim stays UNCLAIMED until a controlled run | Done |
| **Tests**: Flutter **91/91** (+13: category·city, Place fallback, compass, layer switch + persistence, recent searches ×2, route-results share action, share-payload unit tests); Deno **91/91** (+4: photon category/city, mapPhotonFeatures carries enrichment, Overpass `addr:city`) | Done |
| **Accessibility**: compass/layer/zoom/search all ≥44×44 `IconButton`s with tooltips; map surface still has no OS semantics tree (flutter_map limitation, documented in the completion report) | Done |
| Verification: `flutter analyze lib test` 0 errors / 7 pre-existing infos (baseline parity, **no new lints**), `flutter test` **91/91**, `dart format` clean, `flutter build apk --debug` ✓, `flutter build web` ✓, `deno check` clean on all 19 function dirs, `deno test --allow-env` **91/91** | Done |
| Load test (3K target): still **NOT run** — requires owned-infra controlled test; `LOAD_TEST_PLAN.md` now specifies the procedure and acceptance criteria | Deferred |

---

## v3.0 Spec Alignment & Gap Analysis (2026-08-24)

Full analysis: `docs/GAP_ANALYSIS.md`. Summary:

| Spec Section | Status | Notes |
|---|---|---|
| **P0 — MVP Core** | ✅ Complete | Onboarding, Auth, Home, Explore, Search, Trip Planner, Route Comparison, Budget, Places/Stays/Fuel, Maps, Live Trip, Profile, Vehicles, Saved Trips, Admin, Security |
| **11. Safety & Emergency** | 🟡 Partial | Route deviation alert done; trusted contacts, emergency shortcut, fatigue reminder, "I am safe" missing |
| **12. Notifications** | 🟡 Partial | FCM init done; trip reminders, budget/fuel alerts, scheduling missing |
| **14. AI/Voice** | 🟡 Partial | TTS voice service done; NL planning, AI explanations, voice commands missing |
| **19. Analytics** | 🟡 Partial | Firebase + ATT done; product event tracking (`trip_created`, `route_selected`, etc.) missing |
| **20. Offline (P2)** | 🟡 Shells | Offline banner + Phase2Gate exist; tile caching, offline search missing |
| **25. Accessibility** | 🟡 Partial | Contrast, touch targets done; reduced motion, full semantics audit missing |
| **32. B2B/Future (P3)** | ❌ Not started | Fleet, corporate, APIs |

### Tests (2026-08-24)

- `flutter analyze` → **No issues found** (fixed 7 `use_build_context_synchronously` lints)
- `flutter test` → **106/106** pass
- `dart format` → clean (129 files)
- Mobile CI → **PASSING** on GitHub Actions

### Store submission gaps to close

1. **Safety Centre** — trusted contacts UI + backend (spec Section 11)
2. **Product analytics events** — core funnel tracking (spec Section 19)
3. **Reduced motion** — `MediaQuery.reduceMotionOf(context)` respect (spec Section 25.2)
