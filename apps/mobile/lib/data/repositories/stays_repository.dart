import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datasources/api_client.dart';
import 'base_repository.dart';
import '../../domain/entities/stay.dart';

class StayFilters {
  const StayFilters({
    this.maxPricePerNight,
    this.minRating,
    this.maxDistanceKm,
    this.amenities = const [],
    this.roomType,
  });

  final double? maxPricePerNight;
  final double? minRating;
  final double? maxDistanceKm;
  final List<String> amenities;
  final String? roomType;

  StayFilters copyWith({
    double? maxPricePerNight,
    double? minRating,
    double? maxDistanceKm,
    List<String>? amenities,
    String? roomType,
  }) {
    return StayFilters(
      maxPricePerNight: maxPricePerNight ?? this.maxPricePerNight,
      minRating: minRating ?? this.minRating,
      maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm,
      amenities: amenities ?? this.amenities,
      roomType: roomType ?? this.roomType,
    );
  }
}

class StaysRepository extends BaseRepository {
  StaysRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<List<Stay>> staysNearRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    StayFilters filters = const StayFilters(),
  }) async {
    final res = await _apiClient.get('/stays-near-route', queryParameters: {
      'origin_lat': '$originLat',
      'origin_lng': '$originLng',
      'dest_lat': '$destLat',
      'dest_lng': '$destLng',
      if (filters.maxPricePerNight != null)
        'max_price': '${filters.maxPricePerNight}',
      if (filters.minRating != null) 'min_rating': '${filters.minRating}',
      if (filters.maxDistanceKm != null)
        'max_distance_km': '${filters.maxDistanceKm}',
      if (filters.roomType != null) 'room_type': filters.roomType!,
      if (filters.amenities.isNotEmpty)
        'amenities': filters.amenities.join(','),
    });
    return parseList(res, Stay.fromJson);
  }
}

final staysRepositoryProvider = Provider<StaysRepository>((ref) {
  return StaysRepository(ref.watch(apiClientProvider));
});
