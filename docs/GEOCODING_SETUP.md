# GEOCODING_SETUP.md

How place search and reverse geocoding work, and where the limits live.

## Rule

Route2Go never talks to a public geocoder (e.g. Nominatim) directly from the
app. All geocoding goes through the Supabase `/geocode` edge function, which
owns the Nominatim request, its User-Agent and its rate limits.

## Server side (Supabase)

- `supabase/functions/_shared/providers/geocodingProvider.ts` — `GeocodingProvider`
  interface with a deterministic `MockGeocodingProvider` and a live
  `NominatimGeocodingProvider`.
- `supabase/functions/geocode/index.ts` — the `/geocode` edge function:
  - `?q=...` → forward geocode (place search)
  - `?lat=..&lng=..` → reverse geocode (map-pin label)
- Enabling live geocoding (server-side flag, not a key Nominatim needs):

  ```bash
  supabase secrets set GEOCODING_PROVIDER_KEY=1
  ```

  With the value unset, the deterministic mock is used.

## Client side (Flutter)

- `apps/mobile/lib/data/datasources/geocoding_providers.dart`:
  - `GeocodingProvider` — the interface
  - `SupabaseGeocodingProvider` — default; calls the `/geocode` edge function
  - `MockGeocodingProvider` — deterministic offline fixtures (tests/offline builds)
- `geocodingProviderProvider` selects the source from the `GEOCODING_PROVIDER`
  dart-define (`supabase` default, `mock` for offline/test).
- `GeocodingRepository` delegates `geocode`/`reverseGeocode` to the active
  provider and keeps `deviceLocation()` + permission handling unchanged.

## Debounce & no-autocomplete-on-keystroke

- The location picker debounces search input by **350 ms** before calling the
  edge function, and ignores stale responses (query changed while in flight).
- Queries shorter than 2 characters never fire.
- There is no keystroke-by-keystroke autocomplete to any public service — the
  only Nominatim traffic is the debounced search or an explicit reverse
  lookup, both proxied server-side.

## Tests

- Widget tests override `geocodingProviderProvider` (or
  `geocodingRepositoryProvider`) with the mock so no search ever hits the
  network.
- The mock returns the same real places as the server-side mock
  (Bengaluru, Mysuru, Chennai, Kochi, Mumbai, New Delhi), keeping offline
  behaviour identical.