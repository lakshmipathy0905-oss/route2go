import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/app_widgets.dart';

/// Feature-flag management (spec 2.13). Writes require the 'super_admin' role
/// server-side; the flag toggles are disabled for lower roles.
class AdminFlagsScreen extends ConsumerWidget {
  const AdminFlagsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(adminSessionProvider).valueOrNull;
    final flags = ref.watch(adminFlagsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Feature flags')),
      body: SafeArea(
        child: flags.when(
          loading: () => const AppLoadingState(),
          error: (err, st) => AppErrorState(error: err),
          data: (list) {
            if (list.isEmpty) {
              return const AppEmptyState(
                message: 'No feature flags configured yet.',
                icon: Icons.flag_outlined,
              );
            }
            final canWrite = session?.isSuper ?? false;
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                if (!canWrite)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Text(
                      'Read-only — Super Admin role required to change flags.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                ...list.map((f) => Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: SwitchListTile(
                        value: f.enabled,
                        onChanged: canWrite
                            ? (v) => ref.read(adminFlagsProvider.notifier).setFlag(f.key, v)
                            : null,
                        title: Text(f.key),
                        subtitle: Text(f.description),
                      ),
                    )),
              ],
            );
          },
        ),
      ),
    );
  }
}