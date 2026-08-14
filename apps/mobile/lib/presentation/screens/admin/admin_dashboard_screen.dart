import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/app_widgets.dart';

/// Admin dashboard landing (spec 2.13). Shows stat cards and links to the
/// per-module screens. All data comes from the /admin Edge Function, which
/// gates each read on a verified admin_users row.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(adminSessionProvider).valueOrNull;

    if (session == null || !session.isAdmin) {
      return const AdminLockedScreen();
    }

    final stats = ref.watch(adminStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.read(adminStatsProvider.notifier).refresh(),
          ),
        ],
      ),
      body: SafeArea(
        child: stats.when(
          loading: () => const AppLoadingState(message: 'Loading admin…'),
          error: (err, st) => AppErrorState(error: err),
          data: (s) => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_outlined, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Role: ${session.role}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                childAspectRatio: 1.6,
                children: [
                  _StatCard(icon: Icons.route_outlined, label: 'Trips', value: '${s.trips}'),
                  _StatCard(icon: Icons.person_outline, label: 'Users', value: '${s.users}'),
                  _StatCard(icon: Icons.support_agent, label: 'Open tickets', value: '${s.openSupportTickets}'),
                  _StatCard(icon: Icons.monetization_on_outlined, label: 'Affiliate clicks', value: '${s.affiliateClicks}'),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Modules', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              _ModuleTile(
                icon: Icons.flag_outlined,
                title: 'Feature flags',
                subtitle: 'Toggle phase-2 experiments',
                onTap: () => context.push(AppRoutes.adminFlags),
              ),
              _ModuleTile(
                icon: Icons.receipt_long_outlined,
                title: 'Audit log',
                subtitle: 'Every privileged write, every actor',
                onTap: () => context.push(AppRoutes.adminAudit),
              ),
              _ModuleTile(
                icon: Icons.support_agent,
                title: 'Support tickets',
                subtitle: 'Open, triage and resolve requests',
                onTap: () => context.push(AppRoutes.adminSupport),
              ),
              _ModuleTile(
                icon: Icons.monetization_on_outlined,
                title: 'Affiliate',
                subtitle: 'Partner click summary',
                onTap: () => context.push(AppRoutes.adminAffiliate),
              ),
              _ModuleTile(
                icon: Icons.group_outlined,
                title: 'Users',
                subtitle: 'Account directory search',
                onTap: () => context.push(AppRoutes.adminUsers),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminLockedScreen extends StatelessWidget {
  const AdminLockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: AppEmptyState(
            message: 'Admin access required.',
            icon: Icons.lock_outline,
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const Spacer(),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}