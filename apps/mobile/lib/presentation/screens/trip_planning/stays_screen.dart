import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/stays_provider.dart';
import '../../providers/trip_planning_provider.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/sharing_widgets.dart';
import '../../../domain/entities/stay.dart';
import '../../../data/repositories/stays_repository.dart';
import '../../../data/repositories/favorites_repository.dart';
class StaysScreen extends ConsumerStatefulWidget {
  const StaysScreen({super.key});

  @override
  ConsumerState<StaysScreen> createState() => _StaysScreenState();
}

class _StaysScreenState extends ConsumerState<StaysScreen> {
  double? _maxPrice;
  double? _minRating;
  double? _maxDistance;
  String? _roomType;

  Future<void> _applyFilters() async {
    await ref.read(staysNearRouteProvider.notifier).load(
          filters: StayFilters(
            maxPricePerNight: _maxPrice,
            minRating: _minRating,
            maxDistanceKm: _maxDistance,
            roomType: _roomType,
            amenities: const ['wifi', 'parking'],
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stays Near Route')),
      body: SafeArea(
        child: Consumer(builder: (context, ref, _) {
          final state = ref.watch(staysNearRouteProvider);
          final trip = ref.watch(tripSelectionProvider);

          return state.when(
            loading: () => const AppLoadingState(message: 'Finding stays…'),
            error: (err, st) => AppErrorState(
              error: err,
              onRetry: () => _applyFilters(),
            ),
            data: (near) {
              if (near.stays.isEmpty) {
                return const AppEmptyState(
                  message: 'No stays found for these filters yet.',
                  icon: Icons.hotel_outlined,
                );
              }
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      children: [
                        Expanded(
                          child: _PriceFilterField(
                            value: _maxPrice,
                            onChanged: (v) => setState(() => _maxPrice = v),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _MinRatingFilter(
                            value: _minRating,
                            onChanged: (v) => setState(() => _minRating = v),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      itemCount: near.stays.length,
                      itemBuilder: (context, i) {
                        final stay = near.stays[i];
                        final selected = trip.containsStay(stay);
                        return _StayCard(
                          stay: stay,
                          selected: selected,
                          onToggleSelect: () {
                            final notifier = ref.read(tripSelectionProvider.notifier);
                            final current = ref.read(tripSelectionProvider);
                            notifier.state = current.containsStay(stay)
                                ? current.removeStay(stay.id)
                                : current.addStay(stay);
                          },
                          onBook: () => _book(context, ref, stay),
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

  Future<void> _book(BuildContext context, WidgetRef ref, Stay stay) async {
    if (stay.bookingUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This stay is not bookable yet.')),
      );
      return;
    }

    // (Spec 3.6) Booking redirects to the partner site — no payment inside
    // Route2Go, so Apple's IAP rule 3.1.1 does not apply to physical,
    // off-platform bookings. We log the click before opening the deep link.
    final booking = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Book on the partner site?'),
        content: Text(
          stay.commission != null
              ? 'You\'ll be taken to ${stay.partnerName ?? 'our partner'} to book at ${formatCurrency(stay.pricePerNight ?? 0)}/night. Route2Go may earn a commission if you book — it never changes your price.'
              : 'You\'ll be taken to ${stay.partnerName ?? 'our partner'} to complete your booking.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue')),
        ],
      ),
    );
    if (booking != true) return;

    try {
      // Log the affiliate click BEFORE redirecting (spec 2.5 / 23.2).
      if (stay.partnerId != null) {
        await ref.read(affiliateRepositoryProvider).logClick(
              stayId: stay.id,
              partnerId: stay.partnerId!,
            );
      }
    } catch (_) {
      // Logging must not block the user's booking.
    }

    final uri = Uri.tryParse(stay.bookingUrl!);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _PriceFilterField extends StatelessWidget {
  const _PriceFilterField({required this.value, required this.onChanged});
  final double? value;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onSubmitted: (v) => onChanged(double.tryParse(v.trim())),
      decoration: const InputDecoration(
        labelText: 'Max price/night (₹)',
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
      ),
    );
  }
}

class _MinRatingFilter extends StatelessWidget {
  const _MinRatingFilter({required this.value, required this.onChanged});
  final double? value;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<double?>(
      initialValue: value,
      isDense: true,
      decoration: const InputDecoration(labelText: 'Min rating'),
      items: const [
        DropdownMenuItem(value: null, child: Text('Any')),
        DropdownMenuItem(value: 4.5, child: Text('4.5+')),
        DropdownMenuItem(value: 4.0, child: Text('4.0+')),
        DropdownMenuItem(value: 3.5, child: Text('3.5+')),
      ],
      onChanged: (v) => onChanged(v),
    );
  }
}

class _StayCard extends StatelessWidget {
  const _StayCard({
    required this.stay,
    required this.selected,
    required this.onToggleSelect,
    required this.onBook,
  });

  final Stay stay;
  final bool selected;
  final VoidCallback onToggleSelect;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      elevation: selected ? 4 : 0,
      shadowColor: AppColors.primary.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: selected
            ? const BorderSide(color: AppColors.primary, width: 1.5)
            : BorderSide(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(stay.name, style: Theme.of(context).textTheme.headlineSmall),
                ),
                if (selected) ...[
                  const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                ],
                if (stay.isSponsored) ...[
                  const DisclosureBadge(label: 'Partner'),
                  const SizedBox(width: AppSpacing.sm),
                ],
                if (stay.rating != null) StarRating(rating: stay.rating, size: 12),
              ],
            ),
            if (stay.partnerName != null) ...[
              const SizedBox(height: AppSpacing.xs),
              HintText('Booked via ${stay.partnerName}'),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Flexible(
                  child: Text(
                    stay.pricePerNight != null
                        ? '${formatCurrency(stay.pricePerNight!)}/night'
                        : 'Price on request',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (stay.distanceFromRouteKm != null) ...[
                  const SizedBox(width: AppSpacing.md),
                  HintText('${formatDistance(stay.distanceFromRouteKm!)} from route'),
                ],
              ],
            ),
            if (stay.amenities.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: 4,
                children: stay.amenities
                    .take(5)
                    .map((a) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                          ),
                          child: Text(a, style: Theme.of(context).textTheme.bodySmall),
                        ))
                    .toList(),
              ),
            ],
            if (stay.commission != null) ...[
              const SizedBox(height: AppSpacing.sm),
              const HintText('Route2Go may earn a commission on bookings — it never changes your price.'),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: onBook,
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Book'),
                ),
                const SizedBox(width: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: onToggleSelect,
                  icon: Icon(selected ? Icons.check : Icons.add, size: 16),
                  label: Text(selected ? 'Selected' : 'Add to itinerary'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}