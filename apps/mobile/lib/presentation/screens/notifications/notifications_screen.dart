import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/notifications_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/guest_gate.dart';
import '../../../core/local/preferences_store.dart';
import '../../../domain/entities/notification_item.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(isLoggedInProvider);
    final prefs = ref.watch(notificationPrefsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (isLoggedIn)
            TextButton(
              onPressed: () =>
                  ref.read(notificationsProvider.notifier).markAllRead(),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: SafeArea(
        child: isLoggedIn
            ? ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  _PrefsCard(
                      prefs: prefs,
                      onChanged: (c, v) {
                        ref
                            .read(notificationPrefsProvider.notifier)
                            .toggleCategory(c, v);
                      }),
                  const SizedBox(height: AppSpacing.lg),
                  ref.watch(notificationsProvider).when(
                        loading: () => const AppLoadingState(
                            message: 'Loading notifications…'),
                        error: (err, st) => AppErrorState(
                          error: err,
                          onRetry: () => ref
                              .read(notificationsProvider.notifier)
                              .refresh(),
                        ),
                        data: (list) => _NotificationsList(
                          items: list,
                          onTap: (id) => ref
                              .read(notificationsProvider.notifier)
                              .markRead(id),
                          onDelete: (id) => ref
                              .read(notificationsProvider.notifier)
                              .delete(id),
                        ),
                      ),
                ],
              )
            : _GuestView(onSignIn: () => showGuestGate(context)),
      ),
    );
  }
}

class _GuestView extends StatelessWidget {
  const _GuestView({required this.onSignIn});
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_none,
                size: 44, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.md),
            const Text('Get reminders for upcoming trips and budget warnings.'),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
                onPressed: onSignIn,
                child: const Text('Sign in to get notifications')),
          ],
        ),
      ),
    );
  }
}

class _PrefsCard extends StatelessWidget {
  const _PrefsCard({required this.prefs, required this.onChanged});

  final NotificationPrefs prefs;
  final void Function(String category, bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Alert categories',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile(
              value: prefs.tripReminder,
              onChanged: (v) => onChanged('trip_reminder', v),
              title: const Text('Trip reminders'),
              subtitle: const Text('Upcoming trip and departure alerts'),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              value: prefs.budgetWarning,
              onChanged: (v) => onChanged('budget_warning', v),
              title: const Text('Budget warnings'),
              subtitle:
                  const Text('Alerts when a trip nears or passes its budget'),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              value: prefs.tripStatus,
              onChanged: (v) => onChanged('trip_status', v),
              title: const Text('Trip status updates'),
              subtitle: const Text('Status changes on saved trips'),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              value: prefs.marketing,
              onChanged: (v) => onChanged('marketing', v),
              title: const Text('Offers and updates'),
              subtitle: const Text(
                  'Optional marketing — off by default, and never required'),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsList extends StatelessWidget {
  const _NotificationsList(
      {required this.items, required this.onTap, required this.onDelete});

  final List<NotificationItem> items;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const AppEmptyState(
        message:
            'Nothing here yet — alerts will show up when there is trip news.',
        icon: Icons.notifications_none,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Messages', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        ...items.map((n) => Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ListTile(
                leading: Icon(_iconFor(n.type),
                    color:
                        n.read ? AppColors.textSecondary : AppColors.primary),
                title: Text(n.title ?? n.type,
                    style: Theme.of(context).textTheme.bodyLarge),
                subtitle: n.body != null
                    ? Text(n.body!,
                        style: Theme.of(context).textTheme.bodySmall)
                    : null,
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: 'Delete',
                  onPressed: () => onDelete(n.id),
                ),
                onTap: () => onTap(n.id),
              ),
            )),
      ],
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'trip_reminder':
        return Icons.event_note;
      case 'budget_warning':
        return Icons.warning_amber_outlined;
      case 'trip_status':
        return Icons.route_outlined;
      case 'marketing':
        return Icons.campaign_outlined;
      default:
        return Icons.notifications_none;
    }
  }
}
