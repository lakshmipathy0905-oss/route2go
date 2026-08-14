import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/app_widgets.dart';

/// Affiliate click summary for the last 30 days (spec 2.13). Groups clicks by
/// partner id so finance/content can see which stays drive revenue.
class AdminAffiliateScreen extends ConsumerWidget {
  const AdminAffiliateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(adminAffiliateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Affiliate')),
      body: SafeArea(
        child: summary.when(
          loading: () => const AppLoadingState(),
          error: (err, st) => AppErrorState(error: err),
          data: (s) {
            final partners = s.byPartner.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      children: [
                        const Icon(Icons.monetization_on_outlined, color: AppColors.primary, size: 28),
                        const SizedBox(width: AppSpacing.md),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${s.total}',
                                style: Theme.of(context).textTheme.headlineSmall),
                            Text('Clicks · last ${s.days} days',
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('By partner', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.sm),
                if (partners.isEmpty)
                  const AppEmptyState(message: 'No clicks in this window.', icon: Icons.trending_down)
                else
                  ...partners.map((e) => Card(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: ListTile(
                          leading: const Icon(Icons.storefront_outlined, color: AppColors.primary),
                          title: Text(e.key == 'unknown' ? 'Unknown partner' : 'Partner ${e.key}'),
                          trailing: Text('${e.value}', style: Theme.of(context).textTheme.titleMedium),
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