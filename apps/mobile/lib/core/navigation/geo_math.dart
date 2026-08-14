import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Pure geometric helpers for route-following navigation. No Flutter
/// dependencies beyond latlong2, so the whole engine is unit-testable.
class GeoMath {
  GeoMath._();

  static const double _earthRadiusKm = 6371.0;

  static double deg2rad(double deg) => deg * math.pi / 180;

  /// Great-circle distance in km (haversine).
  static double haversineKm(LatLng a, LatLng b) {
    final dLat = deg2rad(b.latitude - a.latitude);
    final dLng = deg2rad(b.longitude - a.longitude);
    final s = math.pow(math.sin(dLat / 2), 2) +
        math.cos(deg2rad(a.latitude)) *
            math.cos(deg2rad(b.latitude)) *
            math.pow(math.sin(dLng / 2), 2);
    return _earthRadiusKm * 2 * math.atan2(math.sqrt(s), math.sqrt(1 - s));
  }

  static double metersToKm(double meters) => meters / 1000;

  /// Distance in meters from [point] to the infinite segment [a]-[b].
  static double distanceToSegmentM(LatLng point, LatLng a, LatLng b) {
    // Use equirectangular approximation locally: accurate enough for the
    // tens-to-hundreds-of-metres off-route checks navigation needs.
    final x0 = point.longitude;
    final y0 = point.latitude;
    final x1 = a.longitude;
    final y1 = a.latitude;
    final x2 = b.longitude;
    final y2 = b.latitude;

    final cosLat = math.cos(deg2rad((y0 + y2) / 2));
    final px = x0 * cosLat;
    final py = y0;
    final p1x = x1 * cosLat;
    final p1y = y1;
    final p2x = x2 * cosLat;
    final p2y = y2;

    final dx = p2x - p1x;
    final dy = p2y - p1y;
    final len2 = dx * dx + dy * dy;
    double t = 0;
    if (len2 > 0) {
      t = ((px - p1x) * dx + (py - p1y) * dy) / len2;
      t = t.clamp(0.0, 1.0);
    }
    final cx = p1x + t * dx;
    final cy = p1y + t * dy;
    final dLng = (px - cx) / cosLat;
    final dLat = py - cy;
    return math.sqrt(dLng * dLng + dLat * dLat) * 111320.0;
  }

  /// Nearest point on polyline [polyline] to [point], plus the index of the
  /// segment it lies on. Returns null for an empty polyline.
  static ({LatLng nearest, int segmentIndex})? nearestPointOnPolyline(
    List<LatLng> polyline,
    LatLng point,
  ) {
    if (polyline.isEmpty) return null;
    if (polyline.length == 1) {
      return (nearest: polyline.first, segmentIndex: 0);
    }

    var bestDist = double.infinity;
    LatLng best = polyline.first;
    var bestIndex = 0;
    for (var i = 0; i < polyline.length - 1; i++) {
      final d = distanceToSegmentM(point, polyline[i], polyline[i + 1]);
      if (d < bestDist) {
        bestDist = d;
        bestIndex = i;
        best = _closestPointOnSegment(point, polyline[i], polyline[i + 1]);
      }
    }
    return (nearest: best, segmentIndex: bestIndex);
  }

  static LatLng _closestPointOnSegment(LatLng point, LatLng a, LatLng b) {
    final cosLat = math.cos(deg2rad((point.latitude + b.latitude) / 2));
    final px = point.longitude * cosLat;
    final py = point.latitude;
    final p1x = a.longitude * cosLat;
    final p1y = a.latitude;
    final p2x = b.longitude * cosLat;
    final p2y = b.latitude;

    final dx = p2x - p1x;
    final dy = p2y - p1y;
    final len2 = dx * dx + dy * dy;
    double t = 0;
    if (len2 > 0) {
      t = ((px - p1x) * dx + (py - p1y) * dy) / len2;
      t = t.clamp(0.0, 1.0);
    }
    final lat = a.latitude + (b.latitude - a.latitude) * t;
    final lng = a.longitude + (b.longitude - a.longitude) * t;
    return LatLng(lat, lng);
  }

  /// Distance in meters from [point] to the nearest point on [polyline].
  static double distanceToRouteM(List<LatLng> polyline, LatLng point) {
    final n = nearestPointOnPolyline(polyline, point);
    if (n == null) return double.infinity;
    return haversineKm(point, n.nearest) * 1000;
  }

  /// Length of the polyline in km.
  static double polylineLengthKm(List<LatLng> polyline) {
    if (polyline.length < 2) return 0;
    var sum = 0.0;
    for (var i = 0; i < polyline.length - 1; i++) {
      sum += haversineKm(polyline[i], polyline[i + 1]);
    }
    return sum;
  }
}
