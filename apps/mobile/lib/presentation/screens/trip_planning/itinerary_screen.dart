import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../providers/itinerary_provider.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/sharing_widgets.dart';
import '../../../domain/entities/itinerary.dart';

class ItineraryScreen extends ConsumerStatefulWidget {
  const ItineraryScreen({super.key});

  @override
  ConsumerState<ItineraryScreen> createState() => _ItineraryScreenState();
}

IconData _iconFor(String itemType) {
  return switch (itemType) {
    'place' => Icons.place_outlined,
    'hotel' => Icons.hotel_outlined,
    'restaurant' => Icons.restaurant_outlined,
    'drive' => Icons.route_outlined,
    _ => Icons.check_circle_outline,
  };
}

class _ItineraryScreenState extends ConsumerState<ItineraryScreen> {
  int _activeDay = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(itineraryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Itinerary')),
      body: SafeArea(
        child: state.when(
          loading: () => const AppLoadingState(message: 'Scheduling your trip…'),
          error: (err, st) => AppErrorState(
            error: err,
            onRetry: () => ref.read(itineraryProvider.notifier).generate(),
          ),
          data: (plan) {
            if (plan == null || plan.days.isEmpty) {
              return Column(
                children: [
                  const Expanded(
                    child: AppEmptyState(
                      message: 'Select places and stays first, then generate your itinerary.',
                      icon: Icons.calendar_month_outlined,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => context.push(AppRoutes.places),
                            child: const Text('Add places'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => context.push(AppRoutes.stays),
                            child: const Text('Add stays'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            final dayIndex = _activeDay.clamp(0, plan.days.length - 1);
            final day = plan.days[dayIndex];
            return Column(
              children: [
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    children: List.generate(plan.days.length, (i) {
                      return Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: ChoiceChip(
                          label: Text('Day ${i + 1}'),
                          selected: i == dayIndex,
                          onSelected: (_) => setState(() => _activeDay = i),
                        ),
                      );
                    }),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                  child: Row(
                    children: [
                      HintText('Driving capped at ${ref.read(itineraryProvider.notifier).maxDrivingHoursPerDay.toStringAsFixed(0)} hrs/day.'),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () async {
                          await ref.read(itineraryProvider.notifier).generate();
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Regenerate'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    buildDefaultDragHandles: true,
                    itemCount: day.items.length,
                    onReorderItem: (oldIndex, newIndex) {
                      setState(() {
                        final items = List<ItineraryItem>.of(day.items);
                        final moved = items.removeAt(oldIndex);
                        items.insert(newIndex, moved);
                      });
                    },
                    itemBuilder: (context, i) {
                      final item = day.items[i];
                      return Card(
                        key: ValueKey('${day.dayNumber}-$i-${item.itemType}-${item.name ?? item.refId ?? i}'),
                        margin: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: ListTile(
                          leading: Icon(_iconFor(item.itemType), color: AppColors.primary),
                          title: Text(item.name ?? item.itemType, style: Theme.of(context).textTheme.bodyLarge),
                          subtitle: Row(
                            children: [
                              if (item.startTime != null)
                                Text(
                                  '${item.startTime!.hour.toString().padLeft(2, '0')}:${item.startTime!.minute.toString().padLeft(2, '0')}  ·  ',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              Flexible(
                                child: Text(
                                  item.itemType,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              if (item.estCost > 0)
                                Text('  ·  ${formatCurrency(item.estCost)}', style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                          trailing: ReorderableDragStartListener(
                            index: i,
                            child: const Icon(Icons.drag_handle, color: AppColors.textSecondary),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: ElevatedButton(
                    onPressed: () => context.push(AppRoutes.confirmTrip),
                    child: const Text('Confirm Trip'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}