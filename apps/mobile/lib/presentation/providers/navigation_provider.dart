import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/errors/app_exception.dart';
import '../../core/navigation/arrival_detector.dart';
import '../../core/navigation/eta_calculator.dart';
import '../../core/navigation/maneuver_engine.dart';
import '../../core/navigation/off_route_detector.dart';
import '../../core/navigation/reroute_policy.dart';
import '../../core/navigation/route_progress.dart';
import '../../data/location/location_source.dart';
import '../../data/repositories/navigation_repository.dart';
import '../../domain/entities/navigation.dart';
import '../../domain/entities/route_option.dart';
import '../services/voice_service.dart';
import 'connectivity_provider.dart';
import 'trip_planning_provider.dart';

/// Immutable snapshot of the in-app navigation session. UI layers select only
/// the slices they need (position, route, maneuver, status) so a GPS event
/// does not rebuild the whole screen.
class NavigationState {
  const NavigationState({
    this.status = NavigationStatus.idle,
    this.route,
    this.originLabel,
    this.destination,
    this.waypoints = const [],
    this.position,
    this.progress,
    this.nextManeuver,
    this.distanceToNextKm = 0,
    this.voiceMuted = false,
    this.lastError,
    this.offline = false,
  });

  final NavigationStatus status;
  final RouteOption? route;

  /// The trip's origin label (shown for context; navigation starts from the
  /// current GPS position after the first fix).
  final String? originLabel;

  /// The current navigation destination (changeable mid-ride).
  final NavStop? destination;

  /// Intermediate stops added during the ride, in visit order.
  final List<NavStop> waypoints;

  final LocationUpdate? position;
  final RouteProgress? progress;
  final NavigationStep? nextManeuver;
  final double distanceToNextKm;
  final bool voiceMuted;
  final String? lastError;

  /// True when the device reports no network. Used to stop reroutes from
  /// hammering a provider we cannot reach.
  final bool offline;

  NavigationState copyWith({
    NavigationStatus? status,
    RouteOption? route,
    String? originLabel,
    NavStop? destination,
    List<NavStop>? waypoints,
    LocationUpdate? position,
    RouteProgress? progress,
    NavigationStep? nextManeuver,
    double? distanceToNextKm,
    bool? voiceMuted,
    String? lastError,
    bool? offline,
  }) {
    return NavigationState(
      status: status ?? this.status,
      route: route ?? this.route,
      originLabel: originLabel ?? this.originLabel,
      destination: destination ?? this.destination,
      waypoints: waypoints ?? this.waypoints,
      position: position ?? this.position,
      progress: progress ?? this.progress,
      nextManeuver: nextManeuver ?? this.nextManeuver,
      distanceToNextKm: distanceToNextKm ?? this.distanceToNextKm,
      voiceMuted: voiceMuted ?? this.voiceMuted,
      lastError: lastError ?? this.lastError,
      offline: offline ?? this.offline,
    );
  }
}

/// Live in-app GPS navigation engine. Owns the location stream, route-following
/// progress, off-route detection, rerouting, maneuver selection, ETA and
/// arrival — exposed as a single Riverpod [NavigationState].
class NavigationNotifier extends Notifier<NavigationState> {
  StreamSubscription<LocationUpdate>? _positionSub;
  ProviderSubscription<AsyncValue<bool>>? _connectivitySub;
  Timer? _rerouteRetry;
  OffRouteDetector? _offRouteDetector;
  ArrivalDetector? _arrivalDetector;
  ReroutePolicy? _reroutePolicy;
  RouteProgressEngine? _progressEngine;
  EtaCalculator? _eta;
  ManeuverEngine? _maneuverEngine;
  bool _deviationPending = false;
  bool _announcedArrival = false;
  String? _lastManeuverKey;

  VoiceService? _voice;
  NavigationRepository get _repo => ref.read(navigationRepositoryProvider);
  LocationSource get _location => ref.read(locationSourceProvider);
  bool _disposed = false;

