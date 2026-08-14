import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../providers/profile_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/guest_gate.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _version;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = ref.watch(isLoggedInProvider);
    final profile = ref.watch(profileProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Profile'),
                    subtitle: Text(profile?.name ??
                        'Edit name, home location, travel preferences'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _requireLogin(context, ref,
                        () => context.push(AppRoutes.profileEdit)),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.notifications_none),
                    title: const Text('Notifications'),
                    subtitle:
                        const Text('Alert categories and marketing opt-out'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _requireLogin(context, ref,
                        () => context.push(AppRoutes.notifications)),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.shield_outlined,
                        color: AppColors.primary),
                    title: const Text('Admin'),
                    subtitle: const Text('Dashboard, flags, audit, support'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _requireLogin(
                        context, ref, () => context.push(AppRoutes.admin)),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.favorite_outline),
                    title: const Text('Favorites'),
                    subtitle:
                        const Text('Saved places, hotels, routes and trips'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _requireLogin(
                        context, ref, () => context.push(AppRoutes.favorites)),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.security_outlined),
                    title: const Text('Analytics'),
                    subtitle: Text(profile?.analyticsOptOut == true
                        ? 'Analytics opt-out is ON'
                        : 'Analytics opt-out is OFF'),
                    trailing: Switch(
                      value: profile?.analyticsOptOut != true,
                      onChanged: isLoggedIn
                          ? (v) => ref
                              .read(profileProvider.notifier)
                              .setAnalyticsOptOut(!v)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Privacy policy'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.privacy),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Terms of service'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.terms),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: const Text('Help & support'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.help),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.delete_forever_outlined,
                        color: AppColors.error),
                    title: const Text('Delete account'),
                    subtitle: const Text('Permanently removes your data'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _requireLogin(context, ref,
                        () => context.push(AppRoutes.deleteAccount)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Center(
              child: Text(
                'Route2Go v${_version ?? '…'}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _requireLogin(BuildContext context, WidgetRef ref, VoidCallback action) {
    if (!ref.read(isLoggedInProvider)) {
      showGuestGate(context);
      return;
    }
    action();
  }
}
