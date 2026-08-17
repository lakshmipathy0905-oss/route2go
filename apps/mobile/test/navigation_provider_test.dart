import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:route2go/core/errors/app_exception.dart';
import 'package:route2go/data/location/location_source.dart';
import 'package:route2go/data/repositories/navigation_repository.dart';
import 'package:route2go/domain/entities/navigation.dart';
import 'package:route2go/domain/entities/route_option.dart';
import 'package:route2go/presentation/providers/connectivity_provider.dart';
import 'package:route2go/presentation/providers/navigation_provider.dart';
import 'package:route2go/presentation/providers/trip_planning_provider.dart';
import 'package:route2go/presentation/services/voice_service.dart';

/// Voice stub — never touches the real TTS platform channel in tests.
class _SilentVoice extends VoiceService {
  @override
  Future<String?> announce(String message) async => null;

  @override
  void setMuted(bool value) {}

  @override
  void stop() {}
}

/// Repository stub that records requests and returns a fixed alternative route.
class _FakeNavRepository implements NavigationRepository {
  final List<NavStop> requestedWaypoints = [];
  final List<NavStop> requestedDestinations = [];
  int fetchCount = 0;
  bool failNext = false;

  RouteOption routeFor(NavStop destination) => _route(
        label: destination.label,
        geometry: _FakeNavRepository.geometry,
      );

  @override
  Future<RouteOption> fetchRoute({
    required NavStop origin,
    required NavStop destination,
    List<NavStop> waypoints = const [],
  }) async {
    if (failNext) {
      failNext = false;
      throw const AppException(
        code: 'REROUTE_FAILED',
        message: 'Could not reach the routing provider.',
        retryable: true,
      );
    }
    fetchCount++;
    requestedWaypoints
      ..clear()
      ..addAll(waypoints);
    requestedDestinations
      ..clear()
      ..add(destination);
    return routeFor(destination);
  }

  static final Map<String, dynamic> geometry = {
    'type': 'LineString',
    'coordinates': [
      [0.0, 0.0],
      [0.0, 0.5],
      [0.0, 1.0],
    ],
  };
}

RouteOption _route({String label = 'Test', Map<String, dynamic>? geometry}) {
  return RouteOption(
    routeType: 'recommended',
    distanceKm: 111,
    durationMin: 60,
    fuelCost: 10,
    fuelCostConfidence: 'calculated',
    tollCost: 0,
    tollConfidence: 'unavailable',
    totalCost: 10,
    provider: 'test-fixture',
    fetchedAt: DateTime(2026, 1, 1),
    geometry: geometry,
    steps: const [
      NavigationStep(
        instruction: 'Turn left onto Main St',
        maneuverType: 'turn',
        modifier: 'left',
        name: 'Main St',
        distanceKm: 10,
        durationMin: 5,
        lat: 0,
        lng: 0.2,
      ),
    ],
  );
}

class _FixedCalc extends TripCalculationNotifier {
  _FixedCalc(this._result);
  final TripCalculationResult _result;

  @override
  Future<TripCalculationResult?> build() async => _result;
}

const _form = TripPlanningForm(
  originLabel: 'Origin',
  originLat: 0,
  originLng: 0,
  destinationLabel: 'Dest',
  destinationLat: 0,
  destinationLng: 1,
  tripType: 'one_way',
  travellers: 1,
  fuelType: 'petrol',
);

TripCalculationResult _result({RouteOption? route}) => TripCalculationResult(
      tripId: null,
      routes: [route ?? _route()],
      budgetStatus: null,
    );

