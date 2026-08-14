import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../providers/places_provider.dart';
import '../../providers/trip_planning_provider.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/sharing_widgets.dart';
import '../../../domain/entities/place.dart';

class PlacesScreen extends ConsumerStatefulWidget {
  const PlacesScreen({super.key});

  @override
  ConsumerState<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends ConsumerState<PlacesScreen> {
  final Set<String> _selectedCategoryIds = {};
  double _detourRadiusKm = 30;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Places Along Route')),
      body: SafeArea(
        child: Consumer(builder: (context, ref, _) {
          final state = ref.watch(placesNearRouteProvider);
          final trip = ref.watch(tripSelectionProvider);

          return state.when(
            loading: () => const AppLoadingState(message: 'Finding places near your route…'),
            error: (err, st) => AppErrorState(
              error: err,
              onRetry: () => ref.read(placesNearRouteProvider.notifier).load(force: true),
            ),
            data: (placesNear) {
              var places = placesNear.places;
              if (_selectedCategoryIds.isNotEmpty) {
                places = places
                    .where((p) => p.categoryId != null && _selectedCategoryIds.contains(p.categoryId))
                    .toList();
              }
              if (placesNear.places.isEmpty) {
                return Column(
                  children: [
                    const Expanded(
                      child: AppEmptyState(
                        message: 'No places found near this route in your data yet.',
                        icon: Icons.place_outlined,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: FilledButton.icon(
                        icon: const Icon(Icons.refresh),
                        onPressed: () => ref.read(placesNearRouteProvider.notifier).load(force: true),
                        label: const Text('Search again'),
                      ),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  if (placesNear.categories.isNotEmpty)
                    SizedBox(
                      height: 52,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        children: [
                          TagChip(
                            label: 'All',
                            selected: _selectedCategoryIds.isEmpty,
                            onTap: () => setState(() => _selectedCategoryIds.clear()),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          ...placesNear.categories.map(
                            (c) => Padding(
                              padding: const EdgeInsets.only(right: AppSpacing.sm),
                              child: TagChip(
                                label: c.name,
                                selected: _selectedCategoryIds.contains(c.id),
                                onTap: () => setState(() {
                                  if (!_selectedCategoryIds.add(c.id)) {
                                    _selectedCategoryIds.remove(c.id);
                                  }
                                }),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                    child: Row(
                      children: [
                        HintText('Detour radius: ${_detourRadiusKm.toStringAsFixed(0)} km'),
                        const Spacer(),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.tune, size: 20),
                          tooltip: 'Detour radius',
                          onSelected: (v) => setState(() => _detourRadiusKm = double.parse(v)),
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: '10', child: Text('10 km')),
                            PopupMenuItem(value: '30', child: Text('30 km')),
                            PopupMenuItem(value: '50', child: Text('50 km')),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      itemCount: places.length,
                      itemBuilder: (context, i) {
                        final p = places[i];
                        final added = trip.containsPlace(p);
                        return _PlaceCard(
                          place: p,
                          addedToTrip: added,
                          onToggleAdd: () => _toggleAdd(p),
                          onOpen: () => context.push(AppRoutes.placeDetailOf(p.id)),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        }),
      ),
    );
  }

  void _toggleAdd(Place p) {
    final notifier = ref.read(tripSelectionProvider.notifier);
    final current = ref.read(tripSelectionProvider);
    notifier.state = current.containsPlace(p) ? current.removePlace(p.id) : current.addPlace(p);
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.place,
    required this.addedToTrip,
    required this.onToggleAdd,
    required this.onOpen,
  });

  final Place place;
  final bool addedToTrip;
  final VoidCallback onToggleAdd;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      elevation: addedToTrip ? 4 : 0,
      shadowColor: AppColors.primary.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: addedToTrip
            ? const BorderSide(color: AppColors.primary, width: 1.5)
            : BorderSide(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(place.name, style: Theme.of(context).textTheme.headlineSmall),
                  ),
                  if (addedToTrip) ...[
                    const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  if (place.rating != null)
                    StarRating(rating: place.rating, size: 12),
                ],
              ),
              if (place.category != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(place.category!, style: Theme.of(context).textTheme.bodySmall),
              ],
              if (place.detourKm != null) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Detour adds ${formatDistance(place.detourKm!)}'
                    '${place.detourDurationMin != null ? ' · ${formatDuration(place.detourDurationMin!)}' : ''}'
                    '${place.detourAddedCost != null ? ' · ${formatCurrency(place.detourAddedCost!)}' : ''}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.info, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: onToggleAdd,
                    icon: Icon(addedToTrip ? Icons.check : Icons.add),
                    label: Text(addedToTrip ? 'Added to Trip' : 'Add to Trip'),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Details',
                    onPressed: onOpen,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}