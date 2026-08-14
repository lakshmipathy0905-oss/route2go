import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datasources/api_client.dart';
import 'base_repository.dart';
import '../../domain/entities/itinerary.dart';

class ItineraryRepository extends BaseRepository {
  ItineraryRepository(this._apiClient);
  final ApiClient _apiClient;

  /// Generates a day-by-day itinerary bounded by `maxDrivingHoursPerDay`
  /// (the safety cap — spec Section 18). Rejects inputs server-side when
  /// the trip cannot be scheduled (same origin/destination, zero budget,
  /// no places, no stays).
  Future<ItineraryPlan> generate({
    required Map<String, dynamic> trip,
    required List<Map<String, dynamic>> selectedPlaces,
    required List<Map<String, dynamic>> selectedStays,
    double? budgetTotal,
    double maxDrivingHoursPerDay = 8,
  }) async {
    final res = await _apiClient.post(
      '/itinerary-generate',
      body: {
        'trip': trip,
        'selected_places': selectedPlaces,
        'selected_stays': selectedStays,
        if (budgetTotal != null) 'budget_total': budgetTotal,
        'max_driving_hours_per_day': maxDrivingHoursPerDay,
      },
    );
    return ItineraryPlan.fromJson(res['data'] as Map<String, dynamic>);
  }
}

final itineraryRepositoryProvider = Provider<ItineraryRepository>((ref) {
  return ItineraryRepository(ref.watch(apiClientProvider));
});
