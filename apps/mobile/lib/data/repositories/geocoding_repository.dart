import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../datasources/geocoding_providers.dart';
import '../../domain/entities/geo.dart';

class GeocodingRepository {
  GeocodingRepository(this._provider);

  final GeocodingProvider _provider;

  /// Requests location permission and, on Android, background ("Always")
  /// permission — this must only be called from the Live Trip entry point,
  /// after the in-app PermissionExplainer (Section 3.3). Never at launch.
  /// Returns the final granted permission.
  Future<LocationPermission> requestLocationPermission(
      {bool background = false}) async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (background && !kIsWeb && Platform.isAndroid) {
      if (perm == LocationPermission.always) return perm;
      perm = await Geolocator.requestPermission();
    }
    return perm;
  }

  /// Forward geocoding: text query -> candidate places. Empty list is a
  /// legitimate "no results" and must not be treated as an error.
  Future<List<GeoPlace>> geocode(String query) => _provider.geocode(query);

  /// Reverse geocoding: lat/lng -> human-readable label for the map pin.
  Future<GeoPlace?> reverseGeocode(double lat, double lng) =>
      _provider.reverseGeocode(lat, lng);

  /// Uses the device's GPS to determine the current location. Returns null
  /// when permission is denied or the service is off — callers must fall
  /// back to manual entry (spec 2.2 edge case) rather than failing hard.
  Future<GeoPlace?> deviceLocation() async {
    try {
      var granted = await Geolocator.checkPermission();
      if (granted == LocationPermission.denied) {
        granted = await Geolocator.requestPermission();
      }
      if (granted != LocationPermission.whileInUse &&
          granted != LocationPermission.always) {
        return null;
      }
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      return GeoPlace(
          label: 'Current location', lat: pos.latitude, lng: pos.longitude);
    } catch (_) {
      return null;
    }
  }
}

final geocodingRepositoryProvider = Provider<GeocodingRepository>((ref) {
  return GeocodingRepository(ref.watch(geocodingProviderProvider));
});
