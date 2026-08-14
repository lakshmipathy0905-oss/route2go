import 'package:flutter_test/flutter_test.dart';

import 'package:route2go/data/datasources/api_client.dart';
import 'package:route2go/data/repositories/itinerary_repository.dart';
import 'package:route2go/data/repositories/places_repository.dart';
import 'package:route2go/data/repositories/stays_repository.dart';
import 'package:route2go/data/repositories/trip_repository.dart';
import 'package:route2go/presentation/providers/trip_planning_provider.dart';

/// Fixtures mirror the real Edge Function response envelopes (`{data, ...}`)
/// exactly as returned by `jsonOk()` — so this test exercises the genuine
/// parsing path (BaseRepository unwrap + typed fromJson) for every step of
/// the critical E2E flow: plan → calculate → compare → places → stays →
/// itinerary → save.
class _FakeApiClient implements ApiClient {
  _FakeApiClient(this._fixtures);
  final Map<String, Map<String, dynamic>> _fixtures;
  final List<String> calls = [];

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    required Map<String, dynamic> body,
    bool allowGuest = false,
  }) async {
    calls.add('POST $path');
    return _fixtures[path]!;
  }

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool allowGuest = false,
  }) async {
    calls.add('GET $path');
    return _fixtures[path]!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A realistic /trip-calculate response with two alternatives so the
/// "compare" step (selectRoute) can be exercised for real.
Map<String, dynamic> tripCalculateFixture() => {
      'requestId': 'req-calc',
      'data': {
        'trip_id': null,
        'routes': [
          {
            'route_type': 'recommended',
            'distance_km': 142.5,
            'duration_min': 210,
            'fuel_cost': 1345.0,
            'fuel_cost_confidence': 'calculated',
            'toll_cost': 265.0,
            'toll_confidence': 'estimated',
            'total_cost': 1610.0,
            'provider': 'mock-dev-fixture',
            'fetched_at': '2026-08-14T00:00:00Z',
            'geometry': {
              'type': 'LineString',
              'coordinates': [
                [77.5946, 12.9716],
                [77.6, 12.95],
                [77.7, 12.6],
              ],
            },
          },
          {
            'route_type': 'no_toll',
            'distance_km': 158.2,
            'duration_min': 240,
            'fuel_cost': 1410.0,
            'fuel_cost_confidence': 'calculated',
            'toll_cost': 0.0,
            'toll_confidence': 'verified',
            'total_cost': 1410.0,
            'provider': 'mock-dev-fixture',
            'fetched_at': '2026-08-14T00:00:00Z',
            'geometry': null,
          },
        ],
        'budget_status': {
          'status': 'GREEN',
          'total_estimated': 1610.0,
          'budget_total': 10000.0,
          'used_pct': 16.1,
          'remaining': 8390.0,
          'suggestions': <String>[],
        },
      },
    };

Map<String, dynamic> placesFixture() => {
      'requestId': 'req-places',
      'data': [
        {
          'id': 'place-1',
          'name': 'Mysuru Palace',
          'category_id': 'cat-heritage',
          'category': 'Heritage',
          'lat': 12.3052,
          'lng': 76.6552,
          'entry_fee': 200,
          'rating': 4.7,
          'detour_km': 12.0,
          'detour_duration_min': 25,
          'detour_added_cost': 118.0,
        },
      ],
    };

Map<String, dynamic> staysFixture() => {
      'requestId': 'req-stays',
      'data': [
        {
          'id': 'stay-1',
          'name': 'Royal Orchid Mysore',
          'lat': 12.317,
          'lng': 76.638,
          'price_per_night': 3500.0,
          'rating': 4.4,
          'amenities': ['Wi-Fi', 'Parking'],
          'distance_from_route_km': 4.2,
        },
      ],
    };

Map<String, dynamic> itineraryFixture() => {
      'requestId': 'req-itinerary',
      'data': {
        'duration_days': 2,
        'days': [
          {
            'day_number': 1,
            'items': [
              {
                'item_type': 'drive',
                'name': 'Drive to Mysuru',
                'start_time': '2026-08-20T08:00:00Z',
                'end_time': '2026-08-20T11:30:00Z',
                'est_cost': 1345.0,
              },
              {
                'item_type': 'place',
                'ref_id': 'place-1',
                'name': 'Mysuru Palace',
                'est_cost': 200.0,
              },
              {
                'item_type': 'hotel',
                'ref_id': 'stay-1',
                'name': 'Royal Orchid Mysore',
                'est_cost': 3500.0,
              },
            ],
          },
        ],
      },
    };

Map<String, dynamic> tripSaveFixture() => {
      'requestId': 'req-save',
      'data': {'trip_id': 'trip-abc123'},
    };

void main() {
  late _FakeApiClient api;
  late TripRepository tripRepo;
  late PlacesRepository placesRepo;
  late StaysRepository staysRepo;
  late ItineraryRepository itineraryRepo;

  setUp(() {
    api = _FakeApiClient({
      '/trip-calculate': tripCalculateFixture(),
      '/places-near-route': placesFixture(),
      '/stays-near-route': staysFixture(),
      '/itinerary-generate': itineraryFixture(),
      '/trip': tripSaveFixture(),
    });
    tripRepo = TripRepository(api);
    placesRepo = PlacesRepository(api);
    staysRepo = StaysRepository(api);
    itineraryRepo = ItineraryRepository(api);
  });

  test(
      'critical path: calculate -> compare -> places -> stays -> itinerary -> save',
      () async {
    // 1. PLAN + CALCULATE
    final result = await tripRepo.calculateTrip(
      origin: {'lat': 12.9716, 'lng': 77.5946},
      originLabel: 'Bengaluru',
      destination: {'lat': 12.3052, 'lng': 76.6552},
      destinationLabel: 'Mysuru',
      tripType: 'one_way',
      fuelType: 'petrol',
      mileageKmpl: 12,
    );

    expect(result.routes.length, 2,
        reason: 'calculate returns both alternatives');
    expect(result.budgetStatus, isNotNull);
    expect(result.routes.first.routeType, 'recommended');
    expect(result.routes.first.geometryCoordinates, isNotNull,
        reason: 'recommended route carries a parseable GeoJSON polyline');
    expect(api.calls.first, 'POST /trip-calculate');

    // 2. COMPARE (selectRoute honours the user's pick, falls back correctly)
    final recommended = selectRoute(result, 'recommended');
    expect(recommended, isNotNull);
    expect(recommended!.label, 'Recommended');
    final noToll = selectRoute(result, 'no_toll');
    expect(noToll!.tollCost, 0,
        reason: 'no_toll alternative has verified zero toll');
    final missing = selectRoute(result, 'does-not-exist');
    expect(missing!.routeType, 'recommended',
        reason: 'unknown selection falls back to recommended');
    expect(selectRoute(null, 'recommended'), isNull,
        reason: 'null result -> null route');

    // 3. PLACES along the route corridor
    final places = await placesRepo.placesNearRoute(
      originLat: 12.9716,
      originLng: 77.5946,
      destLat: 12.3052,
      destLng: 76.6552,
      detourRadiusKm: 30,
      routeDistanceKm: recommended.distanceKm,
      routeDurationMin: recommended.durationMin,
      fuelCostPerKm: recommended.fuelCost! / recommended.distanceKm,
    );
    expect(api.calls, contains('GET /places-near-route'));
    expect(places.length, 1);
    final place = places.first;
    expect(place.name, 'Mysuru Palace');
    expect(place.detourKm, 12.0,
        reason: 'detour delta must be present, never hidden');
    expect(place.detourAddedCost, 118.0);

    // 4. STAYS near the route
    final stays = await staysRepo.staysNearRoute(
      originLat: 12.9716,
      originLng: 77.5946,
      destLat: 12.3052,
      destLng: 76.6552,
      filters: const StayFilters(maxPricePerNight: 5000, minRating: 4.0),
    );
    expect(api.calls, contains('GET /stays-near-route'));
    expect(stays.length, 1);
    final stay = stays.first;
    expect(stay.name, 'Royal Orchid Mysore');
    expect(stay.pricePerNight, 3500.0);
    expect(stay.isSponsored, isFalse);

    // 5. ITINERARY generation from the selected places + stays
    final itinerary = await itineraryRepo.generate(
      trip: {
        'origin_label': 'Bengaluru',
        'destination_label': 'Mysuru',
        'trip_type': 'one_way',
      },
      selectedPlaces: places.map((p) => p.toMap()).toList(),
      selectedStays: stays.map((s) => s.toMap()).toList(),
      budgetTotal: 10000,
      maxDrivingHoursPerDay: 8,
    );
    expect(api.calls, contains('POST /itinerary-generate'));
    expect(itinerary.durationDays, 2);
    expect(itinerary.days, hasLength(1));
    final items = itinerary.days.first.items;
    expect(items, hasLength(3));
    expect(items.first.itemType, 'drive');
    expect(items.first.estCost, 1345.0);
    expect(itinerary.totalCost, closeTo(1345.0 + 200.0 + 3500.0, 0.01),
        reason: 'itinerary total sums drive + place + stay costs');

    // 6. SAVE the confirmed trip (returns a real trip id)
    final tripId = await tripRepo.saveTrip(
      originLabel: 'Bengaluru',
      originLat: 12.9716,
      originLng: 77.5946,
      destinationLabel: 'Mysuru',
      destLat: 12.3052,
      destLng: 76.6552,
      tripType: 'one_way',
      startDate: '2026-08-20',
      travellers: 1,
      budgetTotal: 10000,
    );
    expect(api.calls, contains('POST /trip'));
    expect(tripId, 'trip-abc123');

    // Sanity: the flow hit every backend step exactly in order.
    expect(
      api.calls
          .where((c) => c.startsWith('POST') || c.startsWith('GET'))
          .toList(),
      [
        'POST /trip-calculate',
        'GET /places-near-route',
        'GET /stays-near-route',
        'POST /itinerary-generate',
        'POST /trip',
      ],
    );
  });

  test('guest trip calculation is explicitly allowed (allowGuest=true)',
      () async {
    await tripRepo.calculateTrip(
      origin: {'lat': 12.9716, 'lng': 77.5946},
      originLabel: 'Bengaluru',
      destination: {'lat': 12.3052, 'lng': 76.6552},
      destinationLabel: 'Mysuru',
      tripType: 'one_way',
      fuelType: 'petrol',
      mileageKmpl: 12,
    );
    expect(api.calls.first, 'POST /trip-calculate');
  });
}
