import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datasources/api_client.dart';
import 'base_repository.dart';
import '../../domain/entities/vehicle.dart';

class VehicleRepository extends BaseRepository {
  VehicleRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<List<Vehicle>> listVehicles() async {
    final res = await _apiClient.get('/vehicles');
    return parseList(res, Vehicle.fromJson);
  }

  Future<Vehicle> createVehicle({
    required String label,
    required String fuelType,
    double? mileageKmpl,
    double? evBatteryKwh,
    double? evEfficiencyKwhPerKm,
    double? cngMileageKmPerKg,
    bool isDefault = false,
  }) async {
    final res = await _apiClient.post(
      '/vehicles',
      body: {
        'label': label,
        'fuel_type': fuelType,
        if (mileageKmpl != null) 'mileage_kmpl': mileageKmpl,
        if (evBatteryKwh != null) 'ev_battery_kwh': evBatteryKwh,
        if (evEfficiencyKwhPerKm != null) 'ev_efficiency_kwh_per_km': evEfficiencyKwhPerKm,
        if (cngMileageKmPerKg != null) 'cng_mileage_km_per_kg': cngMileageKmPerKg,
        'is_default': isDefault,
      },
    );
    return parseObject(res, Vehicle.fromJson);
  }

  Future<Vehicle> updateVehicle(Vehicle vehicle) async {
    final res = await _apiClient.patch(
      '/vehicles',
      body: {
        'vehicle_id': vehicle.id,
        'label': vehicle.label,
        'fuel_type': vehicle.fuelType,
        if (vehicle.mileageKmpl != null) 'mileage_kmpl': vehicle.mileageKmpl,
        if (vehicle.evBatteryKwh != null) 'ev_battery_kwh': vehicle.evBatteryKwh,
        if (vehicle.evEfficiencyKwhPerKm != null)
          'ev_efficiency_kwh_per_km': vehicle.evEfficiencyKwhPerKm,
        if (vehicle.cngMileageKmPerKg != null)
          'cng_mileage_km_per_kg': vehicle.cngMileageKmPerKg,
        'is_default': vehicle.isDefault,
      },
    );
    return parseObject(res, Vehicle.fromJson);
  }

  Future<void> deleteVehicle(String vehicleId) async {
    await _apiClient.delete('/vehicles', queryParameters: {'vehicle_id': vehicleId});
  }

  Future<void> setDefaultVehicle(String vehicleId) async {
    await _apiClient.patch('/vehicles', body: {'vehicle_id': vehicleId, 'is_default': true});
  }
}

final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  return VehicleRepository(ref.watch(apiClientProvider));
});