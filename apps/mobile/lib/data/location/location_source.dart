import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../domain/entities/navigation.dart';

/// Abstraction around the device location stream so navigation logic can be
/// tested with a scripted fake and run with real GPS on device.
///
/// The stream emits raw [LocationUpdate]s (with accuracy/speed/heading when the
/// device reports them). It must never throw — errors are surfaced through the
/// stream as an [Object] (which the consumer maps to a navigation error state).
abstract class LocationSource {
  /// Raw GPS stream. Emits [LocationUpdate] or an [Object] error object.
  Stream<LocationUpdate> get updates;

  /// One-shot current position, or null when unavailable/denied.
  Future<LocationUpdate?> getCurrentPosition();

  /// Whether the app currently holds location permission.
  Future<bool> get hasPermission;
}

/// Real device GPS via the geolocator package. Distance filtering avoids
/// spamming the stream on static devices; accuracy is set for navigation.
class GeolocatorLocationSource implements LocationSource {
  GeolocatorLocationSource({this.accuracy = LocationAccuracy.high});

  final LocationAccuracy accuracy;

  @override
  Stream<LocationUpdate> get updates => Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          distanceFilter: 10, // meters
        ),
      ).map(_toUpdate);

  @override
  Future<LocationUpdate?> getCurrentPosition() async {
    try {
      if (!await hasPermission) return null;
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: accuracy),
      );
      return _toUpdate(pos);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> get hasPermission async {
    final perm = await Geolocator.checkPermission();
    return perm == LocationPermission.whileInUse ||
        perm == LocationPermission.always;
  }

  LocationUpdate _toUpdate(Position pos) {
    return LocationUpdate(
      lat: pos.latitude,
      lng: pos.longitude,
      timestamp: pos.timestamp,
      accuracyMeters: pos.accuracy,
      speedMps: pos.speed,
      headingDegrees: pos.heading,
    );
  }
}

/// Test-only scripted location source. Never used in production.
class FakeLocationSource implements LocationSource {
  FakeLocationSource(
      {required List<LocationUpdate> points,
      Duration interval = const Duration(milliseconds: 100)})
      : _points = points,
        _interval = interval;

  final List<LocationUpdate> _points;
  final Duration _interval;

  @override
  Stream<LocationUpdate> get updates => Stream.periodic(_interval, (i) {
        if (_points.isEmpty) {
          return LocationUpdate(
              lat: 0,
              lng: 0,
              timestamp: DateTime.fromMillisecondsSinceEpoch(0));
        }
        return _points[i.clamp(0, _points.length - 1)];
      });

  @override
  Future<LocationUpdate?> getCurrentPosition() async =>
      _points.isEmpty ? null : _points.first;

  @override
  Future<bool> get hasPermission async => true;
}

final locationSourceProvider = Provider<LocationSource>((ref) {
  return GeolocatorLocationSource();
});
