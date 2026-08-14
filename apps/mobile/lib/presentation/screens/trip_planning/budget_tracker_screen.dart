import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../data/repositories/trip_repository.dart';
import '../../providers/trip_planning_provider.dart';
import '../../providers/itinerary_provider.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/sharing_widgets.dart';

class BudgetTrackerScreen extends ConsumerWidget {
  const BudgetTrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calcState = ref.watch(tripCalculationProvider);
    final selection = ref.watch(tripSelectionProvider);
    final itinerary = ref.watch(itineraryProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Budget Tracker')),
      body: SafeArea(
        child: calcState.when(
          loading: () => const AppLoadingState(),
          error: (err, st) => AppErrorState(error: err),
          data: (result) {
            final budget = result?.budgetStatus;
            if (budget == null) {
              return const AppEmptyState(
                message: 'Add a budget on the Plan Trip screen to see your budget meter.',
                icon: Icons.savings_outlined,
              );
            }

            final stayCost = selection.stayEstimatedCost;
            final foodCost = itinerary != null
                ? itinerary.days.fold<double>(
                    0,
                    (sum, d) => sum +
                        d.items
                            .where((i) => i.itemType == 'restaurant')
                            .fold<double>(0, (s, i) => s + i.estCost),
                  )
                : 0.0;
            const miscCost = 0.0;

            final full = ref.read(tripRepositoryProvider).aggregateBudget(
                  base: budget,
                  stayCost: stayCost,
                  foodCost: foodCost,
                  miscCost: miscCost,
                );

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                BudgetMeter(
                  status: full.status,
                  usedPct: full.usedPct,
                  remaining: full.remaining,
                ),
                const SizedBox(height: AppSpacing.lg),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Breakdown', style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: AppSpacing.md),
                        _row(context, 'Total budget', full.budgetTotal),
                        _row(context, 'Transport', budget.totalEstimated,
                            note: budget.totalEstimated == 0
                                ? 'No transport cost data'
                                : null),
                        _row(context, 'Accommodation', stayCost,
                            note: stayCost == 0
                                ? 'Select stays to include them'
                                : null),
                        _row(context, 'Food', foodCost,
                            note: foodCost == 0
                                ? 'Generates with your itinerary'
                                : null),
                        _row(context, 'Misc', miscCost),
                        const Divider(height: AppSpacing.xl),
                        _row(context, 'Estimated total', full.totalEstimated),
                        _row(context, 'Used', full.usedPct, isPercent: true),
                      ],
                    ),
                  ),
                ),
                if (full.usedPct < 90 && (stayCost == 0 || foodCost == 0)) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const HintText(
                    'Accommodation and food become part of this meter once you select stays and generate an itinerary. Recorded expenses always override estimates.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton(
                    onPressed: () => context.push(AppRoutes.stays),
                    child: const Text('Find stays'),
                  ),
                ],
                if (full.suggestions.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text('Ways to bring this trip back under budget',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.sm),
                  ...full.suggestions.map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lightbulb_outline, size: 18, color: AppColors.accent),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: Text(s, style: Theme.of(context).textTheme.bodyLarge)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, double value,
      {bool isPercent = false, String? note}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                isPercent ? '${value.toStringAsFixed(0)}%' : formatCurrency(value),
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (note != null)
            Text(note, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.info)),
        ],
      ),
    );
  }
}