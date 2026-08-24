import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/booking_links.dart';
import '../../../core/config/map_tile_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../data/repositories/geocoding_repository.dart';
import '../../providers/trip_planning_provider.dart';
import '../../providers/live_trip_provider.dart';
import '../../providers/places_provider.dart';
import '../../providers/stays_provider.dart';
import '../../providers/itinerary_provider.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/sharing_widgets.dart';
import '../../widgets/permission_explainer.dart';
import '../../../domain/entities/navigation.dart';
import '../../../domain/entities/geo.dart';
import '../../../domain/entities/route_option.dart';

class RouteResultsScreen extends ConsumerStatefulWidget {
  const RouteResultsScreen({super.key});

  @override
  ConsumerState<RouteResultsScreen> createState() => _RouteResultsScreenState();
}

class _RouteResultsScreenState extends ConsumerState<RouteResultsScreen> {
  final MapController _mapController = MapController();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  List<LatLng> _toLatLng(List<List<double>> coords) =>
      coords.map((p) => LatLng(p[1], p[0])).toList();

  LatLngBounds? _routeBounds(List<RouteOption> routes) {
    LatLngBounds? bounds;
    for (final r in routes) {
      final coords = r.geometryCoordinates;
      if (coords == null || coords.isEmpty) continue;
      for (final p in coords) {
        final pt = LatLng(p[1], p[0]);
        if (bounds == null) {
          bounds = LatLngBounds(pt, pt);
        } else {
          bounds.extend(pt);
        }
      }
    }
    return bounds;
  }

