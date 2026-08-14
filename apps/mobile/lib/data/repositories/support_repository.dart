import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datasources/api_client.dart';
import 'base_repository.dart';

class SupportRepository extends BaseRepository {
  SupportRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<void> openTicket({
    required String subject,
    required String message,
  }) async {
    await _apiClient.post('/support', body: {
      'action': 'open',
      'subject': subject,
      'message': message,
    });
  }

  Future<List<Map<String, dynamic>>> faqs() async {
    final res =
        await _apiClient.get('/support', queryParameters: {'faqs': '1'});
    final data = res['data'];
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }
}

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupportRepository(ref.watch(apiClientProvider));
});
