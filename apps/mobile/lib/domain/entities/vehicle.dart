/// A saved vehicle in the user's garage (spec Section 5.4 / Screen 12).
class Vehicle {
  const Vehicle({
    required this.id,
    required this.label,
    required this.fuelType,
    this.mileageKmpl,
    this.evBatteryKwh,
    this.evEfficiencyKwhPerKm,
    this.cngMileageKmPerKg,
    this.isDefault = false,
  });

  final String id;
  final String label;
  final String fuelType; // petrol | diesel | ev | cng
  final double? mileageKmpl;
  final double? evBatteryKwh;
  final double? evEfficiencyKwhPerKm;
  final double? cngMileageKmPerKg;
  final bool isDefault;

  Vehicle copyWith({
    String? label,
    String? fuelType,
    double? mileageKmpl,
    double? evBatteryKwh,
    double? evEfficiencyKwhPerKm,
    double? cngMileageKmPerKg,
    bool? isDefault,
  }) {
    return Vehicle(
      id: id,
      label: label ?? this.label,
      fuelType: fuelType ?? this.fuelType,
      mileageKmpl: mileageKmpl ?? this.mileageKmpl,
      evBatteryKwh: evBatteryKwh ?? this.evBatteryKwh,
      evEfficiencyKwhPerKm: evEfficiencyKwhPerKm ?? this.evEfficiencyKwhPerKm,
      cngMileageKmPerKg: cngMileageKmPerKg ?? this.cngMileageKmPerKg,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] as String,
      label: json['label'] as String,
      fuelType: json['fuel_type'] as String,
      mileageKmpl: (json['mileage_kmpl'] as num?)?.toDouble(),
      evBatteryKwh: (json['ev_battery_kwh'] as num?)?.toDouble(),
      evEfficiencyKwhPerKm:
          (json['ev_efficiency_kwh_per_km'] as num?)?.toDouble(),
      cngMileageKmPerKg: (json['cng_mileage_km_per_kg'] as num?)?.toDouble(),
      isDefault: json['is_default'] as bool? ?? false,
    );
  }
}

/// Realistic mileage/efficiency ranges per fuel type. Values outside these
/// ranges are rejected with guidance — never silently clamped (spec: "reject
/// unrealistic values with an inline explanation").
class VehicleRanges {
  VehicleRanges._();

  static const petrolMileage = Range(5.0, 30.0); // km/l
  static const dieselMileage = Range(7.0, 35.0); // km/l
  static const cngMileage = Range(8.0, 40.0); // km/kg
  static const evEfficiency = Range(0.05, 0.5); // kWh/km
  static const evBattery = Range(5.0, 150.0); // kWh

  static Range? rangeFor(String fuelType) {
    switch (fuelType) {
      case 'petrol':
        return petrolMileage;
      case 'diesel':
        return dieselMileage;
      case 'cng':
        return cngMileage;
      default:
        return null;
    }
  }

  static String unitFor(String fuelType) {
    switch (fuelType) {
      case 'cng':
        return 'km/kg';
      case 'ev':
        return 'kWh/km';
      default:
        return 'km/l';
    }
  }

  static String describe(String fuelType) {
    switch (fuelType) {
      case 'petrol':
        return 'Petrol mileage is usually 5–30 km/l.';
      case 'diesel':
        return 'Diesel mileage is usually 7–35 km/l.';
      case 'cng':
        return 'CNG mileage is usually 8–40 km/kg.';
      case 'ev':
        return 'EV efficiency is usually 0.05–0.50 kWh/km.';
      default:
        return '';
    }
  }
}

class Range {
  const Range(this.min, this.max);
  final double min;
  final double max;

  bool contains(double value) => value >= min && value <= max;
}
