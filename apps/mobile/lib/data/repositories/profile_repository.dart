import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datasources/api_client.dart';
import 'base_repository.dart';
import '../../domain/entities/profile.dart';

class ProfileRepository extends BaseRepository {
  ProfileRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<Profile?> getProfile() async {
    final res = await _apiClient.get('/profile');
    final data = res['data'];
    if (data == null) return null;
    return Profile.fromJson(data as Map<String, dynamic>);
  }

  Future<Profile> updateProfile(Profile profile) async {
    final res = await _apiClient.patch('/profile', body: profile.toJson());
    return parseObject(res, Profile.fromJson);
  }

  /// Records analytics-opt-out in consent_records and persists on the profile.
  Future<Profile> setAnalyticsOptOut(bool optOut) async {
    final res = await _apiClient.post('/privacy', body: {
      'action': 'consent',
      'consent_type': 'analytics',
      'granted': !optOut,
    });
    final profile = parseObject(res, Profile.fromJson);
    return profile.copyWith(analyticsOptOut: optOut);
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(apiClientProvider));
});
