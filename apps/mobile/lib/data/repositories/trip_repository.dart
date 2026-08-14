import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datasources/api_client.dart';
import 'base_repository.dart';
import '../../domain/entities/route_option.dart';
import '../../domain/entities/trip_summary.dart';

class TripSummaryResult {
  const TripSummaryResult(this.savedTripId, this.maybeId);
  final String? savedTripId;
  final String? maybeId;
}

class TripRepository extends BaseRepository {
  TripRepository(this._apiClient);
  final ApiClient _apiClient;

  /// Calls POST /trip-calculate. Guest users are allowed (spec 5.2).
  Future<TripCalculationResult> calculateTrip({
    required Map<String, double> origin,
    required String originLabel,
    required Map<String, double> destination,
    required String destinationLabel,
    required String tripType,
    required String fuelType,
    double? mileageKmpl,
    double? fuelPricePerLitre,
    double? budgetTotal,
    String? tripId,
  }) async {
    final response = await _apiClient.post(
      '/trip-calculate',
      allowGuest: true,
      body: {
        'origin': {
          'label': originLabel,
          'lat': origin['lat'],
          'lng': origin['lng']
        },
        'destination': {
          'label': destinationLabel,
          'lat': destination['lat'],
          'lng': destination['lng']
        },
        'trip_type': tripType,
        'vehicle': {
          'fuel_type': fuelType,
          if (mileageKmpl != null) 'mileage_kmpl': mileageKmpl,
        },
        if (fuelPricePerLitre != null)
          'fuel_price_per_litre': fuelPricePerLitre,
        if (budgetTotal != null) 'budget_total': budgetTotal,
        if (tripId != null) 'trip_id': tripId,
      },
    );
    return TripCalculationResult.fromJson(response);
  }

  /// Explicidy saves a draft trip (spec 2.8). Authenticated only.
  Future<String> saveTrip({
    required String originLabel,
    required double originLat,
    required double originLng,
    required String destinationLabel,
    required double destLat,
    required double destLng,
    required String tripType,
    String? startDate,
    String? endDate,
    int travellers = 1,
    String? vehicleId,
    double? budgetTotal,
  }) async {
    final res = await _apiClient.post('/trip', body: {
      'action': 'save',
      'origin_label': originLabel,
      'origin_lat': originLat,
      'origin_lng': originLng,
      'destination_label': destinationLabel,
      'destination_lat': destLat,
      'destination_lng': destLng,
      'trip_type': tripType,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      'travellers': travellers,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (budgetTotal != null) 'budget_total': budgetTotal,
    });
    return res['data']?['trip_id'] as String? ?? '';
  }

  Future<List<TripSummary>> listTrips() async {
    final res = await _apiClient.get('/trip');
    return parseList(res, TripSummary.fromJson);
  }

  Future<TripSummary> renameTrip(
      {required String tripId, required String newLabel}) async {
    final res = await _apiClient.patch('/trip', body: {
      'action': 'rename',
      'trip_id': tripId,
      'origin_label': newLabel,
    });
    return parseObject(res, TripSummary.fromJson);
  }

  Future<TripSummary> duplicateTrip({required String tripId}) async {
    final res = await _apiClient.patch('/trip', body: {
      'action': 'duplicate',
      'trip_id': tripId,
    });
    return parseObject(res, TripSummary.fromJson);
  }

  Future<void> deleteTrip(String tripId) async {
    await _apiClient.delete('/trip', queryParameters: {'trip_id': tripId});
  }

  /// Aggregates a live GREEN/YELLOW/RED meter across transport + stay + food
  /// + misc (spec 2.7) given the base calculation and selected stays/places.
  BudgetStatus aggregateBudget({
    required BudgetStatus base,
    required double stayCost,
    required double foodCost,
    required double miscCost,
  }) {
    final transport = base.usedPct > 0
        ? base.budgetTotal * (base.usedPct / 100)
        : base.totalEstimated;
    final total = transport + stayCost + foodCost + miscCost;
    final budgetTotal = base.budgetTotal;
    final usedPct = budgetTotal > 0 ? total / budgetTotal : 1.0;

    String status;
    if (usedPct < 0.8) {
      status = 'GREEN';
    } else if (usedPct <= 1.0) {
      status = 'YELLOW';
    } else {
      status = 'RED';
    }

    return BudgetStatus(
      status: status,
      totalEstimated: total,
      budgetTotal: budgetTotal,
      usedPct: usedPct * 100,
      remaining: budgetTotal - total,
      suggestions: status == 'RED'
          ? base.suggestions.isNotEmpty
              ? base.suggestions
              : const [
                  'Switch to a cheaper accommodation tier',
                  'Remove the lowest-priority attraction',
                  'Switch to the no-toll or cheaper route',
                ]
          : const [],
    );
  }
}

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return TripRepository(ref.watch(apiClientProvider));
});
