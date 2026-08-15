import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/map_tile_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../data/repositories/geocoding_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trips_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/permission_explainer.dart';
import '../../widgets/sharing_widgets.dart';
import '../../widgets/guest_gate.dart';
import '../../widgets/phase2_gate.dart';
import '../../../domain/entities/trip_summary.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = ref.watch(isLoggedInProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Route2Go'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () => context.push(AppRoutes.search),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none),
            tooltip: 'Notifications',
            onPressed: () {
              if (!isLoggedIn) {
                showGuestGate(context);
                return;
              }
              context.push(AppRoutes.notifications);
            },
          ),
        ],
      ),
      body: SafeArea(
          child: IndexedStack(index: _navIndex, children: const [
        _HomeTab(),
        _TripsTab(),
        _MapTab(),
        _ProfileTab(),
      ])),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _navIndex,
        onTap: (i) => setState(() => _navIndex = i),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.route_outlined), label: 'Trips'),
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Map'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

class _HomeTab extends ConsumerWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(isLoggedInProvider);
    final trips = ref.watch(tripsProvider).valueOrNull ?? const <TripSummary>[];
    final vehicles = ref.watch(vehicleListProvider).valueOrNull ?? const [];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (!isLoggedIn)
          _GuestBanner(onSignIn: () => context.push(AppRoutes.login)),
        const SizedBox(height: AppSpacing.lg),
        _PlanTripCta(onTap: () => context.push(AppRoutes.planTrip)),
        const SizedBox(height: AppSpacing.xl),
        const Phase2Gate(
          flagKey: 'phase2_offline',
          title: 'Offline route packages',
          subtitle: 'Download routes and places for offline use',
          icon: Icons.cloud_off_outlined,
          child: SizedBox.shrink(),
        ),
        const SizedBox(height: AppSpacing.xl),
        SectionHeader(
          title: 'My vehicles',
          trailing: TextButton(
            onPressed: () {
              if (!isLoggedIn) {
                showGuestGate(context);
                return;
              }
              context.push(AppRoutes.vehicles);
            },
            child: const Text('Manage'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (vehicles.isEmpty)
          const AppEmptyState(
              message: 'Add your first vehicle to pre-fill trips.',
              icon: Icons.directions_car_outlined)
        else
          ...vehicles.take(3).map(
                (v) => Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ListTile(
                    leading: const Icon(Icons.directions_car_outlined,
                        color: AppColors.primary),
                    title: Text(v.label),
                    subtitle: Text(v.fuelType.toUpperCase()),
                    trailing: v.isDefault
                        ? const Icon(Icons.star,
                            size: 16, color: AppColors.warning)
                        : null,
                    onTap: () => context.push(AppRoutes.vehicles),
                  ),
                ),
              ),
        const SizedBox(height: AppSpacing.xl),
        SectionHeader(
          title: 'Recent Trips',
          trailing: TextButton(
            onPressed: () {
              if (!isLoggedIn) {
                showGuestGate(context);
                return;
              }
              context.go(AppRoutes.home);
            },
            child: const Text('See all'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (trips.isEmpty)
          AppEmptyState(
            message: isLoggedIn
                ? 'Plan your first trip to see it here.'
                : 'Sign in to see your saved trips.',
            icon: Icons.history,
          )
        else
          ...trips.take(3).map(
                (t) => Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ListTile(
                    leading: const Icon(Icons.route_outlined,
                        color: AppColors.primary),
                    title: Text('${t.originLabel} → ${t.destinationLabel}',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(t.status),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.tripDetailOf(t.id)),
                  ),
                ),
              ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _TripsTab extends ConsumerWidget {
  const _TripsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(isLoggedInProvider);
    if (!isLoggedIn) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline,
                  size: 44, color: AppColors.textSecondary),
              const SizedBox(height: AppSpacing.md),
              const Text('Saved trips are private to your account.',
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                  onPressed: () => showGuestGate(context),
                  child: const Text('Sign in to see trips')),
            ],
          ),
        ),
      );
    }

    final trips = ref.watch(tripsProvider);
    return trips.when(
      loading: () => const AppLoadingState(message: 'Loading trips…'),
      error: (err, st) => AppErrorState(error: err),
      data: (list) {
        if (list.isEmpty) {
          return const AppEmptyState(
            message: 'No saved trips yet. Plan one and it will appear here.',
            icon: Icons.route_outlined,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final t = list[i];
            return Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              child: ListTile(
                leading:
                    const Icon(Icons.route_outlined, color: AppColors.primary),
                title: Text('${t.originLabel} → ${t.destinationLabel}'),
                subtitle: Text(
                  '${t.tripType == 'round_trip' ? 'Round trip' : 'One-way'} · ${t.status}'
                  '${t.budgetTotal != null ? ' · ${formatCurrency(t.budgetTotal!)} budget' : ''}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.tripDetailOf(t.id)),
              ),
            );
          },
        );
      },
    );
  }
}

