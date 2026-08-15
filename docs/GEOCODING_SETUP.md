# GEOCODING_SETUP.md

How place search and reverse geocoding work, and where the limits live.

## Rule

Route2Go never talks to a public geocoder (e.g. Photon/Nominatim) directly
from the app. All geocoding goes through the Supabase `/geocode` edge
function, which owns the provider request, its User-Agent and its rate limits.
The same applies to POI category search: it goes through `/poi-search`, which
owns the Overpass request (with mirror failover + caching).

## Server side (Supabase)

- `supabase/functions/_shared/providers/geocodingProvider.ts` — the
  `GeocodingProvider` interface with:
  - `MockGeocodingProvider` — deterministic dev fixture.
  - `PhotonGeocodingProvider` — **default live adapter**: worldwide (no
    country bias), typo-tolerant free-text search/autocomplete over OSM data.
    Handles proximity phrasing ("cafes near me" → skipped for the POI search;
    "cafes near MG Road" → searches "MG Road").
  - `NominatimProvider` — optional India-biased adapter
    (`GEOCODING_BACKEND=nominatim`).
- `supabase/functions/_shared/providers/poiProvider.ts` — `PoiProvider`
  interface with `OverpassPoiProvider` (mirror failover, TTL cache, failure
  cooldown) and `MockPoiProvider`.
- `supabase/functions/geocode/index.ts` — `/geocode`:
  - `?q=...` → forward geocode (place search)
  - `?lat=..&lng=..` → reverse geocode (map-pin label)
- `supabase/functions/poi-search/index.ts` — `/poi-search?q=&lat=&lng=&radius_km=`:
  POI category search around a point (worldwide OSM).
- Enabling live providers (server-side flags):

  ```bash
  supabase secrets set GEOCODING_PROVIDER_KEY=1          # live geocode (Photon)
  supabase secrets set POI_PROVIDER=overpass             # live POI (optional)
  ```

  With the geocoding flag unset, the deterministic mock is used.

## Client side (Flutter)

- `apps/mobile/lib/data/datasources/geocoding_providers.dart`:
  - `GeocodingProvider` — the interface (`geocode`, `reverseGeocode`,
    `searchNear`)
  - `SupabaseGeocodingProvider` — default; calls `/geocode` and `/poi-search`
  - `MockGeocodingProvider` — deterministic offline fixtures (tests/offline builds)
- `geocodingProviderProvider` selects the source from the `GEOCODING_PROVIDER`
  dart-define (`supabase` default, `mock` for offline/test).
- `GeocodingRepository` delegates `geocode`/`reverseGeocode`/`searchNear` to
  the active provider and keeps `deviceLocation()` + permission handling
  unchanged.
- The location picker merges geocode results with POI results for category
  queries; the global search (`/search`) surfaces the same providers as
  `kind: "nearby"` results.

## Debounce & no-autocomplete-on-keystroke

- The location picker and global search debounce input by **300–350 ms**
  before calling the edge functions, and ignore stale responses (query
  changed while in flight).
- Queries shorter than 2 characters never fire.
- POI searches only fire for recognised category queries (a client-side
  keyword list), so Overpass is never hit per keystroke for arbitrary text.
- There is no keystroke-by-keystroke autocomplete to any public service.

## Tests

- Widget tests override `geocodingProviderProvider` (or
  `geocodingRepositoryProvider`) with the mock so no search ever hits the
  network.
- The mock returns the same real places as the server-side mock
  (Bengaluru, Mysuru, Chennai, Kochi, Mumbai, New Delhi) plus deterministic
  POI fixtures for category queries, keeping offline behaviour identical.
- Server-side unit tests cover Photon label/mapping and the "near" phrase
  handling (`geocodingProvider_test.ts`) and Overpass category matching,
  query building and response parsing (`poiProvider_test.ts`).
