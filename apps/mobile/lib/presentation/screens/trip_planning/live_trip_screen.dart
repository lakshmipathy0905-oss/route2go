import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../data/repositories/geocoding_repository.dart';
import '../../../domain/entities/navigation.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/live_trip_provider.dart';
import '../../widgets/sharing_widgets.dart';
import '../../widgets/app_widgets.dart';

/// In-app GPS navigation screen (Phase 2). Replaces the static trip summary +
/// external maps hand-off with a real map-based navigation experience using
/// the existing flutter_map architecture: user position marker, active route
/// polyline, next-maneuver card, live ETA/remaining distance, RECENTER,
/// add-stop, change-destination, voice mute, and end-navigation.
class LiveTripScreen extends ConsumerStatefulWidget {
  const LiveTripScreen({super.key});

  @override
  ConsumerState<LiveTripScreen> createState() => _LiveTripScreenState();
}

class _LiveTripScreenState extends ConsumerState<LiveTripScreen> {
  final MapController _mapController = MapController();
  bool _following = true;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  List<LatLng> _toLatLng(List<List<double>> coords) =>
      coords.map((p) => LatLng(p[1], p[0])).toList();

  void _onMapEvent(MapEvent event) {
    // User interaction (drag / pinch / tap / fling) stops automatic follow.
    // Programmatic moves from MapController must not.
    const userSources = {
      MapEventSource.tap,
      MapEventSource.dragStart,
      MapEventSource.onDrag,
      MapEventSource.dragEnd,
      MapEventSource.multiFingerGestureStart,
      MapEventSource.onMultiFinger,
      MapEventSource.multiFingerEnd,
      MapEventSource.flingAnimationController,
      MapEventSource.doubleTap,
      MapEventSource.doubleTapHold,
    };
    if (event is MapEventMoveStart && userSources.contains(event.source)) {
      if (_following) setState(() => _following = false);
    }
  }

  void _recenter() {
    final pos = ref.read(navigationProvider).position;
    if (pos == null) return;
    _mapController.move(LatLng(pos.lat, pos.lng), 16);
    setState(() => _following = true);
  }

  Future<void> _endTrip() async {
    ref.read(liveTripProvider.notifier).end();
    if (context.mounted) context.go(AppRoutes.home);
  }

