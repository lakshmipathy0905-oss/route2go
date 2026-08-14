import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../data/repositories/geocoding_repository.dart';
import '../../../data/repositories/trip_repository.dart';
import '../../providers/trip_planning_provider.dart';
import '../../providers/itinerary_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/live_trip_provider.dart';
import '../../widgets/sharing_widgets.dart';
import '../../widgets/permission_explainer.dart';
import '../../widgets/guest_gate.dart';

class ConfirmTripScreen extends ConsumerWidget {
  const ConfirmTripScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(tripPlanningFormProvider);
    final calc = ref.watch(tripCalculationProvider).valueOrNull;
    final selection = ref.watch(tripSelectionProvider);
    final itinerary = ref.watch(itineraryProvider).valueOrNull;
    final selectedType = ref.watch(selectedRouteTypeProvider);

    final route = calc == null ? null : selectRoute(calc, selectedType);

    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Your Trip')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Trip summary',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: AppSpacing.md),
                    _row(context, 'Route',
                        '${form.originLabel} → ${form.destinationLabel}'),
                    if (route != null) ...[
                      _row(context, 'Distance',
                          formatDistance(route.distanceKm)),
                      _row(context, 'Time', formatDuration(route.durationMin)),
                      _row(context, 'Est. cost',
                          formatCurrency(route.totalCost)),
                    ],
                    _row(context, 'Places selected',
                        '${selection.places.length}'),
                    _row(
                        context, 'Stays selected', '${selection.stays.length}'),
                    if (itinerary != null)
                      _row(context, 'Itinerary days',
                          '${itinerary.days.length}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: () => _confirmAndStart(context, ref),
              child: const Text('Start Live Trip'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () => _saveTrip(context, ref),
              child: const Text('Save trip only'),
            ),
            const SizedBox(height: AppSpacing.md),
            const HintText(
              'Starting a live trip asks for background location so we can warn you if you drive off your planned route. You can end it any time.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndStart(BuildContext context, WidgetRef ref) async {
    final isLoggedIn = ref.read(isLoggedInProvider);
    if (!isLoggedIn) {
      showGuestGate(context);
      return;
    }

    // Persist the confirmed trip before entering live mode (2.9).
    await _saveTrip(context, ref, navigateToLive: false);
    if (!context.mounted) return;

    // Permission Explainer BEFORE the OS prompt (Section 3.3). Background
    // location is requested ONLY here, when the user enters Live Trip mode.
    await PermissionExplainer(
      icon: Icons.navigation_outlined,
      title: 'Background location for live trips',
      reasons: const [
        'Warn you if the car drifts off your planned route while navigation is running.',
        'Background location is only active while a live trip is running.',
        'It is never shared, sold, or linked to ads.',
      ],
      permissionLabel: 'Allow location',
      onRequest: () => Navigator.of(context).pop(),
    ).showModal(context);
    if (!context.mounted) return;

    final perm = await ref
        .read(geocodingRepositoryProvider)
        .requestLocationPermission(background: true);

    if (context.mounted) {
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Live-trip deviation warnings need location. You can still navigate; enable location later in Settings.',
            ),
          ),
        );
      } else if (!kIsWeb &&
          Platform.isAndroid &&
          perm == LocationPermission.whileInUse) {
        final open = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Enable background location?'),
            content: const Text(
              'To warn you if you leave your planned route while navigation runs in another app, allow "All the time" location access for Route2Go. It is only used while a live trip is active.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('In-use only'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Open settings'),
              ),
            ],
          ),
        );
        if (open == true && context.mounted) {
          await Geolocator.openAppSettings();
        }
      }
    }

    await ref.read(liveTripProvider.notifier).start();

    if (context.mounted) context.push(AppRoutes.liveTrip);
  }

  Future<void> _saveTrip(
    BuildContext context,
    WidgetRef ref, {
    bool navigateToLive = true,
  }) async {
    final isLoggedIn = ref.read(isLoggedInProvider);
    if (!isLoggedIn) {
      showGuestGate(context);
      return;
    }
    final form = ref.read(tripPlanningFormProvider);
    final repo = ref.read(tripRepositoryProvider);
    try {
      await repo.saveTrip(
        originLabel: form.originLabel!,
        originLat: form.originLat!,
        originLng: form.originLng!,
        destinationLabel: form.destinationLabel!,
        destLat: form.destinationLat!,
        destLng: form.destinationLng!,
        tripType: form.tripType,
        travellers: form.travellers,
        budgetTotal: form.budgetTotal,
      );
      if (context.mounted && !navigateToLive) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip saved.')),
        );
      }
    } catch (_) {
      if (context.mounted && !navigateToLive) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not save the trip. Please try again.')),
        );
      }
    }
  }
}