  @override
  Widget build(BuildContext context) {
    final calcState = ref.watch(tripCalculationProvider);
    final selectedType = ref.watch(selectedRouteTypeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Options'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share route',
            // Only enabled when a real route exists — sharing never happens
            // before a route is calculated (no fabricated payloads).
            onPressed: calcState.valueOrNull != null &&
                    (calcState.valueOrNull?.routes.isNotEmpty ?? false)
                ? _shareSelectedRoute
                : null,
          ),
        ],
      ),
      body: SafeArea(
        child: calcState.when(
          loading: () =>
              const AppLoadingState(message: 'Calculating routes and cost…'),
          error: (err, st) => AppErrorState(
            error: err,
            onRetry: () =>
                ref.read(tripCalculationProvider.notifier).calculate(),
          ),
          data: (result) {
            if (result == null || result.routes.isEmpty) {
              return const AppEmptyState(
                  message: 'No route available for this input yet.');
            }
            final routes = result.routes;
            final recommended = routes.firstWhere(
              (r) => r.routeType == 'recommended',
              orElse: () => routes[0],
            );
            final selected = selectRoute(result, selectedType);
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _RouteMapCard(
                  routes: routes,
                  selectedType: selected?.routeType ?? recommended.routeType,
                  mapController: _mapController,
                  bounds: _routeBounds(routes),
                  toLatLng: _toLatLng,
                ),
                const SizedBox(height: AppSpacing.lg),
                const HintText('Tap a route below to select it for the trip.'),
                const SizedBox(height: AppSpacing.sm),
                if (_hasAnyTollEstimated(routes))
                  const HintText(
                      'Toll costs marked "Estimated" may change at the plaza.'),
                const SizedBox(height: AppSpacing.sm),
                _ComparisonCard(
                  routes: routes,
                  recommended: recommended,
                  selectedType: selected?.routeType ?? recommended.routeType,
                  onSelect: (type) =>
                      ref.read(selectedRouteTypeProvider.notifier).state = type,
                ),
                const SizedBox(height: AppSpacing.lg),
                if (result.budgetStatus != null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Budget tracker',
                              style: Theme.of(context).textTheme.headlineSmall),
                          FilledButton(
                            onPressed: () =>
                                context.push(AppRoutes.budgetTracker),
                            child: const Text('View'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                _FlowCta(
                  icon: Icons.place_outlined,
                  title: 'Discover places along the route',
                  subtitle:
                      'Attractions with real detour cost before you add them',
                  onTap: () {
                    ref.read(placesNearRouteProvider.notifier).load();
                    context.push(AppRoutes.places);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                _FlowCta(
                  icon: Icons.hotel_outlined,
                  title: 'Find stays near the route',
                  subtitle: 'Budge-fit hotels with provider disclosure',
                  onTap: () {
                    ref.read(staysNearRouteProvider.notifier).load();
                    context.push(AppRoutes.stays);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                _FlowCta(
                  icon: Icons.calendar_month_outlined,
                  title: 'Build your itinerary',
                  subtitle: 'Day-by-day plan with a driving-time safety cap',
                  onTap: () {
                    ref.read(itineraryProvider.notifier).generate();
                    context.push(AppRoutes.itinerary);
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                _TrainBusCard(
                  fromLabel: ref.read(tripPlanningFormProvider).originLabel,
                  toLabel: ref.read(tripPlanningFormProvider).destinationLabel,
                ),
                const SizedBox(height: AppSpacing.xl),
                _StartNavigationCta(
                  route: selected ?? recommended,
                  destination: NavStop(
                    label:
                        ref.read(tripPlanningFormProvider).destinationLabel ??
                            (selected?.label ?? recommended.label),
                    lat: ref.read(tripPlanningFormProvider).destinationLat ?? 0,
                    lng: ref.read(tripPlanningFormProvider).destinationLng ?? 0,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  bool _hasAnyTollEstimated(List<RouteOption> routes) =>
      routes.any((r) => r.tollConfidence == 'estimated');

  /// Shares the selected route with its real info (label, distance, duration,
  /// cost) and both coordinates. Route2Go has no deep-link URL scheme, so no
  /// route2go:// link is fabricated — coordinates let a recipient open the
  /// same places.
  void _shareSelectedRoute() {
    final calc = ref.read(tripCalculationProvider).valueOrNull;
    if (calc == null || calc.routes.isEmpty) return;
    final selected = selectRoute(calc, ref.read(selectedRouteTypeProvider)) ??
        calc.routes.first;
    final form = ref.read(tripPlanningFormProvider);
    final payload = buildRouteShareText(
      originLabel: form.originLabel ?? 'Origin',
      destinationLabel: form.destinationLabel ?? selected.label,
      routeLabel: selected.label,
      distanceKm: selected.distanceKm,
      durationMin: selected.durationMin,
      totalCost: selected.totalCost,
      originLat: form.originLat,
      originLng: form.originLng,
      destinationLat: form.destinationLat,
      destinationLng: form.destinationLng,
    );
    SharePlus.instance.share(ShareParams(text: payload));
  }
}

class _RouteMapCard extends ConsumerStatefulWidget {
  const _RouteMapCard({
    required this.routes,
    required this.selectedType,
    required this.mapController,
    required this.bounds,
    required this.toLatLng,
  });

  final List<RouteOption> routes;
  final String selectedType;
  final MapController mapController;
  final LatLngBounds? bounds;
  final List<LatLng> Function(List<List<double>>) toLatLng;

  @override
  ConsumerState<_RouteMapCard> createState() => _RouteMapCardState();
}

class _RouteMapCardState extends ConsumerState<_RouteMapCard> {
  bool _fitted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_fitted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
    }
  }

  void _fit() {
    final bounds = widget.bounds;
    if (bounds == null) {
      _fitted = true;
      return;
    }
    widget.mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(40)),
    );
    _fitted = true;
  }

  @override
  Widget build(BuildContext context) {
    final tileConfig = ref.watch(mapTileConfigProvider);
    final routes = widget.routes;
    final selected =
        routes.where((r) => r.routeType == widget.selectedType).firstOrNull;
    final activeCoords = selected?.geometryCoordinates;
    // No geometry anywhere -> nothing to draw; render a compact hint instead
    // of a dead map.
    if (routes.every((r) => r.geometryCoordinates == null)) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Icon(Icons.map_outlined, color: AppColors.textSecondary),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'No route map available for this provider.',
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 220,
            child: FlutterMap(
              mapController: widget.mapController,
              options: MapOptions(
                initialCenter: activeCoords == null
                    ? const LatLng(20.0, 78.0)
                    : widget.toLatLng(activeCoords).first,
                initialZoom: 6,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                const Route2GoTileLayer(),
                PolylineLayer(
                  polylines: [
                    for (final r in routes)
                      if (r.geometryCoordinates != null)
                        Polyline(
                          points: widget.toLatLng(r.geometryCoordinates!),
                          strokeWidth:
                              r.routeType == widget.selectedType ? 6 : 3,
                          color: r.routeType == widget.selectedType
                              ? AppColors.primary
                              : AppColors.primary.withValues(alpha: 0.3),
                        ),
                  ],
                ),
                if (activeCoords != null && activeCoords.isNotEmpty) ...[
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: widget.toLatLng(activeCoords).first,
                        width: 36,
                        height: 36,
                        child: const Icon(Icons.trip_origin,
                            size: 36, color: AppColors.primary),
                      ),
                      Marker(
                        point: widget.toLatLng(activeCoords).last,
                        width: 36,
                        height: 36,
                        child: const Icon(Icons.location_on,
                            size: 36, color: AppColors.error),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              tileConfig.styledUrlTemplate != null
                  ? tileConfig.styledAttribution
                  : tileConfig.attribution,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({
    required this.routes,
    required this.recommended,
    required this.selectedType,
    required this.onSelect,
  });

  final List<RouteOption> routes;
  final RouteOption recommended;
  final String selectedType;
  final void Function(String type) onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Compare routes',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.md),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                columnWidths: const {0: FixedColumnWidth(96)},
                border: TableBorder(
                  horizontalInside:
                      BorderSide(color: Colors.black.withValues(alpha: 0.06)),
                ),
                children: [
                  _headerRow(context),
                  _dataRow(context, 'Distance',
                      (r) => Text(formatDistance(r.distanceKm))),
                  _dataRow(context, 'Time',
                      (r) => Text(formatDuration(r.durationMin))),
                  _dataRow(
                    context,
                    'Fuel',
                    (r) => Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(r.fuelCost != null
                            ? formatCurrency(r.fuelCost!)
                            : '—'),
                        const SizedBox(height: AppSpacing.xs),
                        Center(
                            child: ConfidenceBadge(
                                confidence: r.fuelCostConfidence)),
                      ],
                    ),
                  ),
                  _dataRow(
                    context,
                    'Toll',
                    (r) => Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(formatCurrency(r.tollCost)),
                        const SizedBox(height: AppSpacing.xs),
                        Center(
                            child:
                                ConfidenceBadge(confidence: r.tollConfidence)),
                      ],
                    ),
                  ),
                  _dataRow(
                      context,
                      'Total',
                      (r) => Text(r.fuelCost == null
                          ? '—'
                          : formatCurrency(r.totalCost))),
                  _deltaRow(context),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const HintText(
              'Cost/time deltas shown relative to the recommended route, which is highlighted. Times and ETAs are estimates based on normal speeds — Route2Go has no live traffic data.',
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final r in routes)
                  ActionChip(
                    label: Text(r.label),
                    onPressed: () => onSelect(r.routeType),
                    avatar: r.routeType == selectedType
                        ? const Icon(Icons.check, size: 16)
                        : null,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  TableRow _headerRow(BuildContext context) {
    return TableRow(
      children: [
        const SizedBox.shrink(),
        ...routes.map((r) => Padding(
              padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.sm, horizontal: 4),
              child: Column(
                children: [
                  Text(
                    r.label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: r.routeType == 'recommended'
                              ? AppColors.primary
                              : null,
                        ),
                  ),
                  if (r.routeType == 'recommended')
                    const Text('★',
                        style:
                            TextStyle(color: AppColors.warning, fontSize: 12)),
                ],
              ),
            )),
      ],
    );
  }

  TableRow _dataRow(
    BuildContext context,
    String label,
    Widget Function(RouteOption r) cell,
  ) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        ...routes.map(
          (r) => Padding(
            padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.md, horizontal: 4),
            child: Center(child: cell(r)),
          ),
        ),
      ],
    );
  }

  TableRow _deltaRow(BuildContext context) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Text('vs recommended',
              style: Theme.of(context).textTheme.bodySmall),
        ),
        ...routes.map((r) {
          if (r.routeType == recommended.routeType ||
              identical(r, recommended)) {
            return const Padding(
              padding:
                  EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: 4),
              child: Center(child: Text('—')),
            );
          }
          final costDelta = r.totalCost - recommended.totalCost;
          final timeDelta = r.durationMin - recommended.durationMin;
          final color = costDelta <= 0 ? AppColors.success : AppColors.error;
          // When fuel estimates are unavailable, total costs are toll-only and
          // a "vs recommended" cost delta would be misleading — show the time
          // delta alone.
          final fuelUnavailable =
              r.fuelCost == null || recommended.fuelCost == null;
          return Padding(
            padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.md, horizontal: 4),
            child: Column(
              children: [
                if (fuelUnavailable)
                  const Text('—',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w600))
                else
                  Text(
                    '${costDelta == 0 ? '' : costDelta > 0 ? '+' : '−'}${formatCurrency(costDelta.abs())}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: color, fontWeight: FontWeight.w600),
                  ),
                Text(
                  '${timeDelta >= 0 ? '+' : '−'}${formatDuration(timeDelta.abs())}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _FlowCta extends StatelessWidget {
  const _FlowCta({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title, style: Theme.of(context).textTheme.bodyLarge),
        subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

/// Direct "Start Navigation" entry (Phase 3A). Lets the user begin turn-by-turn
/// navigation from the selected route WITHOUT building a trip / budgeting /
/// itinerary / confirm. Uses the existing navigation engine and the current
/// GPS location as the origin.
class _StartNavigationCta extends ConsumerWidget {
  const _StartNavigationCta({
    required this.route,
    required this.destination,
  });

  final RouteOption route;
  final NavStop destination;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FilledButton.icon(
      onPressed: () => _start(context, ref),
      icon: const Icon(Icons.navigation),
      label: const Text('Start navigation'),
    );
  }

  Future<NavStop?> _resolveOrigin(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final geoRepo = ref.read(geocodingRepositoryProvider);
    final device = await geoRepo.deviceLocation();
    if (device != null) {
      return NavStop(label: device.label, lat: device.lat, lng: device.lng);
    }

    if (!context.mounted) return null;
    final explainer = PermissionExplainer(
      icon: Icons.my_location_outlined,
      title: 'Enable location to navigate',
      reasons: const [
        'Route2Go uses your current location as the start of the route.',
        'Location is only used while navigating and is never stored or shared.',
      ],
      permissionLabel: 'Continue',
      onRequest: () {},
    );
    await explainer.showModal(context);
    if (!context.mounted) return null;
    final picked = await GoRouter.of(context).push<GeoPlace>(
      AppRoutes.locationPicker,
      extra: 'origin',
    );
    if (picked == null || !context.mounted) return null;
    return NavStop(label: picked.label, lat: picked.lat, lng: picked.lng);
  }

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final origin = await _resolveOrigin(context, ref);
    if (origin == null || !context.mounted) return;

    await ref.read(liveTripProvider.notifier).startDirect(
      originLabel: origin.label,
      destination: destination,
      route: route,
      waypoints: const [],
    );

    if (context.mounted) context.push(AppRoutes.liveTrip);
  }
}

/// Train/bus booking links for the calculated route. Honest links only:
/// they open the provider's own search in the browser. The bus button is
/// enabled only when both real origin and destination labels exist.
class _TrainBusCard extends StatelessWidget {
  const _TrainBusCard({required this.fromLabel, required this.toLabel});

  final String? fromLabel;
  final String? toLabel;

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasRoute = (fromLabel?.trim().isNotEmpty ?? false) &&
        (toLabel?.trim().isNotEmpty ?? false);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Train & bus bookings',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            const HintText(
                'Opens the provider\'s site in your browser — Route2Go never '
                'books or takes payment for trains or buses.'),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _open(context, BookingLinks.irctcTrain()),
                    icon: const Icon(Icons.train, size: 18),
                    label: const Text('Book train'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: hasRoute
                        ? () => _open(
                              context,
                              BookingLinks.redBus(
                                fromCity: fromLabel!.trim(),
                                toCity: toLabel!.trim(),
                              ),
                            )
                        : null,
                    icon: const Icon(Icons.directions_bus, size: 18),
                    label: const Text('Book bus'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
