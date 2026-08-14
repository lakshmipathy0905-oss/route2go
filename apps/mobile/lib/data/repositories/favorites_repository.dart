import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datasources/api_client.dart';
import 'base_repository.dart';
import '../../domain/entities/misc_entities.dart';

/// Favorites reflect the spec's Saved lists (spec Section 5.11 / Screen 43)
/// across places, hotels, routes and trips.
class FavoritesRepository extends BaseRepository {
  FavoritesRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<List<SearchResult>> favorites({String? kind}) async {
    final res = await _apiClient.get(
      '/favorites',
      queryParameters: {if (kind != null) 'kind': kind},
    );
    return parseList(res, SearchResult.fromJson);
  }

  Future<void> savePlace(String placeId) async {
    await _apiClient.post('/favorites',
        body: {'action': 'save_place', 'place_id': placeId});
  }

  Future<void> unsavePlace(String placeId) async {
    await _apiClient.post('/favorites',
        body: {'action': 'unsave_place', 'place_id': placeId});
  }

  Future<void> saveTrip(String tripId) async {
    await _apiClient
        .post('/favorites', body: {'action': 'save_trip', 'trip_id': tripId});
  }

  Future<void> unsaveTrip(String tripId) async {
    await _apiClient
        .post('/favorites', body: {'action': 'unsave_trip', 'trip_id': tripId});
  }
}

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  return FavoritesRepository(ref.watch(apiClientProvider));
});

/// Affiliate click logging (spec 2.5 / 23.2): every booking CTA logs the
/// click BEFORE redirecting to the partner deep link.
class AffiliateRepository extends BaseRepository {
  AffiliateRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<void> logClick({
    required String stayId,
    required String partnerId,
    String? tripId,
  }) async {
    await _apiClient.post('/affiliate', body: {
      'action': 'click',
      'stay_id': stayId,
      'partner_id': partnerId,
      if (tripId != null) 'trip_id': tripId,
    });
  }
}

final affiliateRepositoryProvider = Provider<AffiliateRepository>((ref) {
  return AffiliateRepository(ref.watch(apiClientProvider));
});