  @override
  NavigationState build() {
    _voice = ref.read(voiceServiceProvider);
    ref.onDispose(() {
      _disposed = true;
      _positionSub?.cancel();
      _connectivitySub?.close();
      _rerouteRetry?.cancel();
      _voice?.stop();
    });

    _connectivitySub = ref.listen<AsyncValue<bool>>(connectivityProvider, (prev, next) {
      final online = next.value ?? false;
      _onConnectivityChanged(online);
    });

    return const NavigationState();
  }

  /// Starts navigation from the trip already selected in Phase 1 (the active
  /// RouteOption carries geometry + steps). Resolves a current GPS position,
  /// subscribes to the live stream, and enters [NavigationStatus.navigating].
  Future<void> start() async {
    final form = ref.read(tripPlanningFormProvider);
    final calc = ref.read(tripCalculationProvider).valueOrNull;
    if (!form.isReadyToCalculate || calc == null || calc.routes.isEmpty) return;

    final route = selectRoute(calc, ref.read(selectedRouteTypeProvider));
    if (route == null) return;

    final destination = NavStop(
      label: form.destinationLabel!,
      lat: form.destinationLat!,
      lng: form.destinationLng!,
    );

    state = NavigationState(
      status: NavigationStatus.starting,
      route: route,
      originLabel: form.originLabel,
      destination: destination,
      waypoints: const [],
      voiceMuted: state.voiceMuted,
    );

    _installRoute(route);

    final perm = await _location.hasPermission;
    if (!perm) {
      if (!_disposed) {
        state = state.copyWith(status: NavigationStatus.locationUnavailable);
      }
      return;
    }

    _positionSub = _location.updates.listen(
      _onLocation,
      onError: (_) {
        if (_disposed) return;
        state = state.copyWith(status: NavigationStatus.locationUnavailable);
      },
    );
  }

  void _installRoute(RouteOption route) {
    final coords = route.geometryCoordinates;
    final polyline = coords == null || coords.isEmpty
        ? _fallbackPolyline(route)
        : coords.map((p) => LatLng(p[1], p[0])).toList();

    _progressEngine = RouteProgressEngine(polyline);
    _eta = EtaCalculator(routeDurationMin: route.durationMin);
    _maneuverEngine = ManeuverEngine(
      steps: route.steps,
      totalRouteKm: _progressEngine!.totalKm,
    );
    _offRouteDetector = OffRouteDetector(
      offRouteThresholdM: 300,
      onRouteThresholdM: 120,
      requiredSamples: 3,
      requiredRecoverySamples: 2,
    );
    _arrivalDetector = ArrivalDetector();
    _reroutePolicy ??= ReroutePolicy();
    _deviationPending = false;
    _announcedArrival = false;
    _lastManeuverKey = null;
  }

  /// Straight origin->destination polyline used only when the provider returned
  /// no geometry, so progress still degrades gracefully to a straight line.
  List<LatLng> _fallbackPolyline(RouteOption route) {
    final dest = state.destination;
    if (dest == null) return const [];
    // origin comes from the trip form (start position), destination from state.
    final form = ref.read(tripPlanningFormProvider);
    return [
      LatLng(form.originLat ?? dest.lat, form.originLng ?? dest.lng),
      LatLng(dest.lat, dest.lng),
    ];
  }

