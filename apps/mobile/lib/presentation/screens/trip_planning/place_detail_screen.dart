import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/places_provider.dart';
import '../../providers/trip_planning_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/sharing_widgets.dart';
import '../../widgets/guest_gate.dart';
import '../../../data/repositories/favorites_repository.dart';
import '../../../domain/entities/place.dart';

class PlaceDetailScreen extends ConsumerWidget {
  const PlaceDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(placesNearRouteProvider);
    final trip = ref.watch(tripSelectionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Place details')),
      body: SafeArea(
        child: state.when(
          loading: () => const AppLoadingState(),
          error: (err, st) => AppErrorState(
            error: err,
            onRetry: () => ref.read(placesNearRouteProvider.notifier).load(force: true),
          ),
          data: (near) {
            Place? place;
            for (final p in near.places) {
              if (p.id == id) {
                place = p;
                break;
              }
            }
            if (place == null) {
              return const AppEmptyState(
                message: 'This place is no longer available for this route.',
                icon: Icons.place_outlined,
              );
            }
            final selected = place;

            final added = trip.containsPlace(selected);
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                if (selected.photos.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    child: Container(
                      height: 180,
                      width: double.infinity,
                      color: AppColors.primary.withValues(alpha: 0.1),
                      alignment: Alignment.center,
                      child: Icon(Icons.photo_outlined, size: 44, color: AppColors.primary.withValues(alpha: 0.5)),
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                Text(selected.name, style: Theme.of(context).textTheme.headlineLarge),
                if (selected.category != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(selected.category!, style: Theme.of(context).textTheme.bodySmall),
                ],
                const SizedBox(height: AppSpacing.md),
                if (selected.rating != null) StarRating(rating: selected.rating),
                if (selected.hours != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _Row(icon: Icons.schedule, text: 'Hours: ${selected.hours}'),
                ],
                if (selected.entryFee != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _Row(icon: Icons.payments_outlined, text: 'Entry fee: ${formatCurrency(selected.entryFee!)}'),
                ],
                if (selected.description != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(selected.description!, style: Theme.of(context).textTheme.bodyLarge),
                ],
                if (selected.detourKm != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Card(
                    color: AppColors.info.withValues(alpha: 0.08),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Real cost of this detour', style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            '${formatDistance(selected.detourKm!)}'
                            '${selected.detourDurationMin != null ? ' · ${formatDuration(selected.detourDurationMin!)} extra driving' : ''}'
                            '${selected.detourAddedCost != null ? ' · ${formatCurrency(selected.detourAddedCost!)} extra fuel/toll' : ''}',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          const HintText('This is added on top of your current route cost — not free.'),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          final notifier = ref.read(tripSelectionProvider.notifier);
                          final current = ref.read(tripSelectionProvider);
                          notifier.state = current.containsPlace(selected)
                              ? current.removePlace(selected.id)
                              : current.addPlace(selected);
                        },
                        icon: Icon(added ? Icons.check : Icons.add),
                        label: Text(added ? 'Added to Trip' : 'Add to Trip'),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next),
                      tooltip: 'Skip for now',
                      onPressed: () => Navigator.pop(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.bookmark_border),
                      tooltip: 'Save',
                      onPressed: () => _save(context, ref),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_outlined),
                      tooltip: 'Share',
                      onPressed: () => _share(context, selected),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final isLoggedIn = ref.read(isLoggedInProvider);
    if (!isLoggedIn) {
      showGuestGate(context);
      return;
    }
    try {
      await ref.read(favoritesRepositoryProvider).savePlace(id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to Favorites.')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not save. Please try again.')));
      }
    }
  }

  Future<void> _share(BuildContext context, Place p) async {
    final project = p.detourAddedCost != null
        ? '${p.name}\nDetour: ${formatDistance(p.detourKm ?? 0)} added to your route.\n\nSent from Route2Go.'
        : '${p.name}\n\nSent from Route2Go.';
    await SharePlus.instance.share(ShareParams(text: project));
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyLarge)),
      ],
    );
  }
}