  Future<void> _pickStop({required String title}) async {
    final stop = await showModalBottomSheet<NavStop>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _NavStopSheet(title: title),
    );
    if (stop == null || !mounted) return;
    final notifier = ref.read(navigationProvider.notifier);
    if (title == 'Change destination') {
      await notifier.changeDestination(stop);
    } else {
      await notifier.addStop(stop);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(navigationProvider.select((s) => s.status));
    final destination =
        ref.watch(navigationProvider.select((s) => s.destination));
    final offline = ref.watch(navigationProvider.select((s) => s.offline));
    final voiceMuted =
        ref.watch(navigationProvider.select((s) => s.voiceMuted));
    final live = ref.watch(liveTripProvider);

    // No active session yet — safe empty state (should not normally be hit
    // because navigation starts before this screen is pushed).
    if (destination == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Live Trip')),
        body: const AppEmptyState(
            message: 'No active trip. Start one from your plan.'),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // --- Map ---
          Positioned.fill(
            child: _NavMap(
              mapController: _mapController,
              following: _following,
              onMapEvent: _onMapEvent,
              onRecenter: _recenter,
              toLatLng: _toLatLng,
            ),
          ),

          // --- Top bar: destination + end trip ---
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm),
                          child: Row(
                            children: [
                              const Icon(Icons.flag,
                                  color: AppColors.error, size: 18),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  destination.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    IconButton.filled(
                      tooltip: 'End trip',
                      onPressed: _endTrip,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // --- Maneuver card ---
          const Positioned(
            top: 90,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: _ManeuverCard(),
              ),
            ),
          ),

          // --- Status banners (off-route / recalculating / location) ---
          if (status == NavigationStatus.offRoute ||
              status == NavigationStatus.recalculating) ...[
            const Positioned(
                top: 250, left: 0, right: 0, child: _OffRouteBanner()),
          ],

          // --- RECENTER + controls ---
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_following)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: FilledButton.icon(
                          onPressed: _recenter,
                          icon: const Icon(Icons.my_location),
                          label: const Text('RECENTER'),
                        ),
                      ),
                    _ProgressCard(live: live),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickStop(title: 'Add stop'),
                            icon: const Icon(Icons.add_location_alt_outlined),
                            label: const Text('Add stop'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _pickStop(title: 'Change destination'),
                            icon: const Icon(Icons.edit_location_alt_outlined),
                            label: const Text('Change dest'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => ref
                                .read(navigationProvider.notifier)
                                .toggleVoice(),
                            icon: Icon(voiceMuted
                                ? Icons.volume_off
                                : Icons.volume_up),
                            label: Text(voiceMuted ? 'Unmute' : 'Mute'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => ref
                                .read(navigationProvider.notifier)
                                .recalculate(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Recalc'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // --- Arrived overlay ---
          if (status == NavigationStatus.arrived)
            Positioned.fill(
              child: Container(
                color: AppColors.surface.withValues(alpha: 0.95),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.flag,
                            size: 64, color: AppColors.success),
                        const SizedBox(height: AppSpacing.lg),
                        Text('You have arrived.',
                            style: Theme.of(context).textTheme.headlineLarge),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          destination.label,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        FilledButton.icon(
                          onPressed: _endTrip,
                          icon: const Icon(Icons.check),
                          label: const Text('Finish trip'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // --- Location unavailable / starting overlays ---
          if (status == NavigationStatus.locationUnavailable)
            const Positioned.fill(child: _LocationUnavailableOverlay()),
          if (status == NavigationStatus.starting)
            const Positioned(
              bottom: 300,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: AppSpacing.md),
                        Text('Finding your location…'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (offline)
            const Positioned(
              bottom: 350,
              left: 0,
              right: 0,
              child: OfflineBanner(),
            ),
        ],
      ),
    );
  }
}

/// The interactive map layer. Rebuilds only when the route/waypoints change —
/// the user marker animates independently so a GPS event never rebuilds the
/// whole map.
class _NavMap extends ConsumerWidget {
  const _NavMap({
    required this.mapController,
    required this.following,
    required this.onMapEvent,
    required this.onRecenter,
    required this.toLatLng,
  });

  final MapController mapController;
  final bool following;
  final void Function(MapEvent) onMapEvent;
  final VoidCallback onRecenter;
  final List<LatLng> Function(List<List<double>>) toLatLng;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = ref.watch(navigationProvider.select((s) => s.route));
    final waypoints = ref.watch(navigationProvider.select((s) => s.waypoints));
    final destination =
        ref.watch(navigationProvider.select((s) => s.destination));
    final coords = route?.geometryCoordinates;
    final initialPosition =
        ref.read(navigationProvider.select((s) => s.position));

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        // Initial centre is a one-time value (later camera movement is driven
        // by the follow logic in _UserMarker); read, don't watch, so a GPS fix
        // never rebuilds the whole map.
        initialCenter: initialPosition != null
            ? LatLng(initialPosition.lat, initialPosition.lng)
            : destination != null
                ? LatLng(destination.lat, destination.lng)
                : const LatLng(0.0, 0.0),
        initialZoom: 15,
        onMapEvent: onMapEvent,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.route2go.route2go',
        ),
        if (coords != null && coords.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: toLatLng(coords),
                strokeWidth: 6,
                color: AppColors.primary,
              ),
            ],
          ),
        _WaypointMarkers(
            waypoints: waypoints, destination: destination, toLatLng: toLatLng),
        _UserMarker(
          mapController: mapController,
          following: following,
        ),
      ],
    );
  }
}

/// Intermediate stop + destination markers on the map.
class _WaypointMarkers extends StatelessWidget {
  const _WaypointMarkers({
    required this.waypoints,
    required this.destination,
    required this.toLatLng,
  });

  final List<NavStop> waypoints;
  final NavStop? destination;
  final List<LatLng> Function(List<List<double>>) toLatLng;

