# VALHALLA_MIGRATION_REPORT.md

Date: 2026-08-14. Outcome: **done and verified** — Route2Go routing now runs on
Valhalla behind the existing `RoutingProvider` abstraction. OSRM-specific code
was removed; the mock stays for unconfigured/dev/test runs.

---

## 1. Executive summary

| | |
|---|---|
| Before | OSRM-compatible `HttpRoutingProvider` hardwired to `ROUTING_PROVIDER_BASE_URL`; single request, OSRM-specific JSON parsing |
| After | `ValhallaRoutingProvider` (Valhalla `/route`, `costing: auto`); pure request/response logic isolated in `_shared/providers/valhalla.ts` |
| Activation | `VALHALLA_BASE_URL` (preferred) or legacy `ROUTING_PROVIDER_BASE_URL`; `ROUTING_PROVIDER_KEY` sent as optional Bearer token; mock when unset |
| Business logic | Zero changes — `trip-calculate`/`route-nav` still call `getRoutingProvider().getRouteAlternatives(...)` |
| Tests | 44 Deno tests green (10 scheduler + 6 fuel + 22 Valhalla + 6 provider), 63 Flutter tests green, analyze clean, apk + web build |

## 2. Why Valhalla

- **Multi-alternative responses natively** — Valhalla returns primary + N
  alternates in one call, which OSRM's demo does not expose cleanly.
- **Server-side toll flags** (`use_tolls: true/false`) allow a genuine
  toll-avoiding option instead of relabeling.
- **Turn-by-turn instructions included** in the base response (OSRM's demo
  required a separate `steps=true`/maneuver processing path).
- **One open-source engine, self-hostable** with Docker (see §13) — no per-call
  commercial API costs; honours the "no paid APIs, no mandatory keys" rule.

## 3. Scope

- Server-side only. The client's `RouteOption`/`NavigationStep` model is
  unchanged; `RouteAlternative` fields (`geometry`, `segments`, `steps`,
  `provider`) are provider-agnostic.
- OSRM code (`HttpRoutingProvider`, `parseOsrmSteps`, `instructionFor`) deleted.
- Companion client abstractions added: `MapTileConfig` (tiles) and
  `GeocodingProvider` (geocoding) — see §14.
- Self-hosting setup, config docs, and a 44-test Deno suite added.

## 4. Architecture

```
Flutter app
  └─ trip-calculate / route-nav           (unchanged)
       └─ getRoutingProvider()            _shared/providers/routingProvider.ts
            ├─ VALHALLA_BASE_URL  → ValhallaRoutingProvider (2 requests)
            └─ unset               → MockRoutingProvider (labelled mock-dev-fixture)
```

Files:
- `supabase/functions/_shared/providers/valhalla.ts` — pure functions
- `supabase/functions/_shared/providers/routingProvider.ts` — provider wiring
- `supabase/functions/_shared/providers/valhalla_test.ts` (22 tests)
- `supabase/functions/_shared/providers/routingProvider_test.ts` (6 tests)
- `infra/valhalla/` — self-hosting (Dockerfile, compose, entrypoint, README)

## 5. Request translation

`buildValhallaRequest({ origin, destination, waypoints, roundTrip, useTolls, alternates })`:

- `locations`: origin (break), waypoints (`through`), destination (break).
- `costing: "auto"`, `costing_options.auto.use_tolls` from the profile.
- `directions_options`: `{ units: "kilometers", language: "en-US", format: "text" }`.
- `alternates` from the profile; `shape_format: "geojson"` requested (but see §7).
- Round trips append the origin as a **final break** — a genuine out-and-back
  (verified 288.3 km Bengaluru⇄Mysuru), never a distance×2 hack.

## 6. Response translation

`parseValhallaTrip(trip)`:
- `trip.summary.length` (km) / `time` (s) → `distanceKm` / `durationMin`.
- Leg shapes are merged into one GeoJSON `LineString` (`buildRouteGeometry`).
- Maneuvers → `RouteStep[]` (instruction verbatim, kind/modifier derived from
  text + type, coordinates from the decoded shape at `begin_shape_index`) and
  `RouteSegment[]` (one per maneuver, lat/lng + remaining distance).

## 7. Shape decoding

Valhalla deployments differ. Verified live against Valhalla 3.8.3
(`valhalla1.openstreetmap.de`): the shape came back as an **encoded polyline6
string even when `shape_format: "geojson"` was requested**. The adapter handles
both:
- GeoJSON object (elevation stripped, `[lng, lat]` pairs).
- Encoded polyline6 string (`decodeEncodedPolyline`, precision 1e6,
  sign-aware zigzag decoding).

## 8. Maneuvers → steps / segments

- Numeric maneuver `type` enums differ across Valhalla versions, so the step
  classification (`depart`, `turn`, `new name`, `continue`, `arrive`,
  `roundabout`, `uturn`, …) is derived **primarily from instruction text**,
  with `type` as a secondary signal.
- Instructions are taken **verbatim** from Valhalla ("Drive east.",
  "Your destination is on the left.") — never fabricated or templated from
  fragments.
- Empty/unusable maneuvers yield empty `steps`; callers fall back to
  route-progress display.

## 9. Route labelling, dedupe, capping

Two requests per calculation: main (`use_tolls: true`, `alternates: 3`) and
toll-free (`use_tolls: false`, `alternates: 1`). Results are combined and:
- labelled from **real metrics**: `recommended` (primary), `no_toll` (toll-free
  primary), `fastest` (min duration), `shortest` (min distance), `cheapest`
  (min distance among remaining);
