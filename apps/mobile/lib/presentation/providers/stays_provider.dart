import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/stays_repository.dart';
import '../../domain/entities/stay.dart';
import 'trip_planning_provider.dart';

/// Stays found near the current route (spec 2.5).
class StaysNearRoute {
  const StaysNearRoute(
      {required this.stays, this.filters = const StayFilters()});
  final List<Stay> stays;
  final StayFilters filters;
}

class StaysNotifier extends AsyncNotifier<StaysNearRoute> {
  @override
  Future<StaysNearRoute> build() async {
    return const StaysNearRoute(stays: []);
  }

  Future<void> load({StayFilters filters = const StayFilters()}) async {
    final form = ref.read(tripPlanningFormProvider);
    if (!form.isReadyToCalculate) {
      state = const AsyncData(StaysNearRoute(stays: []));
      return;
    }
    state = const AsyncLoading();
    final repo = ref.read(staysRepositoryProvider);
    state = await AsyncValue.guard(() async {
      final stays = await repo.staysNearRoute(
        originLat: form.originLat!,
        originLng: form.originLng!,
        destLat: form.destinationLat!,
        destLng: form.destinationLng!,
        filters: filters,
      );
      return StaysNearRoute(stays: stays, filters: filters);
    });
  }
}

final staysNearRouteProvider =
    AsyncNotifierProvider<StaysNotifier, StaysNearRoute>(
  StaysNotifier.new,
);
