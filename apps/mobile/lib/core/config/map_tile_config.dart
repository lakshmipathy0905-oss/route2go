import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where the map's raster tiles come from.
///
/// Route2Go defaults to the public OpenStreetMap tile servers (dev/test only)
/// and can point at any XYZ tile host at build time via the
/// `MAP_TILE_URL_TEMPLATE` dart-define (see .env.example). A free-tier styled
/// provider can be enabled with `MAP_TILE_STYLE_URL_TEMPLATE` (plus
/// `MAP_TILE_STYLE_ATTRIBUTION`); when configured, maps render the styled
/// tiles first and fall back to OSM automatically if they fail. Attribution
/// stays editable so the map screens always credit the active provider. Tests
/// override [mapTileConfigProvider] with an offline provider so widget tests
/// never hit the network.
class MapTileConfig {
  MapTileConfig({
    required this.urlTemplate,
    this.attribution = defaultAttribution,
    this.userAgentPackageName = defaultUserAgentPackageName,
    this.styledUrlTemplate,
    this.styledAttribution = defaultAttribution,
    TileProvider Function()? tileProviderFactory,
    TileProvider Function()? styledTileProviderFactory,
  })  : _tileProviderFactory = tileProviderFactory,
        _styledTileProviderFactory = styledTileProviderFactory;

  /// Fallback / default tiles (OSM unless overridden).
  final String urlTemplate;

  /// Attribution for [urlTemplate].
  final String attribution;

  /// Optional free-tier styled tile provider used first, with automatic
  /// fallback to [urlTemplate] when tiles fail to load.
  final String? styledUrlTemplate;

  /// Attribution for [styledUrlTemplate].
  final String styledAttribution;

  final String userAgentPackageName;
  final TileProvider Function()? _tileProviderFactory;
  final TileProvider Function()? _styledTileProviderFactory;

  static const String defaultAttribution =
      'Map data © OpenStreetMap contributors';
  static const String defaultUserAgentPackageName = 'com.route2go.route2go';

  factory MapTileConfig.fromEnvironment() {
    const styleUrl = String.fromEnvironment('MAP_TILE_STYLE_URL_TEMPLATE');
    return MapTileConfig(
      urlTemplate: const String.fromEnvironment(
        'MAP_TILE_URL_TEMPLATE',
        defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      ),
      attribution: const String.fromEnvironment(
        'MAP_TILE_ATTRIBUTION',
        defaultValue: defaultAttribution,
      ),
      styledUrlTemplate: styleUrl.isNotEmpty ? styleUrl : null,
      styledAttribution: const String.fromEnvironment(
        'MAP_TILE_STYLE_ATTRIBUTION',
        defaultValue: defaultAttribution,
      ),
    );
  }

  /// A fresh [TileProvider] for one [TileLayer]. A factory (rather than a
  /// shared instance) keeps per-layer lifecycle — flutter_map disposes the
  /// provider with its layer.
  TileProvider buildTileProvider() =>
      _tileProviderFactory?.call() ?? NetworkTileProvider();

  /// A fresh [TileProvider] for the styled layer. Keyed providers (Stadia,
  /// MapTiler, …) embed their key in the URL template or as a query param, so
  /// the standard network provider is sufficient; tests override it with an
  /// offline provider.
  TileProvider buildStyledTileProvider() =>
      _styledTileProviderFactory?.call() ?? NetworkTileProvider();
}

/// A [TileLayer] that uses the optional styled tile provider first and falls
/// back to OSM automatically on the first tile error (bad key, quota, flaky
/// network). Without a styled provider configured it is simply the default
/// layer, so existing behaviour is unchanged.
class Route2GoTileLayer extends ConsumerStatefulWidget {
  const Route2GoTileLayer({super.key, this.styleMode});

  /// 'styled' → styled provider first with automatic OSM fallback on error.
  /// 'standard' → always the default OSM tiles. null → the historical default
  /// (styled first when configured, OSM fallback). The map tab's layer
  /// switcher drives this; other screens leave it null.
  final String? styleMode;

  @override
  ConsumerState<Route2GoTileLayer> createState() => _Route2GoTileLayerState();
}

class _Route2GoTileLayerState extends ConsumerState<Route2GoTileLayer> {
  bool _styledFailed = false;

  @override
  Widget build(BuildContext context) {
    final tileConfig = ref.watch(mapTileConfigProvider);
    final useStyled = widget.styleMode == 'standard'
        ? false
        : tileConfig.styledUrlTemplate != null && !_styledFailed;
    return TileLayer(
      urlTemplate:
          useStyled ? tileConfig.styledUrlTemplate! : tileConfig.urlTemplate,
      tileProvider: useStyled
          ? tileConfig.buildStyledTileProvider()
          : tileConfig.buildTileProvider(),
      userAgentPackageName: tileConfig.userAgentPackageName,
      evictErrorTileStrategy: EvictErrorTileStrategy.notVisible,
      errorTileCallback: (tile, error, stackTrace) {
        if (useStyled && !_styledFailed) {
          setState(() => _styledFailed = true);
        }
      },
    );
  }
}

/// A [TileProvider] that never touches the network. Used by widget tests (and
/// available for offline-only builds): renders a 1x1 transparent PNG which
/// flutter_map scales to the tile size, so maps still lay out without any
/// HTTP requests or the 400s flutter_test's mock [HttpClient] would return.
class TransparentTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_kTransparentPng);

  static final Uint8List _kTransparentPng = Uint8List.fromList(const [
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x48,
    0x44,
    0x52,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x08,
    0x06,
    0x00,
    0x00,
    0x00,
    0x1F,
    0x15,
    0xC4,
    0x89,
    0x00,
    0x00,
    0x00,
    0x0A,
    0x49,
    0x44,
    0x41,
    0x54,
    0x78,
    0x9C,
    0x63,
    0x00,
    0x01,
    0x00,
    0x00,
    0x05,
    0x00,
    0x01,
    0x0D,
    0x0A,
    0x2D,
    0xB4,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4E,
    0x44,
    0xAE,
    0x42,
    0x60,
    0x82,
  ]);
}

final mapTileConfigProvider = Provider<MapTileConfig>(
  (ref) => MapTileConfig.fromEnvironment(),
);
