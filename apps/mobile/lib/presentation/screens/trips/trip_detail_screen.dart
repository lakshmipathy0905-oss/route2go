import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/config/map_tile_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../providers/trips_provider.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/sharing_widgets.dart';
import '../../widgets/phase2_gate.dart';
import '../../../domain/entities/trip_summary.dart';

class TripDetailScreen extends ConsumerStatefulWidget {
  const TripDetailScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tripsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Trip')),
      body: SafeArea(
        child: state.when(
          loading: () => const AppLoadingState(),
          error: (err, st) => AppErrorState(error: err),
          data: (trips) {
            TripSummary? trip;
            for (final t in trips) {
              if (t.id == widget.id) {
                trip = t;
                break;
              }
            }
            if (trip == null) {
              return const AppEmptyState(
                  message: 'This trip is no longer available.');
            }
            final t = trip;
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(t.originLabel,
                    style: Theme.of(context).textTheme.headlineLarge),
                Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                      child: Icon(Icons.arrow_downward,
                          size: 16, color: AppColors.textSecondary),
                    ),
                    Expanded(
                      child: Text(
                        t.destinationLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '${t.tripType == 'round_trip' ? 'Round trip' : 'One-way'} · ${t.travellers} traveller${t.travellers == 1 ? '' : 's'} · ${t.status}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.lg),
                _TripRouteMapCard(trip: t),
                const SizedBox(height: AppSpacing.lg),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Shareable summary',
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: AppSpacing.sm),
                        _line(context, 'Route',
                            '${t.originLabel} → ${t.destinationLabel}'),
                        if (t.bestRouteCost != null)
                          _line(context, 'Est. total',
                              formatCurrency(t.bestRouteCost!)),
                        if (t.bestDurationMin != null)
                          _line(context, 'Est. time',
                              formatDuration(t.bestDurationMin!)),
                        if (t.budgetTotal != null)
                          _line(context, 'Budget',
                              formatCurrency(t.budgetTotal!)),
                        const SizedBox(height: AppSpacing.md),
                        FilledButton.icon(
                          onPressed: () => _share(context, t),
                          icon: const Icon(Icons.share_outlined, size: 18),
                          label: const Text('Share trip'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton.icon(
                  onPressed: () =>
                      context.push(AppRoutes.tripExpensesOf(widget.id)),
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  label: const Text('Expense tracker'),
                ),
                const SizedBox(height: AppSpacing.md),
                const Phase2Gate(
                  flagKey: 'phase2_weather',
                  title: 'Weather & road alerts',
                  subtitle: 'Along-route forecasts before you leave',
                  icon: Icons.wb_sunny_outlined,
                  child: SizedBox.shrink(),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _rename(context, t),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Rename'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await ref
                              .read(tripsProvider.notifier)
                              .duplicate(t.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Trip duplicated.')));
                          }
                        },
                        icon: const Icon(Icons.copy_outlined, size: 16),
                        label: const Text('Duplicate'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextButton.icon(
                  onPressed: () => _delete(context, t),
                  icon:
                      const Icon(Icons.delete_outline, color: AppColors.error),
                  label: const Text('Delete trip',
                      style: TextStyle(color: AppColors.error)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _line(BuildContext context, String label, String value) {
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
                  .bodySmall
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

  Future<void> _share(BuildContext context, TripSummary trip) async {
    final text = 'Route2Go trip summary\n\n'
        '${trip.originLabel} → ${trip.destinationLabel}\n'
        '${trip.tripType == 'round_trip' ? 'Round trip' : 'One-way'} · ${trip.travellers} traveller(s)\n'
        '${trip.bestRouteCost != null ? 'Est. total: ${formatCurrency(trip.bestRouteCost!)}\n' : ''}'
        '${trip.budgetTotal != null ? 'Budget: ${formatCurrency(trip.budgetTotal!)}\n' : ''}'
        '\nPlanned with Route2Go.';
    await SharePlus.instance.share(ShareParams(text: text));
  }

  Future<void> _rename(BuildContext context, TripSummary trip) async {
    final ctrl = TextEditingController(text: trip.originLabel);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename trip'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Trip name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await ref.read(tripsProvider.notifier).rename(trip.id, name);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Trip renamed.')));
    }
  }

  Future<void> _delete(BuildContext context, TripSummary trip) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete trip?'),
        content: Text(
            '"${trip.originLabel}" will be removed with its routes and expenses.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(tripsProvider.notifier).delete(trip.id);
      if (context.mounted) context.pop();
    }
  }
}

// ignore: non_constant_identifier_names
String tripLabelSafe(TripSummary t) =>
    '${t.originLabel} → ${t.destinationLabel}';

class _TripRouteMapCard extends ConsumerStatefulWidget {
  const _TripRouteMapCard({required this.trip});

  final TripSummary trip;

  @override
  ConsumerState<_TripRouteMapCard> createState() => _TripRouteMapCardState();
}

class _TripRouteMapCardState extends ConsumerState<_TripRouteMapCard> {
  final MapController _mapController = MapController();
  bool _fitted = false;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_fitted) {
      _fitted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
    }
  }

  LatLngBounds? _bounds(TripSummary t) {
    LatLngBounds? b;
    void add(double lat, double lng) {
      final pt = LatLng(lat, lng);
      if (b == null) {
        b = LatLngBounds(pt, pt);
      } else {
        b!.extend(pt);
      }
    }

    if (t.originLat != null && t.originLng != null) {
      add(t.originLat!, t.originLng!);
    }
    if (t.destinationLat != null && t.destinationLng != null) {
      add(t.destinationLat!, t.destinationLng!);
    }
    for (final p in t.bestRouteCoordinates ?? const <List<double>>[]) {
      if (p.length >= 2) add(p[1], p[0]);
    }
    return b;
  }

  void _fit() {
    if (!mounted) return;
    final bounds = _bounds(widget.trip);
    if (bounds == null) return;
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(40)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trip;
    final coords = t.bestRouteCoordinates;
    final endpoints = t.originLat != null &&
        t.originLng != null &&
        t.destinationLat != null &&
        t.destinationLng != null;

    if (coords == null && !endpoints) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Icon(Icons.map_outlined, color: AppColors.textSecondary),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'No route map yet — calculate a route for this trip.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 220,
        child: Stack(
          children: [
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: LatLng(20.0, 78.0),
                  initialZoom: 5,
                  interactionOptions: InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  const Route2GoTileLayer(),
                  if (coords != null)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points:
                              coords.map((p) => LatLng(p[1], p[0])).toList(),
                          strokeWidth: 5,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      if (t.originLat != null && t.originLng != null)
                        Marker(
                          point: LatLng(t.originLat!, t.originLng!),
                          width: 36,
                          height: 36,
                          child: const Icon(Icons.trip_origin,
                              size: 36, color: AppColors.primary),
                        ),
                      if (t.destinationLat != null && t.destinationLng != null)
                        Marker(
                          point: LatLng(t.destinationLat!, t.destinationLng!),
                          width: 36,
                          height: 36,
                          child: const Icon(Icons.location_on,
                              size: 36, color: AppColors.error),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (endpoints)
              Positioned(
                bottom: AppSpacing.sm,
                left: AppSpacing.sm,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: Text(
                    '${t.originLabel} → ${t.destinationLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