  void _onLocation(LocationUpdate update) {
    if (_disposed) return;
    final route = state.route;
    if (route == null) return;

    state = state.copyWith(position: update);

    // Arrival short-circuit: stop GPS processing once arrived.
    if (state.status == NavigationStatus.arrived) {
      return;
    }

    final progressEngine = _progressEngine;
    if (progressEngine == null) return;

    var progress = progressEngine.progressAt(LatLng(update.lat, update.lng));
    progress = _eta?.withEta(progress, now: update.timestamp) ?? progress;

    state = state.copyWith(
      status: NavigationStatus.navigating,
      progress: progress,
    );

    // Dev-only diagnostics for on-device validation. Logs sensor/route metrics
    // and status — deliberately NOT the raw coordinates (privacy: no location
    // history is written to logs; debug builds only).
    if (kDebugMode) {
      debugPrint(
        'navDiag status=${state.status.name} '
        'acc=${update.accuracyMeters?.toStringAsFixed(1) ?? '-'}m '
        'speed=${update.speedMps?.toStringAsFixed(1) ?? '-'}m/s '
        'heading=${update.headingDegrees?.toStringAsFixed(0) ?? '-'} '
        't=${update.timestamp.toIso8601String()} '
        'remainingKm=${progress.remainingKm.toStringAsFixed(2)} '
        'offRouteM=${progress.distanceFromRouteM.toStringAsFixed(0)} '
        'next=${state.nextManeuver?.instruction ?? 'none'}',
      );
    }

    _updateManeuver(progress, update);
    _updateArrival(progress, update);
    _updateOffRoute(progress, update);
  }

  void _updateManeuver(RouteProgress progress, LocationUpdate update) {
    final engine = _maneuverEngine;
    if (engine == null) {
      state = state.copyWith(nextManeuver: null, distanceToNextKm: 0);
      return;
    }
    final next = engine.nextManeuver(progress);
    final distKm = engine.distanceToNextKm(progress);
    state = state.copyWith(nextManeuver: next, distanceToNextKm: distKm);

    if (next == null) return;

    // Voice: announce when a maneuver becomes next, or when the approach
    // crosses a coarse distance bucket — never on every GPS tick.
    final bucket = _announceBucket(distKm);
    if (bucket == null) return;
    final key = '${next.instruction}|$bucket';
    if (key == _lastManeuverKey) return;
    _lastManeuverKey = key;
    final meters = (distKm * 1000).round();
    _voice?.announce('In $meters meters, ${next.instruction}');
  }

  int? _announceBucket(double distKm) {
    if (distKm <= 0.1) return 100;
    if (distKm <= 0.2) return 200;
    if (distKm <= 0.5) return 500;
    if (distKm <= 2.0) return 2000;
    return null;
  }

  void _updateArrival(RouteProgress progress, LocationUpdate update) {
    final detector = _arrivalDetector;
    if (detector == null) return;
    final arrived = detector.update(
      remainingKm: progress.remainingKm,
      progress: progress.progress,
      speedMps: update.speedMps ?? 0,
    );
    if (arrived && !_announcedArrival) {
      _announcedArrival = true;
      _positionSub?.cancel();
      _voice?.announce('You have arrived at your destination.');
      state = state.copyWith(status: NavigationStatus.arrived);
    }
  }

  void _updateOffRoute(RouteProgress progress, LocationUpdate update) {
    final detector = _offRouteDetector;
    if (detector == null) return;
    final offRoute = detector.update(distanceFromRouteM: progress.distanceFromRouteM);

    if (offRoute) {
      if (!_deviationPending) {
        _deviationPending = true;
        state = state.copyWith(status: NavigationStatus.offRoute);
        unawaited(_requestReroute());
      }
    } else {
      _deviationPending = false;
      if (state.status == NavigationStatus.offRoute ||
          state.status == NavigationStatus.recalculating) {
        // Back on track (or never rerouted) — resume normal progress display.
        if (state.status != NavigationStatus.recalculating) {
          state = state.copyWith(status: NavigationStatus.navigating);
        }
      }
    }
  }

