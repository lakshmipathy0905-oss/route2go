import 'package:latlong2/latlong.dart';

import '../../domain/entities/navigation.dart';
import 'geo_math.dart';

/// Computes route-following progress from a position against the active route
/// geometry. "Remaining distance" is measured along the route polyline (from
/// the nearest point to the route end), NOT as a straight line to the
/// destination — so detours and turns are reflected in the reported numbers.
class RouteProgressEngine {
  RouteProgressEngine(this.polyline)
      : assert(polyline.length >= 2, 'Route polyline needs at least 2 points'),
        _segmentEndKm = _cumulative(polyline) {
    _totalKm = _segmentEndKm.isEmpty ? 0 : _segmentEndKm.last;
  }

  final List<LatLng> polyline;

  /// Cumulative distance (km) at the END of each segment i (i -> i+1).
  late final List<double> _segmentEndKm;
  late final double _totalKm;

  double get totalKm => _totalKm;

  static List<double> _cumulative(List<LatLng> line) {
    final ends = <double>[];
    var acc = 0.0;
    for (var i = 0; i < line.length - 1; i++) {
      acc += GeoMath.haversineKm(line[i], line[i + 1]);
      ends.add(acc);
    }
    return ends;
  }

  RouteProgress progressAt(LatLng position) {
    final nearest = GeoMath.nearestPointOnPolyline(polyline, position);
    if (nearest == null) {
      return RouteProgress(
        remainingKm: 0,
        remainingDurationMin: 0,
        progress: 1,
        distanceFromRouteM: double.infinity,
        nearestLat: polyline.first.latitude,
        nearestLng: polyline.first.longitude,
      );
    }

    final distanceFromRouteM =
        GeoMath.haversineKm(position, nearest.nearest) * 1000;

    // Distance travelled along the route up to the start of the segment the
    // user is nearest to, plus the fraction through that segment.
    final segStart = nearest.segmentIndex == 0
        ? 0.0
        : _segmentEndKm[nearest.segmentIndex - 1];
    final segLength = GeoMath.haversineKm(
      polyline[nearest.segmentIndex],
      polyline[nearest.segmentIndex + 1],
    );
    final segTravelled = segLength == 0
        ? 0.0
        : GeoMath.haversineKm(polyline[nearest.segmentIndex], nearest.nearest);
    final travelledKm = (segStart + segTravelled).clamp(0.0, _totalKm);

    final remainingKm = (_totalKm - travelledKm).clamp(0.0, _totalKm);
    final progress =
        _totalKm == 0 ? 1.0 : (travelledKm / _totalKm).clamp(0.0, 1.0);

    return RouteProgress(
      remainingKm: remainingKm,
      remainingDurationMin: 0, // filled by EtaCalculator with provider duration
      progress: progress,
      distanceFromRouteM: distanceFromRouteM,
      nearestLat: nearest.nearest.latitude,
      nearestLng: nearest.nearest.longitude,
    );
  }
}
