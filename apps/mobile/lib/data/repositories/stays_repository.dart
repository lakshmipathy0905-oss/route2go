import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datasources/api_client.dart';
import 'base_repository.dart';
import '../../domain/entities/hotel_details.dart';
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

  /// Per-session cache of fetched hotel details keyed by stay id, so the
  /// details sheet never re-hits the paid upstream API for the same hotel.
  final Map<String, HotelDetails?> _detailsCache = {};

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

  /// Real photo + rating/reviews/price for one hotel. Returns null when the
  /// backend has no matching live listing (or no SERPAPI_KEY is configured).
  Future<HotelDetails?> fetchDetails(Stay stay) async {
    final cached = _detailsCache[stay.id];
    if (cached != null || _detailsCache.containsKey(stay.id)) return cached;

    final res = await _apiClient.post(
      '/hotel-details',
      body: {
        'name': stay.name,
        if (stay.partnerName != null) 'city': stay.partnerName,
      },
      allowGuest: true,
    );
    final raw = res['details'];
    final details =
        raw is Map<String, dynamic> ? HotelDetails.fromJson(raw) : null;
    _detailsCache[stay.id] = details;
    return details;
  }
}

final staysRepositoryProvider = Provider<StaysRepository>((ref) {
  return StaysRepository(ref.watch(apiClientProvider));
});
