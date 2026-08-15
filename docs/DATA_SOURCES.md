# DATA_SOURCES.md

Where the data shown in Route2Go actually comes from. Nothing is fabricated:
every estimate carries a confidence label, and provider failures surface as
honest errors or empty states — never as made-up values.

## 1. Places, hotels, routes & saved trips (global search)

- **Source:** Route2Go database (`places`, `hotels`, `trips`) queried by the
  `/search` edge function (authenticated users get their saved trips).
- **Worldwide place results:** `/search` also returns worldwide address/place
  results from the Photon geocoder, and — when a reference point is passed —
  POI category results from Overpass (`kind: "nearby"`).
- **Unknown when:** DB unreachable → `DB_ERROR`; provider flaky → the nearby
  results are skipped but DB results still return.

## 2. Location picker search

- **Source:** `/geocode` edge function (Photon by default — worldwide, no
  country bias; Nominatim optional). Reverse geocode for the map pin.
- **POI categories** ("cafes near me"): `/poi-search` edge function queries
  Overpass around the map pin and merges named POIs into the results.
  Best-effort — if the POI provider is down, address search still works.
- **GPS "Use my location":** device GPS via `geolocator`. On failure the app
  shows an honest "Location is unavailable" message and lets the user search
  or drag the pin instead.

## 3. Routes (distance, duration, geometry, turn-by-turn)

- **Source:** Valhalla (`VALHALLA_BASE_URL`). Two profiles are computed:
  all-tolls ("recommended") and toll-free ("no_toll").
- **Honesty:** durations/ETAs are estimates from normal speed limits — the app
  labels them "Estimated" and states there is **no live traffic data**.
- **Failure:** returns a clear error; the UI never substitutes fake routes.

## 4. Fuel & toll cost

- **Source (current):** server-side estimates derived from the route distance
  and the configured vehicle/regional fuel prices; toll costs from
  Valhalla toll distance and the DB toll tables.
- **Live pricing is OFF** (`USE_LIVE_TOLL_DATA=false`,
  `USE_LIVE_FUEL_PRICES=false`); costs are shown with a confidence badge
  (`calculated` / `estimated`) and a "may change at the plaza" hint. No
  "real-time price" claims.

## 5. Places & stays along the route

- **Source:** DB tables via `/places-near-route` and `/stays-near-route`
  (detour cost computed against the selected route). Ratings shown are the
  stored values; unrated items display "No rating yet".

## 6. Budget tracker & expenses

- **Source:** user-entered estimates and recorded actuals (`/expenses`),
  aggregated client-side. Toggle between "estimates only" and "use actuals".

## 7. Offline route packages

- Not implemented yet — the Home screen labels it "Coming soon." honestly.

## 8. Notifications

- **Source:** `/notifications` edge function + Firebase Cloud Messaging (push
  when the app is closed). In-app feed otherwise.
