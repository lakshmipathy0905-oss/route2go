import 'package:flutter_test/flutter_test.dart';
import 'package:route2go/domain/entities/vehicle.dart';

void main() {
  group('VehicleRanges', () {
    test('petrol mileage range is 5-30 km/l', () {
      expect(VehicleRanges.petrolMileage.contains(15), isTrue);
      expect(VehicleRanges.petrolMileage.contains(3), isFalse);
      expect(VehicleRanges.petrolMileage.contains(31), isFalse);
    });

    test('diesel mileage range is 7-35 km/l', () {
      expect(VehicleRanges.dieselMileage.contains(20), isTrue);
      expect(VehicleRanges.dieselMileage.contains(5), isFalse);
    });

    test('CNG mileage range is 8-40 km/kg', () {
      expect(VehicleRanges.cngMileage.contains(25), isTrue);
      expect(VehicleRanges.cngMileage.contains(45), isFalse);
    });

    test('EV efficiency range is 0.05-0.50 kWh/km', () {
      expect(VehicleRanges.evEfficiency.contains(0.15), isTrue);
      expect(VehicleRanges.evEfficiency.contains(0.9), isFalse);
    });

    test('rangeFor returns the right range per fuel type', () {
      expect(VehicleRanges.rangeFor('petrol'), VehicleRanges.petrolMileage);
      expect(VehicleRanges.rangeFor('diesel'), VehicleRanges.dieselMileage);
      expect(VehicleRanges.rangeFor('cng'), VehicleRanges.cngMileage);
      expect(VehicleRanges.rangeFor('ev'), isNull);
    });

    test('describe gives guidance text, never empty for known types', () {
      for (final f in ['petrol', 'diesel', 'cng', 'ev']) {
        expect(VehicleRanges.describe(f), isNotEmpty);
      }
    });
  });

  group('Vehicle', () {
    test('fromJson parses all fields', () {
      final v = Vehicle.fromJson({
        'id': 'v1',
        'label': 'My Swift',
        'fuel_type': 'petrol',
        'mileage_kmpl': 18.5,
        'is_default': true,
      });
      expect(v.id, 'v1');
      expect(v.label, 'My Swift');
      expect(v.fuelType, 'petrol');
      expect(v.mileageKmpl, 18.5);
      expect(v.isDefault, isTrue);
      expect(v.evBatteryKwh, isNull);
    });

    test('fromJson defaults missing fields safely', () {
      final v = Vehicle.fromJson({'id': 'v2', 'label': 'X', 'fuel_type': 'ev'});
      expect(v.mileageKmpl, isNull);
      expect(v.isDefault, isFalse);
    });

    test('copyWith overrides only supplied fields', () {
      final v =
          Vehicle.fromJson({'id': 'v1', 'label': 'A', 'fuel_type': 'petrol'});
      final v2 = v.copyWith(label: 'B');
      expect(v2.label, 'B');
      expect(v2.fuelType, 'petrol');
      expect(v2.id, 'v1');
    });
  });
}
