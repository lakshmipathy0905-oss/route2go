import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../data/repositories/trip_repository.dart';
import '../../domain/entities/route_option.dart';
import '../../domain/entities/place.dart';
import '../../domain/entities/stay.dart';

/// Everything the user has selected for the trip beyond the route itself:
/// places to visit, stays, and food stops. Drives the itinerary generator,
/// the full-trip Budget meter (spec 2.7), and trip confirm/save.
class TripSelection {
  const TripSelection({
    this.places = const [],
    this.stays = const [],
    this.foodStops = const [],
  });

  final List<Place> places;
  final List<Stay> stays;
  final List<Map<String, dynamic>> foodStops;

  /// Estimated live cost of the selected stays for the chosen duration —
  /// surfaced in the budget meter, never fabricated.
  double get stayEstimatedCost =>
      stays.fold(0, (sum, s) => sum + (s.pricePerNight ?? 0));

  bool get hasSelection => places.isNotEmpty || stays.isNotEmpty || foodStops.isNotEmpty;

  TripSelection addPlace(Place p) =>
      containsPlace(p) ? this : TripSelection(places: [...places, p], stays: stays, foodStops: foodStops);

  TripSelection removePlace(String id) => TripSelection(
        places: places.where((p) => p.id != id).toList(),
        stays: stays,
        foodStops: foodStops,
      );

  TripSelection addStay(Stay s) =>
      containsStay(s) ? this : TripSelection(places: places, stays: [...stays, s], foodStops: foodStops);

  TripSelection removeStay(String id) => TripSelection(
        places: places,
        stays: stays.where((s) => s.id != id).toList(),
        foodStops: foodStops,
      );

  bool containsPlace(Place p) => places.any((e) => e.id == p.id);
  bool containsStay(Stay s) => stays.any((e) => e.id == s.id);
}

final tripSelectionProvider = StateProvider<TripSelection>((ref) => const TripSelection());

/// Everything the user has entered in the Plan Trip flow (spec Section 5.5).
/// This is intentionally a separate, persistent form-state object from the
/// calculation result: if calculation fails, the form data must be preserved
/// (per the ERROR UX requirement — "every failure preserves entered data").
class TripPlanningForm {
  const TripPlanningForm({
    this.originLabel,
    this.originLat,
    this.originLng,
    this.destinationLabel,
    this.destinationLat,
    this.destinationLng,
    this.tripType = 'one_way',
    this.travellers = 1,
    this.fuelType = 'petrol',
    this.mileageKmpl,
    this.fuelPricePerLitre,
    this.budgetTotal,
    this.interests = const [],
  });

  final String? originLabel;
  final double? originLat;
  final double? originLng;
  final String? destinationLabel;
  final double? destinationLat;
  final double? destinationLng;
  final String tripType;
  final int travellers;
  final String fuelType;
  final double? mileageKmpl;
  final double? fuelPricePerLitre;
  final double? budgetTotal;
  final List<String> interests;

  bool get isReadyToCalculate =>
      originLabel != null &&
      originLat != null &&
      originLng != null &&
      destinationLabel != null &&
      destinationLat != null &&
      destinationLng != null &&
      (originLat != destinationLat || originLng != destinationLng);

  TripPlanningForm copyWith({
    String? originLabel,
    double? originLat,
    double? originLng,
    String? destinationLabel,
    double? destinationLat,
    double? destinationLng,
    String? tripType,
    int? travellers,
    String? fuelType,
    double? mileageKmpl,
    double? fuelPricePerLitre,
    double? budgetTotal,
    List<String>? interests,
  }) {
    return TripPlanningForm(
      originLabel: originLabel ?? this.originLabel,
      originLat: originLat ?? this.originLat,
      originLng: originLng ?? this.originLng,
      destinationLabel: destinationLabel ?? this.destinationLabel,
      destinationLat: destinationLat ?? this.destinationLat,
      destinationLng: destinationLng ?? this.destinationLng,
      tripType: tripType ?? this.tripType,
      travellers: travellers ?? this.travellers,
      fuelType: fuelType ?? this.fuelType,
      mileageKmpl: mileageKmpl ?? this.mileageKmpl,
      fuelPricePerLitre: fuelPricePerLitre ?? this.fuelPricePerLitre,
      budgetTotal: budgetTotal ?? this.budgetTotal,
      interests: interests ?? this.interests,
    );
  }
}

final tripPlanningFormProvider =
    StateProvider<TripPlanningForm>((ref) => const TripPlanningForm());

/// AsyncValue-driven calculation state: loading/error/data are all handled
/// natively by AsyncValue, so every consuming screen gets consistent
/// loading/error/success/empty behavior for free via `.when(...)`.
class TripCalculationNotifier extends AsyncNotifier<TripCalculationResult?> {
  @override
  Future<TripCalculationResult?> build() async => null;

  Future<void> calculate() async {
    final form = ref.read(tripPlanningFormProvider);
    if (!form.isReadyToCalculate) {
      state = AsyncError(
        const AppException(
          code: 'INCOMPLETE_FORM',
          message: 'Please choose a starting point and destination first.',
          retryable: false,
        ),
        StackTrace.current,
      );
      return;
    }

    state = const AsyncLoading();
    final repo = ref.read(tripRepositoryProvider);

    state = await AsyncValue.guard(() {
      return repo.calculateTrip(
        origin: {'lat': form.originLat!, 'lng': form.originLng!},
        originLabel: form.originLabel!,
        destination: {'lat': form.destinationLat!, 'lng': form.destinationLng!},
        destinationLabel: form.destinationLabel!,
        tripType: form.tripType,
        fuelType: form.fuelType,
        mileageKmpl: form.mileageKmpl,
        fuelPricePerLitre: form.fuelPricePerLitre,
        budgetTotal: form.budgetTotal,
      );
    });
  }

  void reset() => state = const AsyncData(null);
}

final tripCalculationProvider =
    AsyncNotifierProvider<TripCalculationNotifier, TripCalculationResult?>(
  TripCalculationNotifier.new,
);
