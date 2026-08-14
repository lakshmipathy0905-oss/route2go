import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/trip_repository.dart';
import '../../domain/entities/trip_summary.dart';
import 'auth_provider.dart';

class TripsNotifier extends AsyncNotifier<List<TripSummary>> {
  @override
  Future<List<TripSummary>> build() async {
    await ref.watch(authStateProvider.future);
    if (ref.read(authStateProvider).valueOrNull == null) return const [];
    final repo = ref.watch(tripRepositoryProvider);
    return repo.listTrips();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(tripRepositoryProvider).listTrips());
  }

  Future<void> rename(String tripId, String newLabel) async {
    state = await AsyncValue.guard(() async {
      await ref
          .read(tripRepositoryProvider)
          .renameTrip(tripId: tripId, newLabel: newLabel);
      return ref.read(tripRepositoryProvider).listTrips();
    });
  }

  Future<void> duplicate(String tripId) async {
    state = await AsyncValue.guard(() async {
      await ref.read(tripRepositoryProvider).duplicateTrip(tripId: tripId);
      return ref.read(tripRepositoryProvider).listTrips();
    });
  }

  Future<void> delete(String tripId) async {
    state = await AsyncValue.guard(() async {
      await ref.read(tripRepositoryProvider).deleteTrip(tripId);
      return ref.read(tripRepositoryProvider).listTrips();
    });
  }
}

final tripsProvider = AsyncNotifierProvider<TripsNotifier, List<TripSummary>>(
  TripsNotifier.new,
);
