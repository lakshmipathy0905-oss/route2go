import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../domain/entities/trip_summary.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/trip_planning_provider.dart';
import '../../providers/trips_provider.dart';
import '../book/book_screen.dart' show bookModeProvider;
import '../../widgets/brand_widgets.dart';
import '../../widgets/guest_gate.dart';
import '../../widgets/sharing_widgets.dart' show SectionHeader;

/// Home dashboard (spec Section 6): hero journey search, quick booking cards,
/// smart suggestions and recent trips — the new landing tab for `/home`.
class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(isLoggedInProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final trips = ref.watch(tripsProvider).valueOrNull ?? const <TripSummary>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            if (isLoggedIn) {
              // ignore: unused_result
              await ref.refresh(tripsProvider.future);
            }
          },
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _DashboardHeader(
                name: profile?.name,
                isLoggedIn: isLoggedIn,
              ),
              const _HeroSearchCard(),
              const SizedBox(height: AppSpacing.xl),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: SectionHeader(
                  title: 'Book your journey',
                  trailing: TextButton(
                    onPressed: () => context.go(AppRoutes.book),
                    child: const Text('View all'),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const _BookModes(),
              const SizedBox(height: AppSpacing.xl),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: SectionHeader(
                  title: 'Quick access',
                  trailing: TextButton(
                    onPressed: () => context.push(AppRoutes.map),
                    child: const Text('Open map'),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: _QuickActions(isLoggedIn: isLoggedIn),
              ),
              const SizedBox(height: AppSpacing.xl),
              const _SuggestedDestinations(),
              const SizedBox(height: AppSpacing.xl),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: SectionHeader(
                  title: 'Recent trips',
                  trailing: TextButton(
                    onPressed: () {
                      if (!isLoggedIn) {
                        showGuestGate(context);
                        return;
                      }
                      context.go(AppRoutes.trips);
                    },
                    child: const Text('See all'),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: _RecentTrips(isLoggedIn: isLoggedIn, trips: trips),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

/// Branded header: wordmark + slogan on the left, notification + avatar.
class _DashboardHeader extends ConsumerWidget {
  const _DashboardHeader({this.name, required this.isLoggedIn});

  final String? name;
  final bool isLoggedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
      child: Row(
        children: [
          const BrandWordmark(size: 22, showGlyph: true),
          const Spacer(),
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search),
            onPressed: () => context.push(AppRoutes.search),
          ),
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_none),
            onPressed: () {
              if (!isLoggedIn) {
                showGuestGate(context);
                return;
              }
              context.push(AppRoutes.notifications);
            },
          ),
          const SizedBox(width: AppSpacing.xs),
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            onTap: () => context.go(AppRoutes.profile),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primarySoft,
              child: Icon(
                isLoggedIn ? Icons.person : Icons.person_outline,
                color: AppColors.primary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hero "Where do you want to go?" card — launches the Plan Trip journey.
class _HeroSearchCard extends ConsumerWidget {
  const _HeroSearchCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(tripPlanningFormProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.accent],
          ),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadows.float,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            onTap: () => context.push(AppRoutes.planTrip),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Where do you want to go?',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Plan your journey — places, stays, transport and budget in one place.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _HeroField(
                    icon: Icons.trip_origin,
                    label: form.originLabel ?? 'From',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _HeroField(
                    icon: Icons.place_outlined,
                    label: form.destinationLabel ?? 'To',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      const Expanded(
                        child: _HeroField(
                          icon: Icons.calendar_today_outlined,
                          label: 'Pick a date',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _HeroField(
                          icon: Icons.group_outlined,
                          label:
                              '${form.travellers} traveller${form.travellers == 1 ? '' : 's'}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        minimumSize: const Size.fromHeight(52),
                      ),
                      onPressed: () => context.push(AppRoutes.planTrip),
                      icon: const Icon(Icons.search),
                      label: const Text('Plan a Trip'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroField extends StatelessWidget {
  const _HeroField({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// Train / Bus / Flight booking cards with honest provider-gated behavior.
class _BookModes extends ConsumerWidget {
  const _BookModes();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modes = [
      (
        'Train',
        Icons.train_outlined,
        AppColors.train,
        AppColors.trainSoft,
        'IRCTC'
      ),
      (
        'Bus',
        Icons.directions_bus_outlined,
        AppColors.bus,
        AppColors.busSoft,
        'RedBus'
      ),
      (
        'Flight',
        Icons.flight_takeoff,
        AppColors.flight,
        AppColors.flightSoft,
        'Compare fares'
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: modes.map((m) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: _ModeCard(
                label: m.$1,
                icon: m.$2,
                color: m.$3,
                soft: m.$4,
                caption: m.$5,
                onTap: () {
                  ref.read(bookModeProvider.notifier).state =
                      m.$1.toLowerCase();
                  context.go(AppRoutes.book);
                },
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.soft,
    required this.caption,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color soft;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: soft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(label, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quick access grid: Plan a Trip, Explore, Map, Favorites.
class _QuickActions extends ConsumerWidget {
  const _QuickActions({required this.isLoggedIn});

  final bool isLoggedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = <(IconData, String, VoidCallback)>[
      (Icons.add_road, 'New Trip', () => context.push(AppRoutes.planTrip)),
      (Icons.explore_outlined, 'Explore', () => context.go(AppRoutes.explore)),
      (Icons.map_outlined, 'Map', () => context.push(AppRoutes.map)),
      (
        Icons.favorite_outline,
        'Favorites',
        () {
          if (!isLoggedIn) {
            showGuestGate(context);
            return;
          }
          context.push(AppRoutes.favorites);
        }
      ),
    ];

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 0.86,
      children: actions.map((a) {
        return Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: a.$3,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(a.$1, color: AppColors.primary, size: 26),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    a.$2,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Honest "suggested for you" — real destinations, clearly labeled as ideas,
/// never fabricated prices or availability (spec Sections 4/16).
class _SuggestedDestinations extends StatelessWidget {
  const _SuggestedDestinations();

  static const _cities = [
    ('Goa', 'Beaches & sunsets', Icons.beach_access_outlined),
    ('Jaipur', 'Heritage & palaces', Icons.account_balance_outlined),
    ('Munnar', 'Hills & tea gardens', Icons.forest_outlined),
    ('Shimla', 'Mountain escapes', Icons.terrain_outlined),
    ('Pondicherry', 'Coastal charm', Icons.waves_outlined),
    ('Rishikesh', 'Rivers & adventure', Icons.landscape_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: SectionHeader(
            title: 'Suggested for you',
            trailing: TextButton(
              onPressed: () => context.go(AppRoutes.explore),
              child: const Text('Explore'),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 148,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            itemCount: _cities.length,
            separatorBuilder: (_, i) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, i) {
              final (name, tag, icon) = _cities[i];
              return _SuggestionCard(name: name, tag: tag, icon: icon);
            },
          ),
        ),
      ],
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.name,
    required this.tag,
    required this.icon,
  });

  final String name;
  final String tag;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => context.push(AppRoutes.planTrip),
        child: Container(
          width: 168,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primaryDark],
            ),
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
          ),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Icon(icon, color: Colors.white, size: 26),
              const Spacer(),
              Text(
                name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                tag,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentTrips extends StatelessWidget {
  const _RecentTrips({required this.isLoggedIn, required this.trips});

  final bool isLoggedIn;
  final List<TripSummary> trips;

  @override
  Widget build(BuildContext context) {
    if (!isLoggedIn) {
      return _DashCard(
        icon: Icons.lock_outline,
        title: 'Sign in to see your trips',
        subtitle: 'Saved trips are private to your account.',
        onTap: () => showGuestGate(context),
      );
    }
    if (trips.isEmpty) {
      return _DashCard(
        icon: Icons.route_outlined,
        title: 'No trips yet',
        subtitle: 'Plan your first adventure and it will appear here.',
        onTap: () => context.push(AppRoutes.planTrip),
      );
    }
    return Column(
      children: trips.take(2).map((t) {
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
              child: const Icon(Icons.route_outlined,
                  color: AppColors.primary, size: 20),
            ),
            title: Text(
              '${t.originLabel} → ${t.destinationLabel}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(t.status),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.tripDetailOf(t.id)),
          ),
        );
      }).toList(),
    );
  }
}

class _DashCard extends StatelessWidget {
  const _DashCard({
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
