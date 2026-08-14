import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datasources/api_client.dart';
import 'base_repository.dart';

class PrivacyRepository extends BaseRepository {
  PrivacyRepository(this._apiClient);
  final ApiClient _apiClient;

  /// Server-side account deletion: the function deletes/anonymizes all
  /// Supabase-owned data for the user first, then this repo deletes the
  /// Firebase identity (AuthRepository.deleteAccount) — in that exact order,
  /// so no orphaned rows are left behind.
  Future<void> requestDelete({required String reason}) async {
    await _apiClient.post('/privacy', body: {
      'action': 'request_delete',
      'reason': reason,
    });
  }

  Future<void> recordConsent({
    required String consentType,
    required bool granted,
  }) async {
    await _apiClient.post('/privacy', body: {
      'action': 'consent',
      'consent_type': consentType,
      'granted': granted,
    });
  }
}

final privacyRepositoryProvider = Provider<PrivacyRepository>((ref) {
  return PrivacyRepository(ref.watch(apiClientProvider));
});
