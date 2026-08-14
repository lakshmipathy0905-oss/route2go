# TILE_PROVIDER_SETUP.md

Configuration and policy for the map's raster tile provider.

## Default

Route2Go uses OpenStreetMap's standard raster tiles by default:

- URL template: `https://tile.openstreetmap.org/{z}/{x}/{y}.png`
- Attribution: `Map data © OpenStreetMap contributors`
- Request UA: `flutter_map (com.route2go.route2go)`

## OSM tile usage policy

The public tile server is a shared, volunteer-funded resource:

- **Dev/test only** — keep traffic light in development and testing.
- **No bulk downloads / no aggressive prefetch** — the map only fetches the
  tiles it displays.
- **Production should use a paid tile provider** (or a self-hosted tile
  server) to avoid being blocked. Route2Go stays provider-agnostic.

## Switching providers at build time

Tiles are configured in one place (`MapTileConfig`, see
`docs/MAP_ARCHITECTURE.md`). Point the app at any XYZ tile host:

```bash
flutter run \
  --dart-define=MAP_TILE_URL_TEMPLATE=https://a.example.com/{z}/{x}/{y}.png \
  --dart-define=MAP_TILE_ATTRIBUTION='© Example Maps'
```

The attribution shown on the route results map always matches the configured
template.

## Compliance notes

- Attribution is **required** by OpenStreetMap's tile policy — Route2Go shows
  it under the map and keeps it editable for other providers.
- The app identifies itself via its User-Agent (`com.route2go.route2go`).
- Widget tests use an offline `TransparentTileProvider`, so the test suite
  makes **zero** tile requests and never hits OSM.

## HTTPS

Only HTTPS tile URLs are used; the OSM default and any production provider
should be HTTPS.