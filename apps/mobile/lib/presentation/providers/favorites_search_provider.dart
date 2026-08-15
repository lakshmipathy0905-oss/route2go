import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/local/preferences_store.dart';
import '../../data/repositories/favorites_repository.dart';
import '../../data/repositories/search_repository.dart';
import '../../domain/entities/misc_entities.dart';

class FavoritesNotifier extends AsyncNotifier<List<SearchResult>> {
  String? _kind;

  @override
  Future<List<SearchResult>> build() async => const [];

  Future<void> load({String? kind}) async {
    _kind = kind;
    state = const AsyncLoading();
    final repo = ref.read(favoritesRepositoryProvider);
    state = await AsyncValue.guard(() => repo.favorites(kind: kind));
  }

  Future<void> refresh() => load(kind: _kind);
}

final favoritesProvider =
    AsyncNotifierProvider<FavoritesNotifier, List<SearchResult>>(
  FavoritesNotifier.new,
);

/// Debounced search state for the global search screen (spec 2.11).
class SearchNotifier extends AsyncNotifier<List<SearchResult>> {
  String _query = '';

  @override
  Future<List<SearchResult>> build() async => const [];

  String get query => _query;

  Future<void> search(String q) async {
    final trimmed = q.trim();
    if ((trimmed.length < 2 && _query.length < 2) && state.hasValue) return;
    _query = trimmed;
    if (trimmed.length < 2) {
      state = const AsyncData([]);
      return;
    }
    state = const AsyncLoading();
    final repo = ref.read(searchRepositoryProvider);
    // Pass the last used location (if any) so category queries like "cafes
    // near me" can also surface nearby POIs from the server.
    final store = ref.read(preferencesStoreProvider).valueOrNull;
    double? lat;
    double? lng;
    if (store != null) {
      final recents = store.getRecentLocations();
      if (recents.isNotEmpty) {
        lat = recents.first.lat;
        lng = recents.first.lng;
      }
    }
    state =
        await AsyncValue.guard(() => repo.search(trimmed, lat: lat, lng: lng));
  }
}

final searchProvider =
    AsyncNotifierProvider<SearchNotifier, List<SearchResult>>(
  SearchNotifier.new,
);

class FeatureFlagsNotifier extends AsyncNotifier<Map<String, bool>> {
  @override
  Future<Map<String, bool>> build() async {
    final repo = ref.watch(searchRepositoryProvider);
    try {
      final flags = await repo.featureFlags();
      return {for (final f in flags) f.key: f.enabled};
    } catch (_) {
      // Flags are read-only client hints; a fetch failure degrades to all-off,
      // never to a client-toggled value.
      return const {};
    }
  }

  bool isOn(String key) => state.valueOrNull?[key] ?? false;
}

final featureFlagsProvider =
    AsyncNotifierProvider<FeatureFlagsNotifier, Map<String, bool>>(
  FeatureFlagsNotifier.new,
);