  /// Reroutes from the CURRENT GPS position through any added stops to the
  /// (possibly changed) destination. Guarded by [ReroutePolicy] so a public
  /// OSRM server is never hammered; deduplicates in-flight requests.
  Future<void> _requestReroute() async {
    final policy = _reroutePolicy;
    final current = state;
    if (policy == null || current.destination == null) return;

    if (state.offline) return; // will be triggered on reconnect

    if (!policy.canRequest()) return;
    policy.requestStarted();
    state = state.copyWith(status: NavigationStatus.recalculating);

    try {
      final origin = await _location.getCurrentPosition();
      if (origin == null) {
        policy.requestFinished(success: false);
        _scheduleRerouteRetry();
        return;
      }

      final newRoute = await _repo.fetchRoute(
        origin: NavStop(label: 'Current location', lat: origin.lat, lng: origin.lng),
        destination: current.destination!,
        waypoints: current.waypoints,
      );

      policy.requestFinished(success: true);
      if (_disposed) return;
      _installRoute(newRoute);
      state = state.copyWith(
        route: newRoute,
        status: NavigationStatus.navigating,
        lastError: null,
      );
    } on AppException catch (e) {
      policy.requestFinished(success: false);
      if (_disposed) return;
      state = state.copyWith(
        status: NavigationStatus.navigating,
        lastError: e.retryable ? null : e.message,
      );
      _scheduleRerouteRetry();
    } catch (_) {
      policy.requestFinished(success: false);
      if (_disposed) return;
      state = state.copyWith(status: NavigationStatus.navigating, lastError: null);
      _scheduleRerouteRetry();
    }
  }

  void _scheduleRerouteRetry() {
    final policy = _reroutePolicy;
    if (policy == null) return;
    _rerouteRetry?.cancel();
    final nextAllowed = policy.canRequest();
    if (nextAllowed && _deviationPending) {
      // Backoff window already elapsed; retry soon.
      _rerouteRetry = Timer(const Duration(seconds: 3), () {
        if (_deviationPending) unawaited(_requestReroute());
      });
    } else if (_deviationPending) {
      unawaited(policy.waitUntilAllowed().then((_) {
        if (_deviationPending) unawaited(_requestReroute());
      }));
    }
  }

  void _onConnectivityChanged(bool online) {
    state = state.copyWith(offline: !online);
    if (online && _deviationPending && state.status != NavigationStatus.recalculating) {
      unawaited(_requestReroute());
    }
  }

  /// Manual "Recalculate" — reroutes from the current position immediately,
  /// respecting the cooldown/dedupe policy.
  Future<void> recalculate() async {
    if (state.destination == null) return;
    _deviationPending = true;
    state = state.copyWith(status: NavigationStatus.offRoute);
    await _requestReroute();
  }

  /// Adds an intermediate stop and reroutes: CURRENT -> stop(s) -> destination.
  Future<void> addStop(NavStop stop) async {
    final current = state;
    if (current.waypoints.any((w) => w.label == stop.label)) return;
    final waypoints = [...current.waypoints, stop];
    state = state.copyWith(waypoints: waypoints);
    _deviationPending = true;
    state = state.copyWith(status: NavigationStatus.offRoute);
    await _requestReroute();
  }

  /// Changes the final destination and reroutes from the current position.
  Future<void> changeDestination(NavStop destination) async {
    state = state.copyWith(destination: destination);
    _deviationPending = true;
    state = state.copyWith(status: NavigationStatus.offRoute);
    await _requestReroute();
  }

  void toggleVoice() {
    final muted = !state.voiceMuted;
    _voice?.setMuted(muted);
    state = state.copyWith(voiceMuted: muted);
  }

  void pause() {
    if (state.status != NavigationStatus.navigating &&
        state.status != NavigationStatus.offRoute) {
      return;
    }
    _positionSub?.cancel();
    _voice?.stop();
    state = state.copyWith(status: NavigationStatus.paused);
  }

  void resume() {
    if (state.status != NavigationStatus.paused) return;
    _positionSub = _location.updates.listen(
      _onLocation,
      onError: (_) {
        if (_disposed) return;
        state = state.copyWith(status: NavigationStatus.locationUnavailable);
      },
    );
    state = state.copyWith(status: NavigationStatus.navigating);
  }

  void dismissError() {
    state = state.copyWith(status: NavigationStatus.navigating, lastError: null);
  }

  void end() {
    _positionSub?.cancel();
    _connectivitySub?.close();
    _rerouteRetry?.cancel();
    _voice?.stop();
    _offRouteDetector?.reset();
    _arrivalDetector?.reset();
    state = const NavigationState();
  }
}

final navigationProvider = NotifierProvider<NavigationNotifier, NavigationState>(
  NavigationNotifier.new,
);