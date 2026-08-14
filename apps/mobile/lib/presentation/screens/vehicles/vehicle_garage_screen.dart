import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/guest_gate.dart';
import '../../../domain/entities/vehicle.dart';

class VehicleGarageScreen extends ConsumerWidget {
  const VehicleGarageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(isLoggedInProvider);

    if (!isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Vehicles')),
        body: SafeArea(
          child: Column(
            children: [
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.directions_car_outlined, size: 44, color: AppColors.textSecondary),
                      SizedBox(height: AppSpacing.md),
                      Text(
                        'Save your vehicles to pre-fill mileage and fuel type when planning.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: ElevatedButton(
                  onPressed: () => showGuestGate(context),
                  child: const Text('Sign in to save vehicles'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final vehicles = ref.watch(vehicleListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Vehicles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add vehicle',
            onPressed: () => context.push(AppRoutes.vehicleAdd),
          ),
        ],
      ),
      body: SafeArea(
        child: vehicles.when(
          loading: () => const AppLoadingState(message: 'Loading your vehicles…'),
          error: (err, st) => AppErrorState(
            error: err,
            onRetry: () => ref.read(vehicleListProvider.notifier).refresh(),
          ),
          data: (list) {
            if (list.isEmpty) {
              return _VehicleEmptyState(
                onAdd: () => context.push(AppRoutes.vehicleAdd),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final v = list[i];
                return _VehicleCard(
                  vehicle: v,
                  onSetDefault: v.isDefault
                      ? null
                      : () => ref.read(vehicleListProvider.notifier).setDefault(v.id),
                  onEdit: () => context.push(AppRoutes.vehicleEditOf(v.id)),
                  onDelete: () => _confirmDelete(context, ref, v),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Vehicle v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete vehicle?'),
        content: Text('"${v.label}" will be removed from your garage. Trips already planned remain unchanged.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(vehicleListProvider.notifier).remove(v.id);
      if (context.mounted && ref.read(vehicleListProvider).hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete the vehicle. Please try again.')),
        );
      }
    }
  }
}

class _VehicleEmptyState extends StatelessWidget {
  const _VehicleEmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.directions_car_outlined, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.md),
            Text('Add your first vehicle', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Save fuel type and mileage once, and reuse it for every trip.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add a vehicle'),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.onSetDefault,
    required this.onEdit,
    required this.onDelete,
  });

  final Vehicle vehicle;
  final VoidCallback? onSetDefault;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final mileageText = switch (vehicle.fuelType) {
      'ev' => vehicle.evEfficiencyKwhPerKm != null
          ? '${vehicle.evEfficiencyKwhPerKm!.toStringAsFixed(2)} kWh/km'
          : 'Efficiency not set',
      'cng' => vehicle.cngMileageKmPerKg != null
          ? '${vehicle.cngMileageKmPerKg!.toStringAsFixed(1)} km/kg'
          : 'Mileage not set',
      _ => vehicle.mileageKmpl != null
          ? '${vehicle.mileageKmpl!.toStringAsFixed(1)} km/l'
          : 'Mileage not set',
    };

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  vehicle.fuelType == 'ev' ? Icons.electric_car : Icons.directions_car_outlined,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(vehicle.label, style: Theme.of(context).textTheme.headlineSmall),
                          ),
                          if (vehicle.isDefault) ...[
                            const SizedBox(width: AppSpacing.sm),
                            const Icon(Icons.star, size: 16, color: AppColors.warning),
                          ],
                        ],
                      ),
                      Text(
                        '${vehicle.fuelType.toUpperCase()} · $mileageText',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                if (!vehicle.isDefault && onSetDefault != null)
                  TextButton(onPressed: onSetDefault, child: const Text('Make default')),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit vehicle',
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  tooltip: 'Delete vehicle',
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}