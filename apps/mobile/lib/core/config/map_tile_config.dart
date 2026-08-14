import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where the map's raster tiles come from.
///
/// Route2Go defaults to the public OpenStreetMap tile servers (dev/test only)
/// and can point at any XYZ tile host at build time via the
/// `MAP_TILE_URL_TEMPLATE` dart-define (see .env.example). Attribution stays
/// editable via `MAP_TILE_ATTRIBUTION` so the map screens always credit the
/// active provider. Tests override [mapTileConfigProvider] with an offline
/// provider so widget tests never hit the network.
class MapTileConfig {
  MapTileConfig({
    required this.urlTemplate,
    this.attribution = defaultAttribution,
    this.userAgentPackageName = defaultUserAgentPackageName,
    TileProvider Function()? tileProviderFactory,
  }) : _tileProviderFactory = tileProviderFactory;

  final String urlTemplate;
  final String attribution;
  final String userAgentPackageName;
  final TileProvider Function()? _tileProviderFactory;

  static const String defaultAttribution =
      'Map data © OpenStreetMap contributors';
  static const String defaultUserAgentPackageName = 'com.route2go.route2go';

  factory MapTileConfig.fromEnvironment() => MapTileConfig(
        urlTemplate: const String.fromEnvironment(
          'MAP_TILE_URL_TEMPLATE',
          defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        ),
        attribution: const String.fromEnvironment(
          'MAP_TILE_ATTRIBUTION',
          defaultValue: defaultAttribution,
        ),
      );

  /// A fresh [TileProvider] for one [TileLayer]. A factory (rather than a
  /// shared instance) keeps per-layer lifecycle — flutter_map disposes the
  /// provider with its layer.
  TileProvider buildTileProvider() =>
      _tileProviderFactory?.call() ?? NetworkTileProvider();
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
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);
}

final mapTileConfigProvider = Provider<MapTileConfig>(
  (ref) => MapTileConfig.fromEnvironment(),
);