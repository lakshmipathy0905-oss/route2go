import 'package:flutter_test/flutter_test.dart';

import 'package:route2go/domain/entities/route_option.dart';
import 'package:route2go/presentation/providers/trip_planning_provider.dart';

void main() {
  RouteOption routeWith({Map<String, dynamic>? geometry}) => RouteOption.fromJson({
        'route_type': 'recommended',
        'distance_km': 100,
        'duration_min': 90,
        'fuel_cost': 12.5,
        'fuel_cost_confidence': 'calculated',
        'toll_cost': 5.0,
        'toll_confidence': 'verified',
        'total_cost': 17.5,
        'provider': 'mock-dev-fixture',
        'fetched_at': '2026-01-01T00:00:00Z',
        if (geometry != null) 'geometry': geometry,
      });

  test('parses GeoJSON LineString geometry into [lng, lat] pairs', () {
    final route = routeWith(geometry: {
      'type': 'LineString',
      'coordinates': [
        [77.2, 28.6],
        [77.3, 28.7],
        [77.4, 28.8],
      ],
    });

    expect(route.geometry, isNotNull);
    expect(route.geometryCoordinates, [
      [77.2, 28.6],
      [77.3, 28.7],
      [77.4, 28.8],
    ]);
  });

  test('returns null coordinates when geometry is absent', () {
    final route = routeWith();
    expect(route.geometry, isNull);
    expect(route.geometryCoordinates, isNull);
  });

  test('returns null coordinates for malformed geometry', () {
    expect(routeWith(geometry: {'type': 'LineString', 'coordinates': 'nope'}).geometryCoordinates,
        isNull);
    expect(routeWith(geometry: {'type': 'LineString', 'coordinates': [[77.2]]}).geometryCoordinates,
        isNull);
    expect(
        routeWith(geometry: {'type': 'Point', 'coordinates': [77.2, 28.6]}).geometryCoordinates, isNull);
    expect(routeWith(geometry: {'type': 'LineString', 'coordinates': []}).geometryCoordinates, isNull);
  });

  test('selectRoute honours the selected type and falls back safely', () {
    final result = TripCalculationResult.fromJson({
      'data': {
        'routes': [
          {
            'route_type': 'fastest',
            'distance_km': 90,
            'duration_min': 80,
            'total_cost': 20.0,
            'provider': 'mock-dev-fixture',
            'fetched_at': '2026-01-01T00:00:00Z',
          },
          {
            'route_type': 'recommended',
            'distance_km': 100,
            'duration_min': 90,
            'total_cost': 17.5,
            'provider': 'mock-dev-fixture',
            'fetched_at': '2026-01-01T00:00:00Z',
          },
        ],
      },
    });

    expect(selectRoute(result, 'fastest')!.routeType, 'fastest');
    expect(selectRoute(result, 'missing')!.routeType, 'recommended');
    expect(selectRoute(null, 'fastest'), isNull);
  });
}