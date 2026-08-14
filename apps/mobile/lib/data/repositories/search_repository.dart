import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datasources/api_client.dart';
import 'base_repository.dart';
import '../../domain/entities/misc_entities.dart';

class SearchRepository extends BaseRepository {
  SearchRepository(this._apiClient);
  final ApiClient _apiClient;

  /// Global autocomplete across places/hotels/routes/saved trips (spec 5.14).
  /// `query` must be at least 2 characters; empty results are a normal
  /// no-match, not an error.
  Future<List<SearchResult>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];
    final res =
        await _apiClient.get('/search', queryParameters: {'q': trimmed});
    return parseList(res, SearchResult.fromJson);
  }

  Future<List<FeatureFlag>> featureFlags() async {
    final res = await _apiClient.get('/feature-flags');
    return parseList(res, FeatureFlag.fromJson);
  }
}

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository(ref.watch(apiClientProvider));
});
