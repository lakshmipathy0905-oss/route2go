import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/app_widgets.dart';

/// Account directory search (spec 2.13). Server-gated to the 'super_admin' role.
class AdminUsersScreen extends ConsumerWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(adminUsersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: TextField(
                onSubmitted: (q) => ref.read(adminUsersProvider.notifier).search(q.trim()),
                decoration: InputDecoration(
                  hintText: 'Search by email or phone…',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            Expanded(
              child: users.when(
                loading: () => const AppLoadingState(),
                error: (err, st) => AppErrorState(error: err),
                data: (list) {
                  if (list.isEmpty) {
                    return const AppEmptyState(
                      message: 'No matching users.',
                      icon: Icons.group_off_outlined,
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final u = list[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: ListTile(
                          leading: const Icon(Icons.person_outline, color: AppColors.primary),
                          title: Text(u.email ?? u.phone ?? u.id),
                          subtitle: Text(
                            '${u.authProvider ?? 'unknown'} · ${u.id}\n'
                            'Created ${u.createdAt?.toLocal().toString().substring(0, 10) ?? '—'}',
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}