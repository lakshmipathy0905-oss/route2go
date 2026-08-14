import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/route_option.dart';
import 'trip_planning_provider.dart';

/// Live Trip state (spec 2.9). Background location permission is requested
/// ONLY here, when the user starts a live trip — never at launch.
class LiveTrip {
  const LiveTrip({
    required this.sessionId,
    required this.originLabel,
    required this.destinationLabel,
    required this.destinationLat,
    required this.destinationLng,
    required this.route,
    this.startedAt,
    this.deviationDetected = false,
    this.handedOff = false,
    this.lastKnownLat,
    this.lastKnownLng,
  });

  final String sessionId;
  final String originLabel;
  final String destinationLabel;
  final double destinationLat;
  final double destinationLng;
  final RouteOption route;
  final DateTime? startedAt;
  final bool deviationDetected;
  final bool handedOff;
  final double? lastKnownLat;
  final double? lastKnownLng;

  LiveTrip copyWith({
    bool? deviationDetected,
    bool? handedOff,
    double? lastKnownLat,
    double? lastKnownLng,
    DateTime? startedAt,
  }) {
    return LiveTrip(
      sessionId: sessionId,
      originLabel: originLabel,
      destinationLabel: destinationLabel,
      destinationLat: destinationLat,
      destinationLng: destinationLng,
      route: route,
      startedAt: startedAt ?? this.startedAt,
      deviationDetected: deviationDetected ?? this.deviationDetected,
      handedOff: handedOff ?? this.handedOff,
      lastKnownLat: lastKnownLat ?? this.lastKnownLat,
      lastKnownLng: lastKnownLng ?? this.lastKnownLng,
    );
  }
}

class LiveTripNotifier extends Notifier<LiveTrip?> {
  StreamSubscription<Position>? _positionSub;

  @override
  LiveTrip? build() {
    ref.onDispose(() => _positionSub?.cancel());
    return null;
  }

  /// Entering Live Trip mode — the ONLY place background location is
  /// requested. The PermissionExplainer must run before calling this.
  Future<void> start() async {
    final form = ref.read(tripPlanningFormProvider);
    final calc = ref.read(tripCalculationProvider).valueOrNull;
    if (!form.isReadyToCalculate || calc == null || calc.routes.isEmpty) return;

    final route = calc.routes.firstWhere(
      (r) => r.routeType == 'recommended',
      orElse: () => calc.routes.first,
    );

    state = LiveTrip(
      sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
      originLabel: form.originLabel!,
      destinationLabel: form.destinationLabel!,
      destinationLat: form.destinationLat!,
      destinationLng: form.destinationLng!,
      route: route,
      startedAt: DateTime.now(),
    );

    _listenForDeviation();
  }

  void _listenForDeviation() {
    _positionSub?.cancel();
    try {
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      ).listen((pos) {
        final current = state;
        if (current == null || current.deviationDetected) return;
        if (current.lastKnownLat == null) {
          state = current.copyWith(lastKnownLat: pos.latitude, lastKnownLng: pos.longitude);
          return;
        }
        final movedKm = haversineKm(
          current.lastKnownLat!,
          current.lastKnownLng!,
          pos.latitude,
          pos.longitude,
        );
        if (movedKm > 5) {
          // Prompt "Recalculate route?" rather than silently recalculating.
          state = current.copyWith(
            deviationDetected: true,
            lastKnownLat: pos.latitude,
            lastKnownLng: pos.longitude,
          );
        }
      }, onError: (_) {});
    } catch (_) {
      // Position stream unavailable (e.g. permission denied) — live summary
      // still works; only deviation detection is degraded.
    }
  }

  /// Confirms the trip (spec 2.9), then hands off to the platform navigation
  /// app via a validated, platform-safe deep link. The affiliate/partner CTA
  /// logging lives in the Stays flow, not here.
  Future<({bool ok, String? error})> handoffToNavigation() async {
    final current = state;
    if (current == null) return (ok: false, error: 'No active live trip.');
    if (!current.handedOff) {
      state = current.copyWith(handedOff: true);
    }

    final uri = _navigationDeepLink(
      destLat: current.destinationLat,
      destLng: current.destinationLng,
      label: current.destinationLabel,
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    return launched ? (ok: true, error: null) : (ok: false, error: 'Could not open the navigation app.');
  }

  /// Platform-safe deep link builder — kept testable and pure. Uses the
  /// `geo:` scheme with a floating-label so Android and iOS both route to
  /// their maps app. No pre-populated user data is carried in the URL.
  Uri _navigationDeepLink({required double destLat, required double destLng, required String label}) {
    return Uri(
      scheme: 'geo',
      path: '$destLat,$destLng',
      queryParameters: {
        'q': '$destLat,$destLng(${Uri.encodeComponent(label)})',
      },
    );
  }

  /// After "Recalculate route?" is answered yes, re-runs calculation and
  /// replaces the current route. Remains in live mode.
  Future<void> recalculate() async {
    await ref.read(tripCalculationProvider.notifier).calculate();
    final calc = ref.read(tripCalculationProvider).valueOrNull;
    final current = state;
    if (calc == null || calc.routes.isEmpty || current == null) return;
    final route = calc.routes.firstWhere(
      (r) => r.routeType == 'recommended',
      orElse: () => calc.routes.first,
    );
    state = LiveTrip(
      sessionId: current.sessionId,
      originLabel: current.originLabel,
      destinationLabel: current.destinationLabel,
      destinationLat: current.destinationLat,
      destinationLng: current.destinationLng,
      route: route,
      startedAt: current.startedAt,
    );
    _listenForDeviation();
  }

  /// Acknowledges the deviation and continues without recalculating.
  void ignoreDeviation() {
    final current = state;
    if (current == null) return;
    state = current.copyWith(deviationDetected: false);
  }

  void end() {
    _positionSub?.cancel();
    state = null;
  }
}

/// Pure haversine distance (km) between two coordinates. Exported for tests.
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

final liveTripProvider = NotifierProvider<LiveTripNotifier, LiveTrip?>(
  LiveTripNotifier.new,
);