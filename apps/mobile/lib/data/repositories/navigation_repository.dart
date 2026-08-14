import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/navigation.dart';
import '../../domain/entities/route_option.dart';
import '../datasources/api_client.dart';

/// Fetches navigation routes (reroutes / waypoint updates / destination
/// changes) from the lightweight /route-nav edge function. No cost or
/// persistence — just a single recommended route with geometry + steps.
class NavigationRepository {
  NavigationRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<RouteOption> fetchRoute({
    required NavStop origin,
    required NavStop destination,
    List<NavStop> waypoints = const [],
  }) async {
    final response = await _apiClient.post(
      '/route-nav',
      allowGuest: true,
      body: {
        'origin': {'label': origin.label, 'lat': origin.lat, 'lng': origin.lng},
        'destination': {
          'label': destination.label,
          'lat': destination.lat,
          'lng': destination.lng,
        },
        if (waypoints.isNotEmpty)
          'waypoints': [
            for (final w in waypoints)
              {'label': w.label, 'lat': w.lat, 'lng': w.lng},
          ],
      },
    );
    final route = response['data']?['route'];
    if (route is! Map<String, dynamic>) {
      throw StateError('route-nav returned an unexpected shape.');
    }
    return RouteOption.fromJson(route);
  }
}

final navigationRepositoryProvider = Provider<NavigationRepository>((ref) {
  return NavigationRepository(ref.watch(apiClientProvider));
});
