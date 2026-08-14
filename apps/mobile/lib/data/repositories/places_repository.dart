import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datasources/api_client.dart';
import 'base_repository.dart';
import '../../domain/entities/place.dart';

class PlacesRepository extends BaseRepository {
  PlacesRepository(this._apiClient);
  final ApiClient _apiClient;

  /// Returns places within `detourRadiusKm` of the route corridor between
  /// origin and destination, matching the categories filter.
  Future<List<Place>> placesNearRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    List<String> categoryIds = const [],
    double detourRadiusKm = 30,
    double? routeDistanceKm,
    int? routeDurationMin,
    double? fuelCostPerKm,
  }) async {
    final res = await _apiClient.get('/places-near-route', queryParameters: {
      'origin_lat': '$originLat',
      'origin_lng': '$originLng',
      'dest_lat': '$destLat',
      'dest_lng': '$destLng',
      'radius_km': '$detourRadiusKm',
      'route_distance_km': routeDistanceKm?.toString(),
      'route_duration_min': routeDurationMin?.toString(),
      'fuel_cost_per_km': fuelCostPerKm?.toString(),
      if (categoryIds.isNotEmpty) 'category_ids': categoryIds.join(','),
    });
    return parseList(res, Place.fromJson);
  }

  Future<List<PlaceCategory>> categories() async {
    final res = await _apiClient.get('/places-near-route', queryParameters: {'categories': '1'});
    return parseList(res, PlaceCategory.fromJson);
  }

  Future<Place?> placeById(String id) async {
    final res = await _apiClient.get('/places-near-route', queryParameters: {'place_id': id});
    final list = parseList(res, Place.fromJson);
    return list.isNotEmpty ? list.first : null;
  }
}

final placesRepositoryProvider = Provider<PlacesRepository>((ref) {
  return PlacesRepository(ref.watch(apiClientProvider));
});