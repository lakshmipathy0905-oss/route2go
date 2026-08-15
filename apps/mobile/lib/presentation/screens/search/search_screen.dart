import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../providers/favorites_search_provider.dart';
import '../../widgets/app_widgets.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  bool _hasQuery = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        actions: [
          if (_hasQuery)
            TextButton(
                onPressed: () => _ctrl.clear(), child: const Text('Clear'))
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                onChanged: (q) {
                  setState(() => _hasQuery = q.trim().isNotEmpty);
                  _debounce?.cancel();
                  if (q.trim().length < 2) return;
                  _debounce = Timer(const Duration(milliseconds: 300), () {
                    ref.read(searchProvider.notifier).search(q);
                  });
                },
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Places, hotels, routes, saved trips',
                ),
              ),
            ),
            Expanded(
              child: ref.watch(searchProvider).when(
                    loading: () => const AppLoadingState(message: 'Searching…'),
                    error: (err, st) => AppErrorState(error: err),
                    data: (response) {
                      if (_ctrl.text.trim().length < 2) {
                        return const AppEmptyState(
                          message:
                              'Type at least 2 characters to search across your saved data.',
                          icon: Icons.search,
                        );
                      }
                      if (response.results.isEmpty) {
                        // Never read "provider unavailable" as "no matches":
                        // a degraded nearby search gets an honest message.
                        if (response.nearbyDegraded) {
                          return const AppEmptyState(
                            message:
                                'Nearby places are unavailable right now. Try again in a moment, or search a place name.',
                            icon: Icons.cloud_off,
                          );
                        }
                        return const AppEmptyState(
                          message: 'No matches found.',
                          icon: Icons.search_off,
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        itemCount: response.results.length,
                        itemBuilder: (context, i) {
                          final r = response.results[i];
                          return ListTile(
                            leading: Icon(_iconFor(r.kind),
                                color: AppColors.primary),
                            title: Text(r.title),
                            subtitle: Text(
                                '${_labelFor(r.kind)} · ${r.subtitle}',
                                style: Theme.of(context).textTheme.bodySmall),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _open(r.kind, r.id),
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

  IconData _iconFor(String kind) {
    switch (kind) {
      case 'place':
      case 'nearby':
        return Icons.place_outlined;
      case 'hotel':
        return Icons.hotel_outlined;
      case 'route':
        return Icons.route_outlined;
      case 'saved_trip':
        return Icons.bookmark_outline;
      default:
        return Icons.search;
    }
  }

  String _labelFor(String kind) {
    switch (kind) {
      case 'place':
      case 'nearby':
        return 'Place';
      case 'hotel':
        return 'Hotel';
      case 'route':
        return 'Route';
      case 'saved_trip':
        return 'Saved trip';
      default:
        return kind;
    }
  }

  void _open(String kind, String id) {
    switch (kind) {
      case 'place':
        context.push(AppRoutes.placeDetailOf(id));
        break;
      case 'saved_trip':
        context.push(AppRoutes.tripDetailOf(id));
        break;
      case 'nearby':
        // A worldwide address/POI result — start planning a route to it.
        context.push(AppRoutes.planTrip);
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opening $_labelFor(kind)…')),
        );
    }
  }
}
