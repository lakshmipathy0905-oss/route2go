import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../widgets/app_widgets.dart';

class _Destination {
  const _Destination(this.name, this.state, this.category, this.tag, this.icon);
  final String name;
  final String state;
  final String category;
  final String tag;
  final IconData icon;
}

const _categories = [
  'All',
  'Heritage',
  'Beaches',
  'Hills',
  'Adventure',
  'Cities'
];

const _destinations = [
  _Destination('Jaipur', 'Rajasthan', 'Heritage', 'Palaces, forts & bazaars',
      Icons.account_balance_outlined),
  _Destination('Goa', 'Goa', 'Beaches', 'Beaches & sunsets',
      Icons.beach_access_outlined),
  _Destination('Munnar', 'Kerala', 'Hills', 'Tea gardens & misty hills',
      Icons.forest_outlined),
  _Destination('Shimla', 'Himachal Pradesh', 'Hills', 'Mountain escapes',
      Icons.terrain_outlined),
  _Destination('Rishikesh', 'Uttarakhand', 'Adventure', 'Rafting & rivers',
      Icons.landscape_outlined),
  _Destination('Pondicherry', 'Puducherry', 'Beaches', 'Coastal charm',
      Icons.waves_outlined),
  _Destination('Agra', 'Uttar Pradesh', 'Heritage', 'The Taj Mahal',
      Icons.temple_buddhist_outlined),
  _Destination('Manali', 'Himachal Pradesh', 'Adventure',
      'Himalayan adventures', Icons.hiking_outlined),
  _Destination('Mumbai', 'Maharashtra', 'Cities', 'City lights & coast',
      Icons.location_city_outlined),
  _Destination('Bengaluru', 'Karnataka', 'Cities', 'Gardens & tech hub',
      Icons.location_city_outlined),
];

/// Explore tab (spec Section 7/9): real destinations, honest suggestions.
/// No fabricated photos — cards use branded art placeholders.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  String _category = 'All';

  List<_Destination> get _visible => _category == 'All'
      ? _destinations
      : _destinations.where((d) => d.category == _category).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Explore'),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search),
            onPressed: () => context.push(AppRoutes.search),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                'Find your next destination',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                itemCount: _categories.length,
                separatorBuilder: (_, i) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, i) {
                  final c = _categories[i];
                  final selected = c == _category;
                  return ChoiceChip(
                    label: Text(c),
                    selected: selected,
                    onSelected: (_) => setState(() => _category = c),
                    showCheckmark: false,
                    selectedColor: AppColors.primarySoft,
                    labelStyle: TextStyle(
                      color: selected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: _visible.isEmpty
                  ? const AppEmptyState(
                      icon: Icons.search_off_outlined,
                      title: 'No destinations',
                      message: 'Try a different category.',
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: AppSpacing.md,
                        crossAxisSpacing: AppSpacing.md,
                        childAspectRatio: 0.86,
                      ),
                      itemCount: _visible.length,
                      itemBuilder: (context, i) =>
                          _DestinationCard(dest: _visible[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DestinationCard extends StatelessWidget {
  const _DestinationCard({required this.dest});

  final _Destination dest;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => context.push(AppRoutes.planTrip),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.accent],
                    ),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppRadius.lg),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -18,
                        bottom: -18,
                        child: Icon(
                          dest.icon,
                          size: 96,
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                              ),
                              child: Text(
                                dest.category,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dest.name,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      dest.tag,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      dest.state,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: AppColors.accentDark),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