- **deduped** by signature (rounded distance + duration bucket + first/last
  coordinates) so near-identical alternates don't flood the picker;
- **capped at 5** options.

Live result: Bengaluru→Mysuru surfaced recommended (146.2 km/224 min),
no_toll (141.3 km/229 min), fastest (162.3 km/303 min), shortest
(157.4 km/308 min); London→Manchester surfaced all five labels.

## 10. Round-trip handling

`roundTrip: true` appends the origin as a final `break`. Valhalla routes the
real return leg. Verified: 288.3 km recommended, 283.4 km no_toll.

## 11. Error handling & status mapping

| Valhalla outcome | Adapter behaviour | Caller maps to |
|---|---|---|
| `200` with `trip` | parse | `200` routes |
| HTTP 400 + no-route code (`error_code` 106/150/156/158/160/161/171–177/180–183, or string code like `"No suitable edges near location"`) | returns `[]` | `404 NO_ROUTE_FOUND` |
| other non-2xx / malformed body | throws | `502 ROUTE_PROVIDER_UNAVAILABLE` |
| toll-free request fails | **non-fatal** — option omitted, main still returned | unaffected |

## 12. Config & secrets

```
supabase secrets set VALHALLA_BASE_URL=http://<host>:8002     # production
supabase secrets set ROUTING_PROVIDER_BASE_URL=...            # legacy alias (optional)
supabase secrets set ROUTING_PROVIDER_KEY=...                 # optional Bearer for your instance
```

`getRoutingProvider()` precedence: `VALHALLA_BASE_URL` →
`ROUTING_PROVIDER_BASE_URL` → mock. Env docs updated (`.env.example`,
`API_SETUP_GUIDE.md`, `CREDENTIALS_REQUIRED.md`).

## 13. Self-hosting

`infra/valhalla/`:
- `Dockerfile` (official `ghcr.io/valhalla/valhalla` + `curl`).
- `docker-compose.yml` (`OSM_EXTRACT_URL` env, `:8002`).
- `scripts/entrypoint.sh` — downloads the extract once, builds admin db +
  tiles + tile extract once (marker-skipped on restart), serves
  `valhalla_service`.
- `README.md` — region sizing, updates, auth/ops notes.
- Production must self-host; the public demo endpoints are dev/test only.

## 14. Client changes

**Routing:** none required — the client never talks to Valhalla directly; all
routing stays server-side behind the edge functions.

**Map tiles (companion):** `core/config/map_tile_config.dart` centralises the
tile URL/attribution/UA (`MAP_TILE_URL_TEMPLATE`, `MAP_TILE_ATTRIBUTION`
dart-defines). All three map screens read it; `TransparentTileProvider` lets
widget tests run fully offline (this removed the false `400 ClientException`
noise caused by flutter_test's mock HttpClient, which 400s every request).

**Geocoding (companion):** `data/datasources/geocoding_providers.dart` — a
client-side `GeocodingProvider` (Supabase default, mock offline, selected via
`GEOCODING_PROVIDER`). The app never calls public Nominatim directly; search is
debounced 350 ms and proxied through the `/geocode` edge function.

## 15. Testing strategy

- **Pure unit tests** (`valhalla_test.ts`, 22): request bodies (one-way /
  waypoints / round trip), polyline6 round-trip against a known fixture,
  GeoJSON + encoded-polyline decoding, boundary de-dupe in
  `concatenateShapes`, verbatim maneuvers (depart/turn/arrive/roundabout/uturn),
  segments, parse/collect/label/dedupe, no-route codes, and a **worldwide**
  sweep (Bengaluru, Goa, London, New York, Tokyo, Sydney, Dubai).
- **Provider tests** (`routingProvider_test.ts`, 6): mock-when-unconfigured,
  `VALHALLA_BASE_URL` precedence, legacy alias, trailing-slash stripping,
  400→empty, 500→throw, Bearer auth — with a stubbed `fetch`.
- **Live smoke tests** (dev demo only): Bangalore→Mysore, London→Manchester,
  waypoints, round trip — verified against Valhalla 3.8.3.

## 16. Verification results

```
deno check  → clean across all 18 functions + shared modules
deno test   → 44/44  (itinerary_scheduler 10, fuelCostEngine 6, valhalla 22, routingProvider 6)
flutter analyze → No issues found
flutter test → 63/63 (tile 400 noise eliminated)
flutter build apk --debug → ✓ app-debug.apk
flutter build web        → ✓ build/web
Security scan → no secrets committed (.env.example only; no hardcoded credentials)
```

## 17. Operational notes, rollback & risks

- **Rollback**: keep `ROUTING_PROVIDER_BASE_URL` pointed at a compatible
  server, or simply unset both — the mock reactivates automatically. Because
  the client is unchanged, switching providers is a server-side env change.
- **Version drift**: shape encoding and maneuver `type` enums differ across
  Valhalla versions; parsers are defensive (both shape forms, text-first
  classification). Re-verify against your pinned Valhalla image when upgrading.
- **`has_toll` quirk**: the demo reports tolls even on the toll-avoiding
  profile; the "no_toll" label reflects the request, and toll cost display
  relies on the separate toll data source — do not infer toll-free from a
  single flag.
- **Public demo risk**: `valhalla1.openstreetmap.de` (and the FOSSGIS root
  `valhalla.openstreetmap.de`, which 405s `/route`) are dev/test only —
  production must self-host (§13).
- **Deployment**: redeploy all 18 edge functions after pulling this change so
  the new `_shared` modules are live; set `VALHALLA_BASE_URL` on the deployed
  functions to activate real routing.