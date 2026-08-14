import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datasources/api_client.dart';
import 'base_repository.dart';
import '../../domain/entities/notification_item.dart';

class NotificationRepository extends BaseRepository {
  NotificationRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<List<NotificationItem>> listNotifications() async {
    final res = await _apiClient.get('/notifications');
    return parseList(res, NotificationItem.fromJson);
  }

  Future<int> unreadCount() async {
    final res = await _apiClient.get('/notifications', queryParameters: {'unread_count': '1'});
    return (res['data'] as num?)?.toInt() ?? 0;
  }

  Future<void> markRead(String notificationId) async {
    await _apiClient.patch('/notifications', body: {'notification_id': notificationId});
  }

  Future<void> markAllRead() async {
    await _apiClient.patch('/notifications', body: {'mark_all_read': true});
  }

  Future<void> deleteNotification(String notificationId) async {
    await _apiClient.delete('/notifications', queryParameters: {'notification_id': notificationId});
  }

  /// Registers the FCM token so the server can deliver push notifications.
  Future<void> registerFcmToken(String token) async {
    await _apiClient.post('/notifications', body: {'action': 'register_token', 'token': token});
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(apiClientProvider));
});