class _MapTab extends ConsumerWidget {
  const _MapTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(isLoggedInProvider);
    final trips = ref.watch(tripsProvider).valueOrNull ?? const <TripSummary>[];
    final hasTrips = isLoggedIn && trips.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _SavedTripsMap(trips: hasTrips ? trips : const [])),
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: SectionHeader(
            title: hasTrips ? 'Saved routes' : 'Your trips',
          ),
        ),
        SizedBox(
          height: 128,
          child: hasTrips
              ? ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  scrollDirection: Axis.horizontal,
                  itemCount: trips.length,
                  itemBuilder: (context, i) => _TripRouteCard(
                    trip: trips[i],
                    color: _kTripPalette[i % _kTripPalette.length],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    isLoggedIn
                        ? 'Plan a trip and its route will show here.'
                        : 'Sign in to see your saved routes on the map.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

const _kTripPalette = [
  AppColors.primary,
  AppColors.accent,
  AppColors.info,
  AppColors.warning,
];

class _SavedTripsMap extends ConsumerStatefulWidget {
  const _SavedTripsMap({required this.trips});

  final List<TripSummary> trips;

  @override
  ConsumerState<_SavedTripsMap> createState() => _SavedTripsMapState();
}

class _SavedTripsMapState extends ConsumerState<_SavedTripsMap> {
  final MapController _mapController = MapController();
  bool _fitted = false;
  bool _locating = false;
  LatLng? _currentLocation;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _SavedTripsMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trips != widget.trips) _fitted = false;
  }

  LatLngBounds? _bounds() {
    LatLngBounds? b;
    void add(double lat, double lng) {
      final pt = LatLng(lat, lng);
      if (b == null) {
        b = LatLngBounds(pt, pt);
      } else {
        b!.extend(pt);
      }
    }

    for (final t in widget.trips) {
      if (t.originLat != null && t.originLng != null) {
        add(t.originLat!, t.originLng!);
      }
      if (t.destinationLat != null && t.destinationLng != null) {
        add(t.destinationLat!, t.destinationLng!);
      }
      for (final p in t.bestRouteCoordinates ?? const <List<double>>[]) {
        if (p.length >= 2) add(p[1], p[0]);
      }
    }
    return b;
  }

  void _fit() {
    if (_fitted) return;
    _fitted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bounds = _bounds();
      if (bounds == null) return;
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(48)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final trips = widget.trips;
    if (!_fitted) _fit();

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
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
                if (trips.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      for (var i = 0; i < trips.length; i++)
                        if (trips[i].bestRouteCoordinates != null)
                          Polyline(
                            points: _toLatLng(trips[i].bestRouteCoordinates!),
                            strokeWidth: 5,
                            color: _kTripPalette[i % _kTripPalette.length],
                          ),
                    ],
                  ),
                if (trips.isNotEmpty)
                  MarkerLayer(
                    markers: [
                      for (var i = 0; i < trips.length; i++) ...[
                        if (trips[i].originLat != null &&
                            trips[i].originLng != null)
                          Marker(
                            point: LatLng(
                                trips[i].originLat!, trips[i].originLng!),
                            width: 36,
                            height: 36,
                            child: const Icon(Icons.trip_origin,
                                size: 36, color: AppColors.primary),
                          ),
                        if (trips[i].destinationLat != null &&
                            trips[i].destinationLng != null)
                          Marker(
                            point: LatLng(trips[i].destinationLat!,
                                trips[i].destinationLng!),
                            width: 36,
                            height: 36,
                            child: const Icon(Icons.location_on,
                                size: 36, color: AppColors.error),
                          ),
                      ],
                      if (_currentLocation != null)
                        Marker(
                          point: _currentLocation!,
                          alignment: Alignment.center,
                          width: 20,
                          height: 20,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.info,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x553B82F6),
                                  blurRadius: 10,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          if (trips.isEmpty)
            const Positioned(
              top: AppSpacing.md,
              left: AppSpacing.md,
              right: AppSpacing.md,
              child: HintText(
                  'Saved route maps appear here with your start and drop points.'),
            ),
          Positioned(
            right: AppSpacing.md,
            bottom: AppSpacing.md,
            child: FilledButton.icon(
              onPressed: _locating ? null : _useMyLocation,
              icon: _locating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.my_location, size: 18),
              label: const Text('Use my current location'),
            ),
          ),
        ],
      ),
    );
  }

  static List<LatLng> _toLatLng(List<List<double>> coords) =>
      coords.map((p) => LatLng(p[1], p[0])).toList();

  Future<void> _useMyLocation() async {
    final explainer = PermissionExplainer(
      icon: Icons.gps_fixed,
      title: 'Use your current location',
      reasons: const [
        'Show exactly where you are on the map.',
        'Find routes and places near you.',
        'Location is only used while you are on the map screen.',
      ],
      permissionLabel: 'Allow location',
      onRequest: () => Navigator.of(context).pop(),
    );
    await explainer.showModal(context);
    if (!mounted) return;

    setState(() => _locating = true);
    final place = await ref.read(geocodingRepositoryProvider).deviceLocation();
    if (!mounted) return;
    setState(() => _locating = false);

    if (place == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Location is unavailable. Turn on GPS/location and try again, or open a saved trip for its route.'),
        ),
      );
      return;
    }

    final pt = LatLng(place.lat, place.lng);
    setState(() => _currentLocation = pt);
    _mapController.move(pt, 14);
  }
}

