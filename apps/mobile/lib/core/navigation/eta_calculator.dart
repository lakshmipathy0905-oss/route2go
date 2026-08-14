import '../../domain/entities/navigation.dart';

/// Computes the remaining duration + estimated arrival time from route
/// progress. Uses the routing provider's original duration estimate scaled by
/// how far along the route the user has travelled — the honest "best available
/// estimate". It is explicitly NOT traffic-aware (no live traffic data yet).
class EtaCalculator {
  const EtaCalculator({required this.routeDurationMin});

  /// Provider-reported duration for the full route, in minutes.
  final int routeDurationMin;

  RouteProgress withEta(RouteProgress progress, {required DateTime now}) {
    final remainingMinutes =
        (routeDurationMin * (1 - progress.progress)).round().clamp(0, 1 << 31);
    return RouteProgress(
      remainingKm: progress.remainingKm,
      remainingDurationMin: remainingMinutes,
      progress: progress.progress,
      distanceFromRouteM: progress.distanceFromRouteM,
      nearestLat: progress.nearestLat,
      nearestLng: progress.nearestLng,
    );
  }
}