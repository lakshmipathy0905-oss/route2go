import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/vehicle_repository.dart';
import '../../domain/entities/vehicle.dart';
import 'auth_provider.dart';

final vehicleRepositoryWatchProvider = Provider<VehicleRepository>((ref) {
  return ref.watch(vehicleRepositoryProvider);
});

/// AsyncNotifier exposing the garage list with explicit refresh.
class VehicleListNotifier extends AsyncNotifier<List<Vehicle>> {
  @override
  Future<List<Vehicle>> build() async {
    await ref.watch(authStateProvider.future);
    if (ref.read(authStateProvider).valueOrNull == null) return const [];
    final repo = ref.watch(vehicleRepositoryProvider);
    return repo.listVehicles();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(vehicleRepositoryProvider).listVehicles());
  }

  Future<void> add(Vehicle vehicle) async {
    final repo = ref.read(vehicleRepositoryProvider);
    state = await AsyncValue.guard(() async {
      await repo.createVehicle(
        label: vehicle.label,
        fuelType: vehicle.fuelType,
        mileageKmpl: vehicle.mileageKmpl,
        evBatteryKwh: vehicle.evBatteryKwh,
        evEfficiencyKwhPerKm: vehicle.evEfficiencyKwhPerKm,
        cngMileageKmPerKg: vehicle.cngMileageKmPerKg,
        isDefault: vehicle.isDefault,
      );
      return repo.listVehicles();
    });
  }

  Future<void> updateVehicle(Vehicle vehicle) async {
    final repo = ref.read(vehicleRepositoryProvider);
    state = await AsyncValue.guard(() async {
      await repo.updateVehicle(vehicle);
      return repo.listVehicles();
    });
  }

  Future<void> remove(String vehicleId) async {
    final repo = ref.read(vehicleRepositoryProvider);
    state = await AsyncValue.guard(() async {
      await repo.deleteVehicle(vehicleId);
      return repo.listVehicles();
    });
  }

  Future<void> setDefault(String vehicleId) async {
    final repo = ref.read(vehicleRepositoryProvider);
    state = await AsyncValue.guard(() async {
      await repo.setDefaultVehicle(vehicleId);
      return repo.listVehicles();
    });
  }
}

final vehicleListProvider =
    AsyncNotifierProvider<VehicleListNotifier, List<Vehicle>>(
  VehicleListNotifier.new,
);

/// The default vehicle for pre-filling the Plan Trip form, or the first one.
final defaultVehicleProvider = Provider<Vehicle?>((ref) {
  final vehicles = ref.watch(vehicleListProvider).valueOrNull;
  if (vehicles == null || vehicles.isEmpty) return null;
  for (final v in vehicles) {
    if (v.isDefault) return v;
  }
  return vehicles.first;
});
