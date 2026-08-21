import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/trips_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../widgets/guest_gate.dart';
import '../../widgets/phase2_gate.dart';
import '../../widgets/sharing_widgets.dart' show SectionHeader;

/// Profile tab (spec Section 7/8): identity header, journey stats and the
/// account menu. Guest mode stays supported — account-only actions gate.
class ProfileTabScreen extends ConsumerWidget {
  const ProfileTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(isLoggedInProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final trips = ref.watch(tripsProvider).valueOrNull ?? const [];
    final vehicles = ref.watch(vehicleListProvider).valueOrNull ?? const [];

    final name = profile?.name ?? (isLoggedIn ? 'Route2Go traveller' : 'Guest');
    final homeLabel = profile?.homeLocationLabel;
    final travelPrefLabel = switch (profile?.travelPref) {
      'budget' => 'Budget travel',
      'premium' => 'Premium travel',
      _ => 'Balanced travel',
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _ProfileHeader(
              name: name,
              subtitle: isLoggedIn
                  ? (homeLabel == null
                      ? travelPrefLabel
                      : '$travelPrefLabel · $homeLabel')
                  : 'Browsing as a guest',
              isLoggedIn: isLoggedIn,
            ),
            const SizedBox(height: AppSpacing.lg),
            _StatsRow(trips: trips.length, vehicles: vehicles.length),
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(
              title: 'My travel',
              trailing: TextButton(
                onPressed: () {
                  if (!isLoggedIn) {
                    showGuestGate(context);
                    return;
                  }
                  context.push(AppRoutes.vehicles);
                },
                child: const Text('Manage'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _MenuTile(
              icon: Icons.directions_car_outlined,
              title: 'My Vehicles',
              subtitle: 'Add vehicles to pre-fill trip costs',
              onTap: () {
                if (!isLoggedIn) {
                  showGuestGate(context);
                  return;
                }
                context.push(AppRoutes.vehicles);
              },
            ),
            _MenuTile(
              icon: Icons.favorite_outline,
              title: 'Favorites',
              subtitle: 'Places, stays and searches you saved',
              onTap: () {
                if (!isLoggedIn) {
                  showGuestGate(context);
                  return;
                }
                context.push(AppRoutes.favorites);
              },
            ),
            const Phase2Gate(
              flagKey: 'phase2_offline',
              title: 'Offline route packages',
              subtitle: 'Download routes and places for offline use',
              icon: Icons.cloud_off_outlined,
              child: SizedBox.shrink(),
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader(title: 'Support & legal'),
            const SizedBox(height: AppSpacing.sm),
            _MenuTile(
              icon: Icons.notifications_none,
              title: 'Notifications & preferences',
              subtitle: 'Reminders, budget alerts and trip updates',
              onTap: () {
                if (!isLoggedIn) {
                  showGuestGate(context);
                  return;
                }
                context.push(AppRoutes.notifications);
              },
            ),
            _MenuTile(
              icon: Icons.help_outline,
              title: 'Help & support',
              subtitle: 'FAQs and contact options',
              onTap: () => context.push(AppRoutes.help),
            ),
            _MenuTile(
              icon: Icons.shield_outlined,
              title: 'Privacy policy',
              subtitle: 'How we handle your data',
              onTap: () => context.push(AppRoutes.privacy),
            ),
            _MenuTile(
              icon: Icons.description_outlined,
              title: 'Terms of service',
              subtitle: 'The rules of using Route2Go',
              onTap: () => context.push(AppRoutes.terms),
            ),
            const SizedBox(height: AppSpacing.md),
            Card(
              color: AppColors.surfaceAlt,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined,
                        size: 18, color: AppColors.success),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Your data is encrypted and never sold.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({
    required this.name,
    required this.subtitle,
    required this.isLoggedIn,
  });

  final String name;
  final String subtitle;
  final bool isLoggedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: AppColors.primarySoft,
          child: Icon(
            isLoggedIn ? Icons.person : Icons.person_outline,
            color: AppColors.primary,
            size: 28,
          ),
        ),
        title: Text(name, style: Theme.of(context).textTheme.titleLarge),
        subtitle: Text(
          subtitle,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
        trailing: isLoggedIn
            ? TextButton(
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
                child: const Text('Sign out'),
              )
            : TextButton(
                onPressed: () => context.push(AppRoutes.login),
                child: const Text('Sign in'),
              ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.trips, required this.vehicles});

  final int trips;
  final int vehicles;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(
          value: '$trips',
          label: 'Trips',
          icon: Icons.route_outlined,
          onTap: () => context.go(AppRoutes.trips),
        ),
        const SizedBox(width: AppSpacing.md),
        _StatCard(
          value: '$vehicles',
          label: 'Vehicles',
          icon: Icons.directions_car_outlined,
          onTap: () => context.push(AppRoutes.vehicles),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String value;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Icon(icon, color: AppColors.primary, size: 22),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
