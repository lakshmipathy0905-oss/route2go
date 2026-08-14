import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/app_widgets.dart';

/// Read-only audit trail of every privileged write (spec 2.13 — "every write
/// goes to public.audit_logs"). Ordering is newest-first; the EF caps at 500.
class AdminAuditScreen extends ConsumerWidget {
  const AdminAuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(adminAuditProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(adminAuditProvider.notifier).refresh(),
          ),
        ],
      ),
      body: SafeArea(
        child: entries.when(
          loading: () => const AppLoadingState(),
          error: (err, st) => AppErrorState(error: err),
          data: (list) {
            if (list.isEmpty) {
              return const AppEmptyState(
                message: 'No audit entries yet.',
                icon: Icons.receipt_long_outlined,
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final e = list[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ListTile(
                    leading: const Icon(Icons.history, color: AppColors.primary),
                    title: Text(e.action, style: Theme.of(context).textTheme.bodyLarge),
                    subtitle: Text(
                      '${e.actorFirebaseUid ?? 'system'} · ${e.entityType}'
                      '${e.entityId != null ? ' · $e.entityId' : ''}\n'
                      '${_fmt(e.createdAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    isThreeLine: true,
                    trailing: e.afterSummary != null
                        ? const Icon(Icons.schedule, size: 16, color: AppColors.textSecondary)
                        : null,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')} '
        '${local.year} $hh:$mm';
  }
}