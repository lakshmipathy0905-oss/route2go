import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/notification_repository.dart';
import '../../domain/entities/notification_item.dart';
import '../../core/local/preferences_store.dart';
import 'auth_provider.dart';

class NotificationsNotifier extends AsyncNotifier<List<NotificationItem>> {
  @override
  Future<List<NotificationItem>> build() async {
    await ref.watch(authStateProvider.future);
    if (ref.read(authStateProvider).valueOrNull == null) return const [];
    final repo = ref.watch(notificationRepositoryProvider);
    return repo.listNotifications();
  }

  Future<void> markRead(String id) async {
    await ref.read(notificationRepositoryProvider).markRead(id);
    final items = state.valueOrNull;
    if (items == null) return;
    state = AsyncData([
      for (final n in items) n.id == id ? NotificationItem(id: n.id, type: n.type, title: n.title, body: n.body, read: true, sentAt: n.sentAt) : n,
    ]);
  }

  Future<void> markAllRead() async {
    await ref.read(notificationRepositoryProvider).markAllRead();
    final items = state.valueOrNull;
    if (items == null) return;
    state = AsyncData([
      for (final n in items)
        NotificationItem(id: n.id, type: n.type, title: n.title, body: n.body, read: true, sentAt: n.sentAt),
    ]);
  }

  Future<void> delete(String id) async {
    await ref.read(notificationRepositoryProvider).deleteNotification(id);
    final items = state.valueOrNull;
    if (items == null) return;
    state = AsyncData(items.where((n) => n.id != id).toList());
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(notificationRepositoryProvider).listNotifications(),
    );
  }
}

final notificationsProvider = AsyncNotifierProvider<NotificationsNotifier, List<NotificationItem>>(
  NotificationsNotifier.new,
);

/// Category toggles, persisted locally (spec 2.10). Marketing is OFF by
/// default and independently controllable.
class NotificationPrefsNotifier extends Notifier<NotificationPrefs> {
  @override
  NotificationPrefs build() {
    final store = ref.watch(preferencesStoreProvider).valueOrNull;
    return store?.getNotificationPrefs() ?? const NotificationPrefs();
  }

  Future<void> set(NotificationPrefs prefs) async {
    state = prefs;
    final store = await ref.read(preferencesStoreProvider.future);
    await store.saveNotificationPrefs(prefs);
  }

  Future<void> toggleCategory(String category, bool value) async {
    await set(_withCategory(state, category, value));
  }

  NotificationPrefs _withCategory(NotificationPrefs prefs, String category, bool value) {
    switch (category) {
      case 'trip_reminder':
        return prefs.copyWith(tripReminder: value);
      case 'budget_warning':
        return prefs.copyWith(budgetWarning: value);
      case 'trip_status':
        return prefs.copyWith(tripStatus: value);
      case 'marketing':
        return prefs.copyWith(marketing: value);
      default:
        return prefs;
    }
  }
}

final notificationPrefsProvider = NotifierProvider<NotificationPrefsNotifier, NotificationPrefs>(
  NotificationPrefsNotifier.new,
);