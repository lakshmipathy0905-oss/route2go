import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/navigation.dart';
import '../../domain/entities/route_option.dart';
import 'navigation_provider.dart';
import 'trip_planning_provider.dart';

/// Live Trip session summary (spec 2.9). Phase 2 moves all real-time
/// navigation into [navigationProvider]; this notifier keeps the small public
/// API used by the confirm/delete flows (`start()` / `end()`) and the summary
/// labels for the trip overview card.
class LiveTrip {
  const LiveTrip({
    required this.sessionId,
    required this.originLabel,
    required this.destinationLabel,
    required this.route,
    this.startedAt,
  });

  final String sessionId;
  final String originLabel;
  final String destinationLabel;
  final RouteOption route;
  final DateTime? startedAt;
}

class LiveTripNotifier extends Notifier<LiveTrip?> {
  @override
  LiveTrip? build() => null;

  /// Enters Live Trip mode: records the summary and hands off to the in-app
  /// navigation engine (which requests location via the PermissionExplainer
  /// flow that runs before this is called).
  /// Enters Live Trip mode: records the summary and hands off to the in-app
  /// navigation engine (which requests location via the PermissionExplainer
  /// flow that runs before this is called).
  Future<void> start() async {
    final form = ref.read(tripPlanningFormProvider);
    final calc = ref.read(tripCalculationProvider).valueOrNull;
    if (!form.isReadyToCalculate || calc == null || calc.routes.isEmpty) return;

    final route = selectRoute(calc, ref.read(selectedRouteTypeProvider));
    if (route == null) return;

    state = LiveTrip(
      sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
      originLabel: form.originLabel ?? 'Start',
      destinationLabel: form.destinationLabel!,
      route: route,
      startedAt: DateTime.now(),
    );

    await ref.read(navigationProvider.notifier).startNavigation(
          route: route,
          origin: NavStop(
            label: form.originLabel ?? 'Start',
            lat: form.originLat!,
            lng: form.originLng!,
          ),
          destination: NavStop(
            label: form.destinationLabel!,
            lat: form.destinationLat!,
            lng: form.destinationLng!,
          ),
          originLabel: form.originLabel,
        );
  }

  /// Direct (no-trip) entry point (Phase 3A): records a lightweight LiveTrip
  /// summary for the LiveTripScreen header, then hands off to the in-app
  /// navigation engine with the already-fetched route. No trip is persisted.
  Future<void> startDirect({
    required String originLabel,
    required NavStop destination,
    required RouteOption route,
    List<NavStop> waypoints = const [],
  }) async {
    state = LiveTrip(
      sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
      originLabel: originLabel,
      destinationLabel: destination.label,
      route: route,
      startedAt: DateTime.now(),
    );

    await ref.read(navigationProvider.notifier).startNavigation(
          route: route,
          origin: NavStop(label: originLabel, lat: 0, lng: 0),
          destination: destination,
          waypoints: waypoints,
          originLabel: originLabel,
        );
  }

  void end() {
    ref.read(navigationProvider.notifier).end();
    state = null;
  }
}

final liveTripProvider = NotifierProvider<LiveTripNotifier, LiveTrip?>(
  LiveTripNotifier.new,
);