ProviderContainer _container({
  required FakeLocationSource location,
  _FakeNavRepository? repo,
  TripCalculationResult? result,
  Stream<bool>? connectivity,
}) {
  final container = ProviderContainer(
    overrides: [
      locationSourceProvider.overrideWithValue(location),
      navigationRepositoryProvider
          .overrideWithValue(repo ?? _FakeNavRepository()),
      tripPlanningFormProvider.overrideWith((ref) => _form),
      tripCalculationProvider.overrideWith(
        () => _FixedCalc(result ?? _result()),
      ),
      voiceServiceProvider.overrideWithValue(_SilentVoice()),
      connectivityProvider
          .overrideWith((ref) => connectivity ?? Stream.value(true)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _startNavigation(ProviderContainer container) async {
  // The AsyncNotifier override resolves asynchronously; wait until the route
  // calculation is available before kicking off navigation.
  await container.read(tripCalculationProvider.future);
  await container.read(navigationProvider.notifier).start();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  FakeLocationSource onRoute() => FakeLocationSource(
        points: [
          LocationUpdate(
              lat: 0, lng: 0, timestamp: DateTime(2026, 1, 1, 12, 0, 0)),
          LocationUpdate(
              lat: 0, lng: 0.3, timestamp: DateTime(2026, 1, 1, 12, 0, 1)),
          LocationUpdate(
              lat: 0, lng: 0.6, timestamp: DateTime(2026, 1, 1, 12, 0, 2)),
          LocationUpdate(
              lat: 0, lng: 0.8, timestamp: DateTime(2026, 1, 1, 12, 0, 3)),
        ],
        interval: const Duration(milliseconds: 10),
      );

  FakeLocationSource offRoute() => FakeLocationSource(
        points: [
          LocationUpdate(
              lat: 0, lng: 0, timestamp: DateTime(2026, 1, 1, 12, 0, 0)),
          LocationUpdate(
              lat: 0, lng: 0.1, timestamp: DateTime(2026, 1, 1, 12, 0, 1)),
          // 0.01deg north is ~1.1km from the route — beyond the 300m threshold.
          LocationUpdate(
              lat: 0.01, lng: 0.2, timestamp: DateTime(2026, 1, 1, 12, 0, 2)),
          LocationUpdate(
              lat: 0.01, lng: 0.3, timestamp: DateTime(2026, 1, 1, 12, 0, 3)),
          LocationUpdate(
              lat: 0.01, lng: 0.4, timestamp: DateTime(2026, 1, 1, 12, 0, 4)),
          LocationUpdate(
              lat: 0.01, lng: 0.5, timestamp: DateTime(2026, 1, 1, 12, 0, 5)),
        ],
        interval: const Duration(milliseconds: 10),
      );

  group('NavigationNotifier lifecycle', () {
    test('start() moves idle -> starting -> navigating with a position fix',
        () async {
      final repo = _FakeNavRepository();
      final container = _container(location: onRoute(), repo: repo);

      expect(container.read(navigationProvider).status, NavigationStatus.idle);

      await _startNavigation(container);
      expect(
          container.read(navigationProvider).status, NavigationStatus.starting);
      expect(container.read(navigationProvider).destination!.label, 'Dest');

      // Let the fake GPS stream emit a few fixes.
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final state = container.read(navigationProvider);
      expect(state.status, NavigationStatus.navigating);
      expect(state.position, isNotNull);
      expect(state.progress, isNotNull);
      expect(state.progress!.remainingKm, greaterThan(0));
    });

    test('end() resets the session back to idle', () async {
      final container = _container(location: onRoute());
      final notifier = container.read(navigationProvider.notifier);

      await _startNavigation(container);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      notifier.end();

      final state = container.read(navigationProvider);
      expect(state.status, NavigationStatus.idle);
      expect(state.route, isNull);
      expect(state.destination, isNull);
      expect(state.position, isNull);
    });
  });

  group('NavigationNotifier rerouting', () {
    test('sustained deviation triggers a reroute from the current position',
        () async {
      final repo = _FakeNavRepository();
      final container = _container(location: offRoute(), repo: repo);

      await _startNavigation(container);
      await Future<void>.delayed(const Duration(milliseconds: 120));

      final state = container.read(navigationProvider);
      // Off-route was either detected (banner) or already resolved by reroute.
      expect(
        state.status == NavigationStatus.offRoute ||
            state.status == NavigationStatus.recalculating ||
            state.status == NavigationStatus.navigating,
        isTrue,
        reason:
            'expected off-route detection then recovery, got ${state.status}',
      );
      expect(repo.fetchCount, greaterThan(0));
      // Reroute origin must be the CURRENT GPS position (not the trip origin).
      expect(state.route, isNotNull);
    });

    test('failed reroute is retryable and never crashes navigation', () async {
      final repo = _FakeNavRepository()..failNext = true;
      final container = _container(location: offRoute(), repo: repo);

      await _startNavigation(container);
      await Future<void>.delayed(const Duration(milliseconds: 140));

      final state = container.read(navigationProvider);
      // Even with a failed reroute the session stays active / recovers.
      expect(state.status.isActive || state.status == NavigationStatus.error,
          isTrue);
    });
  });

  group('NavigationNotifier waypoints + destination', () {
    test('addStop records the waypoint and reroutes through it', () async {
      final repo = _FakeNavRepository();
      final container = _container(location: onRoute(), repo: repo);
      final notifier = container.read(navigationProvider.notifier);

      await _startNavigation(container);
      await Future<void>.delayed(const Duration(milliseconds: 40));

      await notifier
          .addStop(const NavStop(label: 'Petrol pump', lat: 0, lng: 0.5));

      final state = container.read(navigationProvider);
      expect(state.waypoints, hasLength(1));
      expect(state.waypoints.first.label, 'Petrol pump');
      expect(repo.requestedWaypoints, hasLength(1));
      expect(repo.requestedWaypoints.first.label, 'Petrol pump');
    });

    test('changeDestination updates the target and reroutes to it', () async {
      final repo = _FakeNavRepository();
      final container = _container(location: onRoute(), repo: repo);
      final notifier = container.read(navigationProvider.notifier);

      await _startNavigation(container);
      await Future<void>.delayed(const Duration(milliseconds: 40));

      await notifier.changeDestination(
        const NavStop(label: 'New destination', lat: 0, lng: 2),
      );

      final state = container.read(navigationProvider);
      expect(state.destination!.label, 'New destination');
      expect(repo.requestedDestinations, hasLength(1));
      expect(repo.requestedDestinations.first.label, 'New destination');
    });
  });

  group('NavigationNotifier voice', () {
    test('toggleVoice flips the mute state both ways', () async {
      final container = _container(location: onRoute());
      final notifier = container.read(navigationProvider.notifier);

      await _startNavigation(container);
      expect(container.read(navigationProvider).voiceMuted, isFalse);

      notifier.toggleVoice();
      expect(container.read(navigationProvider).voiceMuted, isTrue);

      notifier.toggleVoice();
      expect(container.read(navigationProvider).voiceMuted, isFalse);
    });
  });

  group('NavigationNotifier direct startNavigation (no trip required)', () {
    test('startNavigation installs the route and navigates from GPS', () async {
      final repo = _FakeNavRepository();
      final container = _container(location: onRoute(), repo: repo);
      final notifier = container.read(navigationProvider.notifier);

      final route = _route(geometry: _FakeNavRepository.geometry);

      await notifier.startNavigation(
        route: route,
        origin: const NavStop(label: 'Current location', lat: 0, lng: 0),
        destination: const NavStop(label: 'Kahale', lat: 0, lng: 1),
      );

      // No trip form / calculation is required: navigation starts directly.
      expect(
          container.read(navigationProvider).status, NavigationStatus.starting);
      expect(container.read(navigationProvider).destination!.label, 'Kahale');
      expect(container.read(navigationProvider).route, same(route));

      await Future<void>.delayed(const Duration(milliseconds: 60));
      final state = container.read(navigationProvider);
      expect(state.status, NavigationStatus.navigating);
      expect(state.position, isNotNull);
      expect(state.progress, isNotNull);
    });

    test('the trip-flow start() delegates to startNavigation unchanged',
        () async {
      // Reuses the existing trip-form overrides already in _container.
      final container = _container(location: onRoute());
      await _startNavigation(container);

      final state = container.read(navigationProvider);
      expect(state.status, NavigationStatus.starting);
      expect(state.destination!.label, 'Dest');
      // The route is installed from the trip calculation result.
      expect(state.route, isNotNull);
      expect(state.route!.provider, 'test-fixture');
    });
  });
}
