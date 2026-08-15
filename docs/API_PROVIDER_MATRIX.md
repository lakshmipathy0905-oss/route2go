# API_PROVIDER_MATRIX.md

Every external data provider Route2Go talks to, what it is used for, how it is
configured, and what happens when it is unavailable. Only open data (OSM
ecosystem) is used — no Google services.

## Providers

| Feature | Provider | Endpoint | Server/Client | Env config | Fallback when down |
|---------|----------|----------|---------------|------------|--------------------|
| Routing (route + turn-by-turn) | Valhalla (self-hostable / public demo) | `VALHALLA_BASE_URL/route` | Server (edge fn) | `VALHALLA_BASE_URL` | Honest "route unavailable" error; **never** silent mock data |
| Forward + reverse geocoding | Photon (OSM, komoot) — worldwide, no country bias | `https://photon.komoot.io/api|reverse` | Server (edge fn `/geocode`) | `GEOCODING_PROVIDER_KEY` present selects live; `GEOCODING_BACKEND=nominatim` opts into the India-biased Nominatim adapter | `GEOCODING_UNAVAILABLE` (retryable) |
| POI category search ("cafes near me") | Overpass (OSM) | `https://overpass-api.de/api/interpreter` (+ mirrors) | Server (edge fn `/poi-search`) | `POI_PROVIDER=mock\|overpass` (default: real when project configured) | Best-effort empty / `POI_SEARCH_UNAVAILABLE`; app search still shows geocode + DB results |
| Map raster tiles | OpenStreetMap standard tiles (default) | `https://tile.openstreetmap.org/{z}/{x}/{y}.png` | Client (flutter_map) | `MAP_TILE_URL_TEMPLATE`, `MAP_TILE_ATTRIBUTION` | Automatic OSM fallback when a styled provider fails |
| Map tiles (optional styled, free tier) | Configurable (e.g. CARTO/Stadia) | `MAP_TILE_STYLE_URL_TEMPLATE` | Client (flutter_map) | `MAP_TILE_STYLE_URL_TEMPLATE`, `MAP_TILE_STYLE_ATTRIBUTION` | `Route2GoTileLayer` falls back to OSM on first tile error |
| Places/stays along route | Route2Go DB (via edge fns `/places-near-route`, `/stays-near-route`) | Supabase | Server | Supabase project secrets | Empty state, retryable error |
| Fuel prices / tolls | Route2Go DB + Valhalla toll distance | Supabase + Valhalla | Server | `USE_LIVE_TOLL_DATA`, `USE_LIVE_FUEL_PRICES` (currently `false` — estimates are DB/Valhalla-derived, never live) | "Estimated" confidence badges |
| Auth | Firebase Auth (Google/email/phone sign-in) | Firebase | Client→Server | `firebase_options.dart` | Guest mode (plan/estimate without account) |

## Provider selection (server-side)

- `getGeocodingProvider()` (`_shared/providers/geocodingProvider.ts`):
  - `GEOCODING_PROVIDER_KEY` unset → deterministic mock (dev).
  - key set → **Photon** by default (worldwide, typo tolerant).
  - `GEOCODING_BACKEND=nominatim` → Nominatim adapter (retains the regional
    `countrycodes=in` bias used by early builds).
- `getPoiProvider()` (`_shared/providers/poiProvider.ts`):
  - `POI_PROVIDER=mock` → mock.
  - `POI_PROVIDER=overpass` or a configured project → Overpass with mirror
    failover, a per-instance TTL cache and a failure cooldown (so the shared
    public servers are never hammered).

## Rate limiting & caching

- App-side debounce on every search field (300–350 ms).
- Overpass: in-memory 30-minute cache keyed by `query|lat|lng|radius`;
  after a total failure a 90-second circuit-breaker avoids retrying on every
  keystroke.
- Photon/Nominatim: `limit=6` capped results; single edge-function entry point
  owns the User-Agent.
- Tiles: only the visible viewport is fetched; no prefetch or bulk download
  (OSM tile usage policy).

## Attribution

- Map tiles: `Map data © OpenStreetMap contributors` (styled providers must
  set `MAP_TILE_STYLE_ATTRIBUTION` to their required credit).
- Geocoding/POI data is from OpenStreetMap contributors (ODbL); results are
  sourced via Photon/Overpass.
