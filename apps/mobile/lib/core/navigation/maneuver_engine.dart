import '../../domain/entities/navigation.dart';

/// Selects the next (upcoming) maneuver from the provider's turn-by-turn steps
/// based on how far along the route the user has travelled. Steps whose
/// maneuver point is behind the user are skipped; the first remaining usable
/// step becomes "next". If the provider returned no usable steps, `next` is
/// null and the UI shows route-progress information instead.
class ManeuverEngine {
  ManeuverEngine({required this.steps, required this.totalRouteKm}) {
    _cumulativeKm = _buildCumulative();
  }

  /// Provider turn-by-turn steps (may be empty — no fabrication).
  final List<NavigationStep> steps;

  /// Total route length in km (used to clamp step cumulative distances).
  final double totalRouteKm;

  /// Cumulative distance (km) to each step's maneuver point along the route,
  /// built by summing the provider's per-step distances.
  late final List<double> _cumulativeKm;

  List<double> _buildCumulative() {
    final cum = <double>[];
    var acc = 0.0;
    for (final s in steps) {
      acc += s.distanceKm.clamp(0.0, double.infinity);
      cum.add(acc.clamp(0.0, totalRouteKm));
    }
    return cum;
  }

  /// Distance (km) the user has travelled along the route, given [progress].
  double _travelledKm(RouteProgress progress) =>
      (progress.progress * totalRouteKm).clamp(0.0, totalRouteKm);

  /// The upcoming maneuver given the current progress, or null when the
  /// provider gave no usable instructions or the user passed them all.
  NavigationStep? nextManeuver(RouteProgress progress) {
    final travelled = _travelledKm(progress);
    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      if (!step.isUsable) continue;
      if (_cumulativeKm[i] > travelled) {
        return step;
      }
    }
    return null;
  }

  /// Distance in km to the next maneuver's point (0 when none is upcoming).
  double distanceToNextKm(RouteProgress progress) {
    final travelled = _travelledKm(progress);
    for (var i = 0; i < steps.length; i++) {
      if (!steps[i].isUsable) continue;
      if (_cumulativeKm[i] > travelled) {
        return (_cumulativeKm[i] - travelled).clamp(0.0, double.infinity);
      }
    }
    return 0;
  }
}