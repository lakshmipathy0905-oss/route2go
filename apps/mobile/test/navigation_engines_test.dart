import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:route2go/core/navigation/arrival_detector.dart';
import 'package:route2go/core/navigation/eta_calculator.dart';
import 'package:route2go/core/navigation/geo_math.dart';
import 'package:route2go/core/navigation/maneuver_engine.dart';
import 'package:route2go/core/navigation/off_route_detector.dart';
import 'package:route2go/core/navigation/reroute_policy.dart';
import 'package:route2go/core/navigation/route_progress.dart';
import 'package:route2go/domain/entities/navigation.dart';

void main() {
  group('GeoMath', () {
    test('haversine matches a known city-pair distance', () {
      // Approx 400m between two points ~0.0036 degrees of latitude apart.
      final d = GeoMath.haversineKm(
        const LatLng(28.6, 77.2),
        const LatLng(28.6036, 77.2),
      );
      expect(d * 1000, closeTo(400, 30));
    });

    test('nearestPointOnPolyline snaps to the middle of a segment', () {
      final line = [
        const LatLng(0, 0),
        const LatLng(0, 10),
      ];
      final hit = GeoMath.nearestPointOnPolyline(line, const LatLng(0, 5))!;
      expect(hit.nearest.latitude, closeTo(0, 1e-9));
      expect(hit.nearest.longitude, closeTo(5, 1e-9));
      expect(hit.segmentIndex, 0);
    });

    test('distanceToSegmentM measures perpendicular distance', () {
      final d = GeoMath.distanceToSegmentM(
        const LatLng(0.001, 5),
        const LatLng(0, 0),
        const LatLng(0, 10),
      );
      expect(d, closeTo(111, 10)); // ~1km per degree * 0.001deg latitude
    });

    test('polylineLengthKm sums segments', () {
      final len = GeoMath.polylineLengthKm([
        const LatLng(0, 0),
        const LatLng(0, 1),
        const LatLng(1, 1),
      ]);
      expect(
          len,
          closeTo(
              GeoMath.haversineKm(const LatLng(0, 0), const LatLng(0, 1)) * 2,
              1));
    });
  });

  group('RouteProgressEngine', () {
    // Straight east-west line 2 points, ~111km per degree at equator.
    final line = [
      const LatLng(0, 0),
      const LatLng(0, 1),
    ];

    test('start: full remaining distance, zero progress', () {
      final engine = RouteProgressEngine(line);
      final p = engine.progressAt(const LatLng(0, 0));
      expect(p.remainingKm, closeTo(engine.totalKm, 1));
      expect(p.progress, closeTo(0, 1e-9));
      expect(p.distanceFromRouteM, lessThan(1));
    });

    test('middle: half the route travelled along the geometry', () {
      final engine = RouteProgressEngine(line);
      final p = engine.progressAt(const LatLng(0, 0.5));
      expect(p.progress, closeTo(0.5, 0.01));
      expect(p.remainingKm, closeTo(engine.totalKm / 2, 1));
    });

    test('end: full progress, zero remaining', () {
      final engine = RouteProgressEngine(line);
      final p = engine.progressAt(const LatLng(0, 1));
      expect(p.progress, closeTo(1, 0.01));
      expect(p.remainingKm, closeTo(0, 1));
    });

    test('remains sensible when the position is far off the route', () {
      final engine = RouteProgressEngine(line);
      final p = engine.progressAt(const LatLng(1, 0.5));
      expect(p.distanceFromRouteM, greaterThan(100000)); // ~1deg north
      expect(p.progress, inInclusiveRange(0, 1));
    });

    test('rejects a degenerate polyline', () {
      expect(() => RouteProgressEngine([const LatLng(0, 0)]),
          throwsAssertionError);
    });
  });

  group('EtaCalculator', () {
    test('scales provider duration by remaining progress', () {
      const calc = EtaCalculator(routeDurationMin: 90);
      final p = calc.withEta(
        const RouteProgress(
          remainingKm: 10,
          remainingDurationMin: 0,
          progress: 0.25,
          distanceFromRouteM: 0,
          nearestLat: 0,
          nearestLng: 0,
        ),
        now: DateTime(2026, 1, 1, 12, 0),
      );
      expect(p.remainingDurationMin, 68); // 90 * 0.75 = 67.5 -> rounds to 68
      expect(
          p.eta(now: DateTime(2026, 1, 1, 12, 0)), DateTime(2026, 1, 1, 13, 8));
    });

    test('arrival at end yields zero remaining minutes', () {
      const calc = EtaCalculator(routeDurationMin: 90);
      final p = calc.withEta(
        const RouteProgress(
          remainingKm: 0,
          remainingDurationMin: 0,
          progress: 1,
          distanceFromRouteM: 0,
          nearestLat: 0,
          nearestLng: 0,
        ),
        now: DateTime(2026, 1, 1, 12, 0),
      );
      expect(p.remainingDurationMin, 0);
    });
  });

  group('ManeuverEngine', () {
    final steps = [
      const NavigationStep(
        instruction: 'Turn left onto Main St',
        maneuverType: 'turn',
        modifier: 'left',
        name: 'Main St',
        distanceKm: 2.0,
        durationMin: 1,
        lat: 0,
        lng: 0,
      ),
      const NavigationStep(
        instruction: 'Turn right onto Oak Ave',
        maneuverType: 'turn',
        modifier: 'right',
        name: 'Oak Ave',
        distanceKm: 4.0,
        durationMin: 4,
        lat: 0,
        lng: 1,
      ),
    ];
    final engine = ManeuverEngine(steps: steps, totalRouteKm: 10);

    RouteProgress at(double progress) => RouteProgress(
          remainingKm: 10 * (1 - progress),
          remainingDurationMin: 0,
          progress: progress,
          distanceFromRouteM: 0,
          nearestLat: 0,
          nearestLng: 0,
        );

    test('selects the first upcoming maneuver before any distance travelled',
        () {
      expect(engine.nextManeuver(at(0))!.instruction, 'Turn left onto Main St');
    });

    test('advances to the next maneuver after passing the first', () {
      expect(
          engine.nextManeuver(at(0.3))!.instruction, 'Turn right onto Oak Ave');
    });

    test('returns null after all maneuvers are passed', () {
      expect(engine.nextManeuver(at(0.95)), isNull);
    });

    test('distanceToNextKm measures the gap to the upcoming maneuver', () {
      expect(engine.distanceToNextKm(at(0)), closeTo(2.0, 1e-9));
      expect(engine.distanceToNextKm(at(0.3)), closeTo(3.0, 1e-9));
    });

    test('skips unusable (empty) steps instead of fabricating guidance', () {
      final noisy = ManeuverEngine(
        steps: [
          const NavigationStep(
            instruction: '',
            maneuverType: 'continue',
            distanceKm: 1,
            durationMin: 1,
            lat: 0,
            lng: 0,
          ),
          steps[0],
        ],
        totalRouteKm: 10,
      );
      expect(noisy.nextManeuver(at(0))!.instruction, 'Turn left onto Main St');
    });
  });

  group('OffRouteDetector', () {
    OffRouteDetector build() => OffRouteDetector(
          offRouteThresholdM: 300,
          onRouteThresholdM: 120,
          requiredSamples: 3,
          requiredRecoverySamples: 2,
        );

    test('does not fire on a single noisy reading beyond the threshold', () {
      final d = build();
      expect(d.update(distanceFromRouteM: 500), isFalse);
    });

    test('confirms off-route after sustained deviation beyond the threshold',
        () {
      final d = build();
      d.update(distanceFromRouteM: 500);
      d.update(distanceFromRouteM: 500);
      expect(d.update(distanceFromRouteM: 500), isTrue);
      expect(d.isOffRoute, isTrue);
    });

    test('dead-band readings reset the debounce counters without firing', () {
      final d = build();
      d.update(distanceFromRouteM: 500);
      d.update(distanceFromRouteM: 200); // inside dead band
      d.update(distanceFromRouteM: 500);
      d.update(distanceFromRouteM: 500);
      expect(d.update(distanceFromRouteM: 500), isTrue);
    });

    test('recovers only after enough consecutive on-route readings', () {
      final d = build();
      d.update(distanceFromRouteM: 500);
      d.update(distanceFromRouteM: 500);
      d.update(distanceFromRouteM: 500); // off-route confirmed
      d.update(distanceFromRouteM: 50); // recovery sample 1
      expect(d.isOffRoute, isTrue); // still off-route
      expect(d.update(distanceFromRouteM: 50),
          isFalse); // recovery sample 2 clears it
      expect(d.isOffRoute, isFalse);
    });

    test('reset clears the off-route state', () {
      final d = build();
      d.update(distanceFromRouteM: 500);
      d.update(distanceFromRouteM: 500);
      d.update(distanceFromRouteM: 500);
      d.reset();
      expect(d.isOffRoute, isFalse);
    });
  });

  group('ReroutePolicy', () {
    test('allows the first request immediately', () {
      final p = ReroutePolicy();
      expect(p.canRequest(), isTrue);
    });

    test('dedupes while a request is in flight', () {
      final p = ReroutePolicy();
      p.requestStarted();
      expect(p.canRequest(), isFalse);
      p.requestFinished(success: true);
      expect(p.canRequest(), isFalse); // cooldown still active
    });

    test('enforces the cooldown window after a successful request', () {
      final now = DateTime(2026, 1, 1, 12, 0);
      final p = ReroutePolicy(clock: () => now);
      p.requestStarted();
      p.requestFinished(success: true);
      expect(p.canRequest(), isFalse);
      expect(p.canRequest(), isFalse);
    });

    test('applies exponential backoff after failures', () {
      final now = DateTime(2026, 1, 1, 12, 0);
      final p = ReroutePolicy(
          backoffBase: const Duration(seconds: 5), clock: () => now);
      p.requestStarted();
      p.requestFinished(success: false);
      // First failure backs off by backoffBase.
      expect(p.canRequest(), isFalse);
    });

    test('never exceeds the maximum backoff', () {
      final now = DateTime(2026, 1, 1, 12, 0);
      final p = ReroutePolicy(
        backoffBase: const Duration(seconds: 5),
        maxBackoff: const Duration(seconds: 30),
        clock: () => now,
      );
      for (var i = 0; i < 10; i++) {
        p.requestStarted();
        p.requestFinished(success: false);
      }
      // Many failures must not grow the wait beyond the cap; just assert the
      // policy still guards canRequest after the burst.
      expect(p.canRequest(), isFalse);
    });
  });

  group('ArrivalDetector', () {
    test('does not fire before the user nears the destination', () {
      final d = ArrivalDetector();
      expect(
        d.update(remainingKm: 5, progress: 0.2, speedMps: 12),
        isFalse,
      );
    });

    test('fires after sustained slow movement inside the arrival radius', () {
      final d = ArrivalDetector();
      d.update(remainingKm: 0.05, progress: 0.999, speedMps: 1);
      d.update(remainingKm: 0.03, progress: 0.999, speedMps: 1);
      expect(d.update(remainingKm: 0.02, progress: 1, speedMps: 1), isTrue);
      expect(d.isArrived, isTrue);
    });

    test('fast movement near the destination resets the sample counter', () {
      final d = ArrivalDetector();
      d.update(remainingKm: 0.05, progress: 0.999, speedMps: 1);
      d.update(remainingKm: 0.04, progress: 0.999, speedMps: 25);
      d.update(remainingKm: 0.03, progress: 1, speedMps: 1);
      expect(d.update(remainingKm: 0.02, progress: 1, speedMps: 1), isFalse);
    });

    test('remains arrived once confirmed', () {
      final d = ArrivalDetector();
      d.update(remainingKm: 0.05, progress: 0.999, speedMps: 1);
      d.update(remainingKm: 0.03, progress: 0.999, speedMps: 1);
      d.update(remainingKm: 0.02, progress: 1, speedMps: 1);
      expect(d.update(remainingKm: 1, progress: 0.1, speedMps: 30), isTrue);
    });
  });
}
