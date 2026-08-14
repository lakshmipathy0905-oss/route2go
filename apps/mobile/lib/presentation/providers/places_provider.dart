import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/places_repository.dart';
import '../../domain/entities/place.dart';
import 'trip_planning_provider.dart';

/// Places found along the current route (spec 2.4).
class PlacesNearRoute {
  const PlacesNearRoute({
    required this.places,
    this.categories = const [],
    this.requestedAt,
  });

  final List<Place> places;
  final List<PlaceCategory> categories;
  final DateTime? requestedAt;
}

class PlacesNotifier extends AsyncNotifier<PlacesNearRoute> {
  String _currentQueryKey = '';

  @override
  Future<PlacesNearRoute> build() async {
    return const PlacesNearRoute(places: []);
  }

  Future<void> load({bool force = false}) async {
    final form = ref.read(tripPlanningFormProvider);
    if (!form.isReadyToCalculate) {
      state = const AsyncData(PlacesNearRoute(places: []));
      return;
    }
    final calc = ref.read(tripCalculationProvider).valueOrNull;
    final route = calc == null || calc.routes.isEmpty
        ? null
        : calc.routes.firstWhere(
            (r) => r.routeType == 'recommended',
            orElse: () => calc.routes.first,
          );

    final key =
        '${form.originLat!},${form.originLng!},${form.destinationLat!},${form.destinationLng!}';
    if (!force && key == _currentQueryKey && state.hasValue) return;
    _currentQueryKey = key;

    state = const AsyncLoading();
    final repo = ref.read(placesRepositoryProvider);
    state = await AsyncValue.guard(() async {
      final places = await repo.placesNearRoute(
        originLat: form.originLat!,
        originLng: form.originLng!,
        destLat: form.destinationLat!,
        destLng: form.destinationLng!,
        routeDistanceKm: route?.distanceKm,
        routeDurationMin: route?.durationMin,
        fuelCostPerKm: (route?.fuelCost != null && route!.distanceKm > 0)
            ? route.fuelCost! / route.distanceKm
            : null,
      );
      List<PlaceCategory> categories = const [];
      try {
        categories = await repo.categories();
      } catch (_) {
        // Categories are a filter nicety; a fetch failure must not block the list.
      }
      return PlacesNearRoute(places: places, categories: categories);
    });
  }

  void reset() {
    _currentQueryKey = '';
    state = const AsyncData(PlacesNearRoute(places: []));
  }
}

final placesNearRouteProvider = AsyncNotifierProvider<PlacesNotifier, PlacesNearRoute>(
  PlacesNotifier.new,
);