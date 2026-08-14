import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/profile_repository.dart';
import '../../domain/entities/profile.dart';
import 'auth_provider.dart';

class ProfileNotifier extends AsyncNotifier<Profile?> {
  @override
  Future<Profile?> build() async {
    await ref.watch(authStateProvider.future);
    if (ref.read(authStateProvider).valueOrNull == null) return null;
    final repo = ref.watch(profileRepositoryProvider);
    try {
      final profile = await repo.getProfile();
      // Enforce the persisted analytics opt-out against the analytics SDK
      // (Section 3 data-safety): opting out disables collection immediately.
      await _applyAnalyticsState(profile);
      return profile;
    } catch (_) {
      // No profile yet (new account) is an acceptable empty state, not an error.
      return null;
    }
  }

  Future<void> save(Profile profile) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(profileRepositoryProvider).updateProfile(profile),
    );
  }

  Future<void> setAnalyticsOptOut(bool optOut) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () async {
        final profile = await ref
            .read(profileRepositoryProvider)
            .setAnalyticsOptOut(optOut);
        await _applyAnalyticsState(profile);
        return profile;
      },
    );
  }

  Future<void> _applyAnalyticsState(Profile? profile) async {
    try {
      await FirebaseAnalytics.instance
          .setAnalyticsCollectionEnabled(profile?.analyticsOptOut != true);
    } catch (_) {
      // Analytics is an enhancement; never let an analytics failure surface.
    }
  }

  /// Resets to null after account deletion.
  void clear() => state = const AsyncData(null);
}

final profileProvider = AsyncNotifierProvider<ProfileNotifier, Profile?>(
  ProfileNotifier.new,
);