class _TripRouteCard extends StatelessWidget {
  const _TripRouteCard({required this.trip, required this.color});

  final TripSummary trip;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
      child: Card(
        margin: const EdgeInsets.only(right: AppSpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: color.withValues(alpha: 0.6), width: 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: () => context.push(AppRoutes.tripDetailOf(trip.id)),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '${trip.originLabel} → ${trip.destinationLabel}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    if (trip.bestDurationMin != null) ...[
                      const Icon(Icons.schedule,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          formatDuration(trip.bestDurationMin!),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                    if (trip.bestDistanceKm != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '${trip.bestDistanceKm!.toStringAsFixed(0)} km',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (trip.bestRouteCost != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        formatCurrency(trip.bestRouteCost!),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(isLoggedInProvider);
    final profile = ref.watch(profileProvider).valueOrNull;

    final items = <(IconData, String, VoidCallback)>[
      (
        Icons.person_outline,
        'Edit profile',
        () => context.push(AppRoutes.profileEdit)
      ),
      (
        Icons.favorite_outline,
        'Favorites',
        () {
          if (!isLoggedIn) {
            showGuestGate(context);
            return;
          }
          context.push(AppRoutes.favorites);
        }
      ),
      (
        Icons.notifications_none,
        'Notifications & preferences',
        () {
          if (!isLoggedIn) {
            showGuestGate(context);
            return;
          }
          context.push(AppRoutes.notifications);
        }
      ),
      (
        Icons.settings_outlined,
        'Settings',
        () => context.push(AppRoutes.settings)
      ),
      (
        Icons.help_outline,
        'Help & support',
        () => context.push(AppRoutes.help)
      ),
      (
        Icons.shield_outlined,
        'Privacy policy',
        () => context.push(AppRoutes.privacy)
      ),
      (
        Icons.description_outlined,
        'Terms of service',
        () => context.push(AppRoutes.terms)
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: const Icon(Icons.person_outline, color: AppColors.primary),
            ),
            title: Text(
                profile?.name ?? (isLoggedIn ? 'Route2Go user' : 'Guest'),
                style: Theme.of(context).textTheme.bodyLarge),
            subtitle: Text(isLoggedIn ? 'Signed in' : 'Browsing as guest',
                style: Theme.of(context).textTheme.bodySmall),
            trailing: isLoggedIn
                ? TextButton(
                    onPressed: () => ref.read(authRepositoryProvider).signOut(),
                    child: const Text('Sign out'))
                : TextButton(
                    onPressed: () => context.push(AppRoutes.login),
                    child: const Text('Sign in')),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ...items.map(
          (m) => ListTile(
            leading: Icon(m.$1, color: AppColors.textSecondary),
            title: Text(m.$2),
            trailing: const Icon(Icons.chevron_right),
            onTap: m.$3,
          ),
        ),
      ],
    );
  }
}

class _GuestBanner extends StatelessWidget {
  const _GuestBanner({required this.onSignIn});
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.info.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.info),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                "You're browsing as a guest. Sign in to save trips and vehicles.",
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            TextButton(onPressed: onSignIn, child: const Text('Sign in')),
          ],
        ),
      ),
    );
  }
}

class _PlanTripCta extends StatelessWidget {
  const _PlanTripCta({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card + 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2E0F4C5C),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Row(
              children: [
                const Icon(Icons.add_road, color: Colors.white, size: 32),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Plan a Trip',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(color: Colors.white)),
                      const SizedBox(height: AppSpacing.xs),
                      const Text('Route, cost, places and stays — in one flow',
                          style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios,
                    color: Colors.white70, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
