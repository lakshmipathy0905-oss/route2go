import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../domain/entities/trip_summary.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trips_provider.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/guest_gate.dart';

enum _TripBucket { upcoming, ongoing, completed, cancelled }

extension on _TripBucket {
  String get label => switch (this) {
        _TripBucket.upcoming => 'Upcoming',
        _TripBucket.ongoing => 'Ongoing',
        _TripBucket.completed => 'Completed',
        _TripBucket.cancelled => 'Cancelled',
      };
}

_TripBucket _bucketOf(TripSummary t) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final start = t.startDate;
  final end = t.endDate;

  if (t.status == 'cancelled') return _TripBucket.cancelled;
  if (t.status == 'completed') return _TripBucket.completed;
  if (t.status == 'ongoing') return _TripBucket.ongoing;
  if (start != null) {
    final s = DateTime(start.year, start.month, start.day);
    final e = end != null ? DateTime(end.year, end.month, end.day) : s;
    if (!s.isAfter(today) && !e.isBefore(today)) return _TripBucket.ongoing;
    if (s.isAfter(today)) return _TripBucket.upcoming;
    if (e.isBefore(today)) return _TripBucket.completed;
  }
  return _TripBucket.upcoming;
}

/// My Trips dashboard (spec Section 7/11): Upcoming · Ongoing · Completed ·
/// Cancelled, with honest empty states per bucket.
class TripsDashboardScreen extends ConsumerStatefulWidget {
  const TripsDashboardScreen({super.key});

  @override
  ConsumerState<TripsDashboardScreen> createState() =>
      _TripsDashboardScreenState();
}

class _TripsDashboardScreenState extends ConsumerState<TripsDashboardScreen> {
  _TripBucket _bucket = _TripBucket.upcoming;

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = ref.watch(isLoggedInProvider);

    if (!isLoggedIn) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('My Trips')),
        body: AppEmptyState(
          icon: Icons.lock_outline,
          title: 'Saved trips are private',
          message:
              'Sign in to see your upcoming, ongoing and completed journeys.',
          action: FilledButton(
            onPressed: () => showGuestGate(context),
            child: const Text('Sign in'),
          ),
        ),
      );
    }

    final tripsAsync = ref.watch(tripsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Trips'),
        actions: [
          IconButton(
            tooltip: 'Plan a trip',
            icon: const Icon(Icons.add_road),
            onPressed: () => context.push(AppRoutes.planTrip),
          ),
        ],
      ),
      body: SafeArea(
        child: tripsAsync.when(
          loading: () => const AppLoadingState(message: 'Loading trips…'),
          error: (err, _) => AppErrorState(
            error: err,
            onRetry: () => ref.invalidate(tripsProvider),
          ),
          data: (trips) {
            final buckets = _TripBucket.values.map(
              (b) => (
                bucket: b,
                count: trips.where((t) => _bucketOf(t) == b).length
              ),
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    itemCount: buckets.length,
                    separatorBuilder: (_, i) =>
                        const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (context, i) {
                      final entry = buckets.elementAt(i);
                      final selected = entry.bucket == _bucket;
                      return ChoiceChip(
                        label: Text(
                          '${entry.bucket.label} · ${entry.count}',
                        ),
                        selected: selected,
                        showCheckmark: false,
                        onSelected: (_) =>
                            setState(() => _bucket = entry.bucket),
                        selectedColor: AppColors.primarySoft,
                        labelStyle: TextStyle(
                          color: selected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(child: _BucketList(bucket: _bucket, trips: trips)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BucketList extends StatelessWidget {
  const _BucketList({required this.bucket, required this.trips});

  final _TripBucket bucket;
  final List<TripSummary> trips;

  @override
  Widget build(BuildContext context) {
    final visible = trips.where((t) => _bucketOf(t) == bucket).toList();

    if (visible.isEmpty) {
      final (icon, title, message) = switch (bucket) {
        _TripBucket.upcoming => (
            Icons.airplanemode_active_outlined,
            'No upcoming trips',
            'Plan a journey and it will show up here.',
          ),
        _TripBucket.ongoing => (
            Icons.navigation_outlined,
            'Nothing in progress',
            'Trips that are underway appear here.',
          ),
        _TripBucket.completed => (
            Icons.history,
            'No completed trips yet',
            'Finished journeys are archived here.',
          ),
        _TripBucket.cancelled => (
            Icons.cancel_outlined,
            'No cancelled trips',
            'Cancelled journeys appear here.',
          ),
      };
      return AppEmptyState(
        icon: icon,
        title: title,
        message: message,
        action: bucket == _TripBucket.upcoming
            ? FilledButton.icon(
                onPressed: () => context.push(AppRoutes.planTrip),
                icon: const Icon(Icons.add_road),
                label: const Text('Plan a Trip'),
              )
            : null,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: visible.length,
      itemBuilder: (context, i) {
        final t = visible[i];
        return _TripCard(trip: t);
      },
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip});

  final TripSummary trip;

  Color get _statusColor {
    switch (trip.status) {
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      case 'ongoing':
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  String get _dateLabel {
    if (trip.startDate == null) return 'Dates not set yet';
    final s = trip.startDate!;
    final e = trip.endDate;
    if (e == null) return '${s.day}/${s.month}/${s.year}';
    return '${s.day}/${s.month}/${s.year} – ${e.day}/${e.month}/${e.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => context.push(AppRoutes.tripDetailOf(trip.id)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(Icons.route_outlined,
                        color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      '${trip.originLabel} → ${trip.destinationLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: 2),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      trip.status,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: _statusColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    _dateLabel,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                  const Spacer(),
                  if (trip.bestDistanceKm != null) ...[
                    const Icon(Icons.straighten,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${trip.bestDistanceKm!.toStringAsFixed(0)} km',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
