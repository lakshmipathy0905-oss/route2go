import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/itinerary_repository.dart';
import '../../domain/entities/itinerary.dart';
import '../../domain/entities/place.dart';
import '../../domain/entities/stay.dart';
import 'places_provider.dart';
import 'stays_provider.dart';
import 'trip_planning_provider.dart';

class ItineraryNotifier extends AsyncNotifier<ItineraryPlan?> {
  double _maxDrivingHoursPerDay = 8;

  @override
  Future<ItineraryPlan?> build() async => null;

  double get maxDrivingHoursPerDay => _maxDrivingHoursPerDay;

  Future<void> generate({double maxDrivingHoursPerDay = 8}) async {
    _maxDrivingHoursPerDay = maxDrivingHoursPerDay;
    final form = ref.read(tripPlanningFormProvider);
    if (!form.isReadyToCalculate) {
      state = const AsyncData(null);
      return;
    }

    final places = ref.read(placesNearRouteProvider).valueOrNull?.places ?? const <Place>[];
    final stays = ref.read(staysNearRouteProvider).valueOrNull?.stays ?? const <Stay>[];

    state = const AsyncLoading();
    final repo = ref.read(itineraryRepositoryProvider);
    state = await AsyncValue.guard(() {
      return repo.generate(
        trip: {
          'origin_label': form.originLabel!,
          'origin_lat': form.originLat!,
          'origin_lng': form.originLng!,
          'destination_label': form.destinationLabel!,
          'destination_lat': form.destinationLat!,
          'destination_lng': form.destinationLng!,
          'trip_type': form.tripType,
          'travellers': form.travellers,
          'budget_total': form.budgetTotal,
        },
        selectedPlaces: places.map((p) => p.toMap()).toList(),
        selectedStays: stays.map((s) => s.toMap()).toList(),
        budgetTotal: form.budgetTotal,
        maxDrivingHoursPerDay: maxDrivingHoursPerDay,
      );
    });
  }

  void reset() => state = const AsyncData(null);
}

final itineraryProvider = AsyncNotifierProvider<ItineraryNotifier, ItineraryPlan?>(
  ItineraryNotifier.new,
);