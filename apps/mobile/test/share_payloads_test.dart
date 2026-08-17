import 'package:flutter_test/flutter_test.dart';

import 'package:route2go/presentation/widgets/sharing_widgets.dart';

void main() {
  group('buildDestinationShareText', () {
    test('includes title, category · city and coordinates when known', () {
      final text = buildDestinationShareText(
        title: 'Cafe Coffee Day',
        subtitle: 'MG Road',
        category: 'cafe',
        city: 'Bengaluru',
        lat: 12.9716,
        lng: 77.5946,
      );
      expect(text, contains('Cafe Coffee Day'));
      expect(text, contains('cafe · Bengaluru'));
      expect(text, contains('MG Road'));
      expect(text, contains('Location: 12.971600, 77.594600'));
    });

    test('falls back to Place for an unknown category but keeps the city', () {
      final text = buildDestinationShareText(
        title: 'Kahale',
        city: 'Hawaii',
        lat: 21.3156,
        lng: -157.8766,
      );
      expect(text, contains('Place · Hawaii'));
      expect(text, isNot(contains('Cafe')));
    });

    test('never fabricates a route or calculating state', () {
      final text = buildDestinationShareText(
        title: 'Somewhere',
        lat: 1.0,
        lng: 2.0,
      );
      expect(text.toLowerCase(), isNot(contains('calculating')));
      expect(text.toLowerCase(), isNot(contains('route')));
      expect(text, contains('Location: 1.000000, 2.000000'));
    });

    test('drops coordinates when the result has none', () {
      final text = buildDestinationShareText(title: 'Unlocated');
      expect(text, 'Unlocated');
      expect(text, isNot(contains('Location:')));
    });
  });

  group('buildRouteShareText', () {
    test('carries the real route info and both coordinates', () {
      final text = buildRouteShareText(
        originLabel: 'Home',
        destinationLabel: 'Kahale',
        routeLabel: 'Recommended',
        distanceKm: 42.5,
        durationMin: 95,
        totalCost: 340,
        originLat: 12.9,
        originLng: 77.5,
        destinationLat: 21.3156,
        destinationLng: -157.8766,
      );
      expect(text, contains('Route2Go route'));
      expect(text, contains('Home → Kahale'));
      expect(text, contains('Recommended · 42.5 km · 1h 35m'));
      expect(text, contains('Est. total: ₹340'));
      expect(text, contains('Origin: 12.900000, 77.500000'));
      expect(text, contains('Destination: 21.315600, -157.876600'));
    });

    test('omits the cost line when there is none', () {
      final text = buildRouteShareText(
        originLabel: 'A',
        destinationLabel: 'B',
        routeLabel: 'Fastest',
        distanceKm: 3,
        durationMin: 8,
      );
      expect(text, isNot(contains('Est. total')));
      expect(text, contains('Fastest · 3.0 km · 8m'));
    });
  });
}
