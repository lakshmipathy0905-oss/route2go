import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../providers/live_trip_provider.dart';
import '../../providers/trip_planning_provider.dart';
import '../../providers/itinerary_provider.dart';
import '../../widgets/sharing_widgets.dart';

class LiveTripScreen extends ConsumerWidget {
  const LiveTripScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(liveTripProvider);
    final budget = ref.watch(tripPlanningFormProvider).budgetTotal;
    final itinerary = ref.watch(itineraryProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Trip'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'End trip',
            onPressed: () {
              ref.read(liveTripProvider.notifier).end();
              context.go(AppRoutes.home);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: live == null
            ? const Center(child: Text('No active trip. Start one from your plan.'))
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  if (live.deviationDetected)
                    _DeviationBanner(
                      onRecalculate: () => ref.read(liveTripProvider.notifier).recalculate(),
                      onIgnore: () => ref.read(liveTripProvider.notifier).ignoreDeviation(),
                    ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('On the way', style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: AppSpacing.md),
                          _row(context, 'From', live.originLabel),
                          _row(context, 'To', live.destinationLabel),
                          _row(context, 'ETA (recommended route)', formatDuration(live.route.durationMin)),
                          _row(context, 'Distance', formatDistance(live.route.distanceKm)),
                          if (budget != null)
                            _row(
                              context,
                              'Remaining budget',
                              formatCurrency(live.route.totalCost <= budget ? budget - live.route.totalCost : 0),
                            ),
                          _row(context, 'Route cost', formatCurrency(live.route.totalCost)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Next stops', style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: AppSpacing.sm),
                          if (itinerary != null && itinerary.days.isNotEmpty)
                            ...itinerary.days.first.items
                                .where((i) => i.itemType == 'place' || i.itemType == 'hotel')
                                .take(3)
                                .map(
                                  (i) => Padding(
padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                                    child: Row(
                                      children: [
                                        Icon(
                                          i.itemType == 'hotel' ? Icons.hotel_outlined : Icons.place_outlined,
                                          size: 18,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: AppSpacing.sm),
                                        Expanded(
                                          child: Text(i.name ?? i.itemType, style: Theme.of(context).textTheme.bodyLarge),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                          else
                            const HintText('Your itinerary appears here once you generate it.'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final result = await ref.read(liveTripProvider.notifier).handoffToNavigation();
                      if (result.ok == false && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(result.error ?? 'Could not start navigation.')),
                        );
                      }
                    },
                    icon: const Icon(Icons.navigation_outlined),
                    label: Text(live.handedOff ? 'Open navigation again' : 'Open navigation'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton(
                    onPressed: () async {
                      await ref.read(liveTripProvider.notifier).recalculate();
                    },
                    child: const Text('Recalculate route'),
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
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviationBanner extends StatelessWidget {
  const _DeviationBanner({required this.onRecalculate, required this.onIgnore});

  final VoidCallback onRecalculate;
  final VoidCallback onIgnore;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_outlined, color: AppColors.warning),
              const SizedBox(width: AppSpacing.sm),
              Text('Looks like you left your route', style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const HintText('Recalculate the route for your new position?'),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton(onPressed: onRecalculate, child: const Text('Recalculate route?')),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: OutlinedButton(onPressed: onIgnore, child: const Text('Keep going')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}