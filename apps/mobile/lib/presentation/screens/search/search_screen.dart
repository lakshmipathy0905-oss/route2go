import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../data/repositories/geocoding_repository.dart';
import '../../../domain/entities/navigation.dart';
import '../../../domain/entities/geo.dart';
import '../../../domain/entities/misc_entities.dart';
import '../../providers/trip_planning_provider.dart';
import '../../providers/favorites_search_provider.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/permission_explainer.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  bool _hasQuery = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        actions: [
          if (_hasQuery)
            TextButton(
                onPressed: () => _ctrl.clear(), child: const Text('Clear'))
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                onChanged: (q) {
                  setState(() => _hasQuery = q.trim().isNotEmpty);
                  _debounce?.cancel();
                  if (q.trim().length < 2) return;
                  _debounce = Timer(const Duration(milliseconds: 300), () {
                    ref.read(searchProvider.notifier).search(q);
                  });
                },
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Places, hotels, routes, saved trips',
                ),
              ),
            ),
            Expanded(
              child: ref.watch(searchProvider).when(
                    loading: () => const AppLoadingState(message: 'Searching…'),
                    error: (err, st) => AppErrorState(error: err),
                    data: (response) {
                      if (_ctrl.text.trim().length < 2) {
                        return const AppEmptyState(
                          message:
                              'Type at least 2 characters to search across your saved data.',
                          icon: Icons.search,
                        );
                      }
                      if (response.results.isEmpty) {
                        // Never read "provider unavailable" as "no matches":
                        // a degraded nearby search gets an honest message.
                        if (response.nearbyDegraded) {
                          return const AppEmptyState(
                            message:
                                'Nearby places are unavailable right now. Try again in a moment, or search a place name.',
                            icon: Icons.cloud_off,
                          );
                        }
                        return const AppEmptyState(
                          message: 'No matches found.',
                          icon: Icons.search_off,
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        itemCount: response.results.length,
                        itemBuilder: (context, i) {
                          final r = response.results[i];
                          return ListTile(
                            leading: Icon(_iconFor(r.kind),
                                color: AppColors.primary),
                            title: Text(r.title),
                            subtitle: Text(
                                '${_labelFor(r.kind)} · ${r.subtitle}',
                                style: Theme.of(context).textTheme.bodySmall),
                            trailing: _navigateTrailing(r, context),
                            onTap: () => _open(r.kind, r.id, r),
                          );
                        },
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String kind) {
    switch (kind) {
      case 'place':
      case 'nearby':
        return Icons.place_outlined;
      case 'hotel':
        return Icons.hotel_outlined;
      case 'route':
        return Icons.route_outlined;
      case 'saved_trip':
        return Icons.bookmark_outline;
      default:
        return Icons.search;
    }
  }

  String _labelFor(String kind) {
    switch (kind) {
      case 'place':
      case 'nearby':
        return 'Place';
      case 'hotel':
        return 'Hotel';
      case 'route':
        return 'Route';
      case 'saved_trip':
        return 'Saved trip';
      default:
        return kind;
    }
  }

  void _open(String kind, String id, SearchResult? result) {
    switch (kind) {
      case 'place':
        if (result != null && result.lat != null && result.lng != null) {
          // Show place detail; direct navigation is available via the Navigate
          // icon on the search row.
          context.push(AppRoutes.placeDetailOf(id));
        } else {
          context.push(AppRoutes.placeDetailOf(id));
        }
        break;
      case 'saved_trip':
        context.push(AppRoutes.tripDetailOf(id));
        break;
      case 'nearby':
        // A worldwide address/POI result. If it has coordinates, offer direct
        // navigation (handled by the Navigate icon); otherwise fall back to the
        // trip planner.
        if (result == null || result.lat == null || result.lng == null) {
          context.push(AppRoutes.planTrip);
        }
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opening ${_labelFor(kind)}…')),
        );
    }
  }

  Widget _navigateTrailing(SearchResult r, BuildContext context) {
    // Direct "Go" path: navigate to this place (current location -> here)
    // without creating a trip. Only offered for routable geo results.
    if ((r.kind == 'place' || r.kind == 'nearby') &&
        r.lat != null &&
        r.lng != null) {
      return IconButton(
        tooltip:
            'Navigate to ${_labelFor(r.kind == 'nearby' ? 'nearby' : 'place').toLowerCase()}',
        icon: const Icon(Icons.navigation, color: AppColors.primary),
        onPressed: () => _getDirections(r, context),
        visualDensity: VisualDensity.compact,
      );
    }
    return const Icon(Icons.chevron_right);
  }

  Future<void> _getDirections(SearchResult result, BuildContext context) async {
    final repo = ref.read(geocodingRepositoryProvider);
    final navigator = GoRouter.of(context);

    // Resolve a start point. Prefer the device GPS (requesting permission first
    // via the in-app explainer); fall back to the location picker otherwise.
    late NavStop origin;
    final device = await repo.deviceLocation();
    if (device != null) {
      origin = NavStop(label: device.label, lat: device.lat, lng: device.lng);
    } else {
      final explainer = PermissionExplainer(
        icon: Icons.my_location_outlined,
        title: 'Enable location to navigate',
        reasons: const [
          'Route2Go will use your current location as the start of the route.',
          'Location is only used while navigating and is never stored or shared.',
        ],
        permissionLabel: 'Continue',
        onRequest: () {},
      );
      if (!context.mounted) return;
      await explainer.showModal(context);
      if (!context.mounted) return;
      final picked = await navigator.push<GeoPlace>(
        AppRoutes.locationPicker,
        extra: 'origin',
      );
      if (picked == null || !context.mounted) return;
      origin = NavStop(label: picked.label, lat: picked.lat, lng: picked.lng);
    }

    final destination = NavStop(
      label: result.title,
      lat: result.lat!,
      lng: result.lng!,
    );

    // Prime the shared trip-form + calculation providers with this direct
    // origin/destination so the existing RouteResultsScreen (route preview +
    // alternatives) renders. Nothing is persisted — this is a transient
    // navigation session only.
    ref.read(tripPlanningFormProvider.notifier).state = TripPlanningForm(
      originLabel: origin.label,
      originLat: origin.lat,
      originLng: origin.lng,
      destinationLabel: destination.label,
      destinationLat: destination.lat,
      destinationLng: destination.lng,
      tripType: 'one_way',
      travellers: 1,
      fuelType: 'petrol',
    );

    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const _CalculatingRoutesDialog(),
    );
    ref.read(tripCalculationProvider.notifier).calculate();
    final calc = await ref.read(tripCalculationProvider.future);
    if (!context.mounted) return;
    Navigator.of(context).pop();

    if (calc == null || calc.routes.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No route available for this destination.')),
      );
      return;
    }

    // Reset the selected alternative to recommended for the preview.
    ref.read(selectedRouteTypeProvider.notifier).state = 'recommended';
    if (context.mounted) context.push(AppRoutes.routeResults);
  }
}

class _CalculatingRoutesDialog extends StatelessWidget {
  const _CalculatingRoutesDialog();

  @override
  Widget build(BuildContext context) {
    return const AlertDialog(
      backgroundColor: Colors.white,
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 16),
          Text('Calculating route…'),
        ],
      ),
    );
  }
}
