import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../providers/favorites_search_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/guest_gate.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  String? _kind; // null = all, else place|hotel|route|trip

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(isLoggedInProvider)) {
        ref.read(favoritesProvider.notifier).load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = ref.watch(isLoggedInProvider);
    if (!isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Favorites')),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.favorite_outline, size: 44, color: AppColors.textSecondary),
                  const SizedBox(height: AppSpacing.md),
                  const Text('Sign in to keep your favorite places and trips.'),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton(onPressed: () => showGuestGate(context), child: const Text('Sign in')),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 8),
                children: [
                  ChoiceChip(label: const Text('All'), selected: _kind == null, onSelected: (_) => _setKind(null)),
                  const SizedBox(width: AppSpacing.sm),
                  ChoiceChip(label: const Text('Places'), selected: _kind == 'place', onSelected: (_) => _setKind('place')),
                  const SizedBox(width: AppSpacing.sm),
                  ChoiceChip(label: const Text('Hotels'), selected: _kind == 'hotel', onSelected: (_) => _setKind('hotel')),
                  const SizedBox(width: AppSpacing.sm),
                  ChoiceChip(label: const Text('Routes'), selected: _kind == 'route', onSelected: (_) => _setKind('route')),
                  const SizedBox(width: AppSpacing.sm),
                  ChoiceChip(label: const Text('Trips'), selected: _kind == 'trip', onSelected: (_) => _setKind('trip')),
                ],
              ),
            ),
            Expanded(
              child: ref.watch(favoritesProvider).when(
                    loading: () => const AppLoadingState(message: 'Loading favorites…'),
                    error: (err, st) => AppErrorState(
                      error: err,
                      onRetry: () => ref.read(favoritesProvider.notifier).refresh(),
                    ),
                    data: (items) {
                      if (items.isEmpty) {
                        return const AppEmptyState(
                          message: 'Nothing saved yet — bookmark places and trips as you plan.',
                          icon: Icons.favorite_border,
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final f = items[i];
                          return ListTile(
                            leading: Icon(_iconFor(f.kind), color: AppColors.primary),
                            title: Text(f.title),
                            subtitle: Text(f.subtitle, style: Theme.of(context).textTheme.bodySmall),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              if (f.kind == 'place') {
                                context.push(AppRoutes.placeDetailOf(f.id));
                              } else if (f.kind == 'saved_trip') {
                                context.push(AppRoutes.tripDetailOf(f.id));
                              }
                            },
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

  void _setKind(String? kind) {
    setState(() => _kind = kind);
    ref.read(favoritesProvider.notifier).load(kind: kind);
  }

  IconData _iconFor(String kind) {
    switch (kind) {
      case 'place':
        return Icons.place_outlined;
      case 'hotel':
        return Icons.hotel_outlined;
      case 'route':
        return Icons.route_outlined;
      case 'saved_trip':
        return Icons.bookmark_outline;
      default:
        return Icons.favorite_outline;
    }
  }
}