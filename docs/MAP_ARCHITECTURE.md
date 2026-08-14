# MAP_ARCHITECTURE.md

How the map screens get their tiles, and why the tile URL is no longer
hardcoded in three places.

## The problem it solves

Before this change every map screen hardcoded
`https://tile.openstreetmap.org/{z}/{x}/{y}.png`. Widget tests logged a stream
of `400` `ClientException`s because flutter_test's mock `HttpClient` answers
**every** request with 400 — the production app never saw those errors (a real
curl to the tile server returns 200).

## The abstraction

`apps/mobile/lib/core/config/map_tile_config.dart`:

- `MapTileConfig` — one place for `urlTemplate`, `attribution`,
  `userAgentPackageName`, and an optional `tileProviderFactory`.
- `mapTileConfigProvider` — a Riverpod provider returning
  `MapTileConfig.fromEnvironment()`.
- `TransparentTileProvider` — an offline `TileProvider` that renders a 1×1
  transparent PNG (never touches the network). Used by widget tests; available
  for offline-only builds.

The three map screens (location picker, route results, live trip) build their
`TileLayer` from `ref.watch(mapTileConfigProvider)`:

```dart
TileLayer(
  urlTemplate: tileConfig.urlTemplate,
  tileProvider: tileConfig.buildTileProvider(),
  userAgentPackageName: tileConfig.userAgentPackageName,
),
```

Attribution shown under the map also comes from the config, so the credit
always matches the active provider.

## Configuring a different tile host at build time

```bash
flutter run \
  --dart-define=MAP_TILE_URL_TEMPLATE=https://tiles.example.com/{z}/{x}/{y}.png \
  --dart-define=MAP_TILE_ATTRIBUTION='© Example Tiles'
```

Defaults: OSM standard tiles and the standard OSM attribution.

## User-Agent policy

flutter_map appends `User-Agent: flutter_map (<userAgentPackageName>)`.
Route2Go sets `userAgentPackageName: com.route2go.route2go` so tile hosts can
identify the app. Public OSM tile servers ask for a descriptive UA and
rate-limited use — dev/test only, plan a paid tile provider for production.

## Tests

`test/router_back_navigation_test.dart` overrides
`mapTileConfigProvider` with an offline config:

```dart
mapTileConfigProvider.overrideWithValue(MapTileConfig(
  urlTemplate: 'https://offline.invalid/{z}/{x}/{y}.png',
  tileProviderFactory: TransparentTileProvider.new,
)),
```

Maps still lay out, no network, no 400 noise.