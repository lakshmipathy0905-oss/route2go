import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/base_repository.dart';
import '../../domain/entities/geo.dart';
import 'api_client.dart';

/// Client-side geocoding source. Route2Go never talks to a public geocoder
/// (e.g. Nominatim) directly from the app: production uses the Supabase
/// `/geocode` edge function, which owns the Nominatim request, its
/// User-Agent and its rate limits. The abstraction exists so the source is
/// replaceable (self-hosted, paid provider, offline mock) without touching
/// screens or repositories.
abstract class GeocodingProvider {
  /// Forward geocoding: text query -> candidate places. An empty list is a
  /// legitimate "no results" and must not be treated as an error.
  Future<List<GeoPlace>> geocode(String query);

  /// Reverse geocoding: lat/lng -> human-readable label for a map pin.
  Future<GeoPlace?> reverseGeocode(double lat, double lng);
}

/// Default provider: the Supabase `/geocode` edge function. The edge function
/// routes to the configured server-side adapter (Nominatim or mock).
class SupabaseGeocodingProvider extends BaseRepository
    implements GeocodingProvider {
  SupabaseGeocodingProvider(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<GeoPlace>> geocode(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];
    final res = await _apiClient.get(
      '/geocode',
      queryParameters: {'q': trimmed},
      allowGuest: true,
    );
    return parseList(res, GeoPlace.fromJson);
  }

  @override
  Future<GeoPlace?> reverseGeocode(double lat, double lng) async {
    final res = await _apiClient.get(
      '/geocode',
      queryParameters: {'lat': '$lat', 'lng': '$lng'},
      allowGuest: true,
    );
    final list = parseList(res, GeoPlace.fromJson);
    return list.isNotEmpty ? list.first : null;
  }
}

/// Deterministic, offline provider for tests and offline-only builds. Select
/// with `--dart-define=GEOCODING_PROVIDER=mock`. Real places (India focus)
/// mirror the server-side mock so behaviour is identical everywhere.
class MockGeocodingProvider implements GeocodingProvider {
  @override
  Future<List<GeoPlace>> geocode(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return _fixtures.where((p) => p.label.toLowerCase().contains(q)).toList();
  }

  @override
  Future<GeoPlace?> reverseGeocode(double lat, double lng) async {
    final hits = _fixtures.where(
      (p) => (p.lat - lat).abs() < 0.05 && (p.lng - lng).abs() < 0.05,
    );
    return hits.isNotEmpty ? hits.first : null;
  }

  static const List<GeoPlace> _fixtures = [
    GeoPlace(
      label: 'Bengaluru',
      subtitle: 'Karnataka, India',
      lat: 12.9716,
      lng: 77.5946,
    ),
    GeoPlace(
      label: 'Mysuru',
      subtitle: 'Karnataka, India',
      lat: 12.3052,
      lng: 76.6552,
    ),
    GeoPlace(
      label: 'Chennai',
      subtitle: 'Tamil Nadu, India',
      lat: 13.0827,
      lng: 80.2707,
    ),
    GeoPlace(
      label: 'Kochi',
      subtitle: 'Kerala, India',
      lat: 9.9312,
      lng: 76.2673,
    ),
    GeoPlace(
      label: 'Mumbai',
      subtitle: 'Maharashtra, India',
      lat: 19.0760,
      lng: 72.8777,
    ),
    GeoPlace(
      label: 'New Delhi',
      subtitle: 'Delhi, India',
      lat: 28.6139,
      lng: 77.2090,
    ),
  ];
}

/// Selects the active geocoding source. Defaults to the Supabase edge
/// function; `GEOCODING_PROVIDER=mock` gives the deterministic offline
/// provider (tests/offline builds). Widget tests override this provider.
final geocodingProviderProvider = Provider<GeocodingProvider>((ref) {
  const choice = String.fromEnvironment(
    'GEOCODING_PROVIDER',
    defaultValue: 'supabase',
  );
  if (choice == 'mock') return MockGeocodingProvider();
  return SupabaseGeocodingProvider(ref.watch(apiClientProvider));
});