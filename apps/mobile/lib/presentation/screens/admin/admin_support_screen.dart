import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/app_widgets.dart';

/// Support ticket triage (spec 2.13). Status changes go through the EF which
/// audits the write and requires the 'super_admin' role.
class AdminSupportScreen extends ConsumerWidget {
  const AdminSupportScreen({super.key});

  static const _statuses = ['open', 'in_progress', 'resolved', 'closed'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(adminSessionProvider).valueOrNull;
    final tickets = ref.watch(adminSupportProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Support tickets')),
      body: SafeArea(
        child: tickets.when(
          loading: () => const AppLoadingState(),
          error: (err, st) => AppErrorState(error: err),
          data: (list) {
            if (list.isEmpty) {
              return const AppEmptyState(
                message: 'No support tickets.',
                icon: Icons.support_agent,
              );
            }
            final canWrite = session?.isSuper ?? false;
            return ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final t = list[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ExpansionTile(
                    leading: Icon(_iconFor(t.status), color: _colorFor(t.status)),
                    title: Text(t.subject),
                    subtitle: Text('${t.status} · ${t.userId ?? 'anon'}'),
                    childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.message, style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: AppSpacing.md),
                      if (canWrite)
                        DropdownButton<String>(
                          value: t.status,
                          isExpanded: true,
                          items: _statuses
                              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                              .toList(),
                          onChanged: (next) {
                            if (next != null) {
                              ref.read(adminSupportProvider.notifier).updateStatus(t.id, next);
                            }
                          },
                        )
                      else
                        Text(
                          'Read-only — Super Admin role required to change status.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  IconData _iconFor(String status) {
    switch (status) {
      case 'resolved':
        return Icons.check_circle_outline;
      case 'closed':
        return Icons.cancel_outlined;
      case 'in_progress':
        return Icons.schedule;
      default:
        return Icons.markunread_mailbox_outlined;
    }
  }

  Color _colorFor(String status) {
    switch (status) {
      case 'resolved':
        return AppColors.success;
      case 'closed':
        return AppColors.textSecondary;
      case 'in_progress':
        return AppColors.warning;
      default:
        return AppColors.error;
    }
  }
}