  @override
  Widget build(BuildContext context) {
    if (destination == null && waypoints.isEmpty) {
      return const SizedBox.shrink();
    }
    final dest = destination;

    return MarkerLayer(
      markers: [
        for (final w in waypoints)
          Marker(
            point: LatLng(w.lat, w.lng),
            width: 36,
            height: 36,
            child: const Icon(Icons.place, size: 36, color: AppColors.accent),
          ),
        if (dest != null)
          Marker(
            point: LatLng(dest.lat, dest.lng),
            width: 36,
            height: 36,
            child: const Icon(Icons.flag, size: 36, color: AppColors.error),
          ),
      ],
    );
  }
}

/// Live user-position marker. Smooths raw GPS with an implicit animation and
/// rotates by heading when the device reports a reliable bearing. When the map
/// is in follow mode it also nudges the camera to the latest smoothed position.
class _UserMarker extends ConsumerStatefulWidget {
  const _UserMarker({required this.mapController, required this.following});

  final MapController mapController;
  final bool following;

  @override
  ConsumerState<_UserMarker> createState() => _UserMarkerState();
}

class _UserMarkerState extends ConsumerState<_UserMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  LocationUpdate? _current;
  LocationUpdate? _from;
  LocationUpdate? _target;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    // Interpolate each frame between the last shown and the new GPS reading.
    _anim.addListener(() {
      final from = _from;
      final to = _target;
      if (from == null || to == null || !mounted) return;
      setState(() {
        _current = LocationUpdate(
          lat: from.lat + (_anim.value * (to.lat - from.lat)),
          lng: from.lng + (_anim.value * (to.lng - from.lng)),
          timestamp: to.timestamp,
          accuracyMeters: to.accuracyMeters,
          speedMps: to.speedMps,
          headingDegrees: to.headingDegrees,
        );
      });
      if (widget.following) {
        widget.mapController.move(
          LatLng(_current!.lat, _current!.lng),
          widget.mapController.camera.zoom,
        );
      }
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _onNewUpdate(LocationUpdate? update) {
    if (update == null) return;
    _target = update;
    if (_current == null) {
      // First fix — jump straight to it and center the camera. setState so the
      // marker actually renders on the very first reading.
      setState(() => _current = update);
      if (widget.following) {
        widget.mapController.move(LatLng(update.lat, update.lng), 16);
      }
      return;
    }
    // Smoothly glide to the new reading.
    _from = _current;
    _anim
      ..stop()
      ..value = 0.0
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    // React to GPS changes outside of build (never mutate state in build).
    ref.listen<LocationUpdate?>(
      navigationProvider.select((s) => s.position),
      (prev, next) => _onNewUpdate(next),
    );

    final pos = _current;
    if (pos == null) return const SizedBox.shrink();

    final heading = pos.hasUsableHeading ? pos.headingDegrees! : 0.0;

    return MarkerLayer(
      markers: [
        Marker(
          point: LatLng(pos.lat, pos.lng),
          width: 44,
          height: 44,
          child: Transform.rotate(
            angle: heading * 3.141592653589793 / 180,
            child:
                const Icon(Icons.navigation, size: 40, color: AppColors.info),
          ),
        ),
      ],
    );
  }
}

/// Top maneuver card: next instruction, road name, distance to maneuver. When
/// the provider gave no usable instructions, shows route-progress info instead
/// (never fabricated text).
class _ManeuverCard extends ConsumerWidget {
  const _ManeuverCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = ref.watch(navigationProvider.select((s) => s.nextManeuver));
    final distKm =
        ref.watch(navigationProvider.select((s) => s.distanceToNextKm));
    final progress = ref.watch(navigationProvider.select((s) => s.progress));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child:
                  const Icon(Icons.turn_right, color: Colors.white, size: 32),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: step != null && step.isUsable
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.instruction,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (step.name != null && step.name!.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            step.name!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Following the highlighted route',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'No turn-by-turn instructions from this provider.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
            ),
            if (step != null && step.isUsable) ...[
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    distKm > 0 ? formatDistance(distKm) : 'Now',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.primary, fontWeight: FontWeight.w700),
                  ),
                  if (progress != null)
                    Text(
                      'of ${formatDistance(progress.remainingKm)} left',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bottom progress card: remaining distance, ETA, and current status.
class _ProgressCard extends ConsumerWidget {
  const _ProgressCard({required this.live});

  final LiveTrip? live;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(navigationProvider.select((s) => s.progress));
    final status = ref.watch(navigationProvider.select((s) => s.status));
    final eta = progress?.eta(now: DateTime.now());

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Remaining',
                    style: Theme.of(context).textTheme.bodyMedium),
                Text(
                  progress != null ? formatDistance(progress.remainingKm) : '…',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('ETA', style: Theme.of(context).textTheme.bodyMedium),
                Text(
                  eta != null
                      ? _formatEta(eta, progress!.remainingDurationMin)
                      : '…',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _statusLabel(status),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _statusColor(status),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatEta(DateTime eta, int remainingMinutes) {
    if (remainingMinutes < 60) return '$remainingMinutes min';
    final h = eta.hour.toString().padLeft(2, '0');
    final m = eta.minute.toString().padLeft(2, '0');
    return 'ETA $h:$m';
  }

  String _statusLabel(NavigationStatus status) {
    switch (status) {
      case NavigationStatus.offRoute:
        return 'Off route — recalculating…';
      case NavigationStatus.recalculating:
        return 'Finding a new route…';
      case NavigationStatus.paused:
        return 'Navigation paused';
      case NavigationStatus.locationUnavailable:
        return 'Location unavailable';
      case NavigationStatus.error:
        return 'Navigation error';
      case NavigationStatus.arrived:
        return 'You have arrived';
      case NavigationStatus.starting:
        return 'Starting…';
      default:
        return 'Navigation active';
    }
  }

  Color _statusColor(NavigationStatus status) {
    switch (status) {
      case NavigationStatus.offRoute:
      case NavigationStatus.error:
        return AppColors.warning;
      case NavigationStatus.paused:
      case NavigationStatus.locationUnavailable:
        return AppColors.textSecondary;
      case NavigationStatus.arrived:
        return AppColors.success;
      default:
        return AppColors.success;
    }
  }
}

class _OffRouteBanner extends StatelessWidget {
  const _OffRouteBanner();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        color: AppColors.warning.withValues(alpha: 0.15),
        child: const Padding(
          padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_outlined, color: AppColors.warning),
              SizedBox(width: AppSpacing.sm),
              Flexible(child: Text('Off route — recalculating…')),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationUnavailableOverlay extends StatelessWidget {
  const _LocationUnavailableOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface.withValues(alpha: 0.92),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off,
                  size: 56, color: AppColors.warning),
              const SizedBox(height: AppSpacing.lg),
              Text('Location unavailable',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              const HintText(
                'Enable location access for Route2Go to continue navigating. '
                'The last known route is still shown.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet to search a place (add stop / change destination) using the
/// existing geocoding pipeline. Returns the selected [NavStop] or null.
class _NavStopSheet extends StatefulWidget {
  const _NavStopSheet({required this.title});

  final String title;

  @override
  State<_NavStopSheet> createState() => _NavStopSheetState();
}

class _NavStopSheetState extends State<_NavStopSheet> {
  final TextEditingController _controller = TextEditingController();
  List<dynamic> _results = const [];
  bool _searching = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().length < 2) {
      setState(() => _results = const []);
      return;
    }
    setState(() => _searching = true);
    final repo =
        ProviderScope.containerOf(context).read(geocodingRepositoryProvider);
    try {
      final places = await repo.geocode(query);
      if (mounted) setState(() => _results = places);
    } catch (_) {
      if (mounted) setState(() => _results = const []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search for a place…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.sm),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            onSubmitted: _search,
            onChanged: (v) {
              if (v.trim().isEmpty) setState(() => _results = const []);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 280,
            child: _results.isEmpty
                ? Center(
                    child: HintText(_searching
                        ? 'Searching…'
                        : 'Type at least 2 characters to search.'),
                  )
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, i) {
                      final p = _results[i];
                      return ListTile(
                        leading: const Icon(Icons.place_outlined,
                            color: AppColors.primary),
                        title: Text(p.label,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: p.subtitle != null
                            ? Text(p.subtitle!,
                                maxLines: 1, overflow: TextOverflow.ellipsis)
                            : null,
                        onTap: () => Navigator.of(context).pop(
                          NavStop(label: p.label, lat: p.lat, lng: p.lng),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
