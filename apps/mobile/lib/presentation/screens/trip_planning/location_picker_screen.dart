import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/local/preferences_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/geocoding_repository.dart';
import '../../../domain/entities/geo.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/permission_explainer.dart';

/// Map-pin + search location picker (spec 2.2). Replaces the manual lat/lng
/// fields in PlanTrip. Returns a [GeoPlace] via Navigator.pop when the user
/// confirms a spot.
class LocationPickerScreen extends ConsumerStatefulWidget {
  const LocationPickerScreen({super.key, required this.target});

  final String target; // 'origin' | 'destination'

  @override
  ConsumerState<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends ConsumerState<LocationPickerScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  bool _searching = false;
  bool _searchFailed = false;
  String? _searchError;
  List<GeoPlace> _results = const [];
  bool _searched = false;

  LatLng _pinCenter = const LatLng(12.9716, 77.5946); // Bengaluru default
  double _zoom = 5;
  bool _locating = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.target == 'origin' ? 'Choose Starting Point' : 'Choose Destination')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onQueryChanged,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  labelText: 'Search a place or address',
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(AppSpacing.md),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtrl.clear();
                            _onQueryChanged('');
                          },
                        ),
                ),
              ),
            ),
            if (_searchFailed)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: AppErrorState(
                  error: _searchError ?? 'Search failed.',
                  onRetry: () => _onQueryChanged(_searchCtrl.text),
                ),
              )
            else if (_searched && !_searching && _results.isEmpty)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: AppEmptyState(
                  message: 'No places matched. Drag the map pin to set an exact spot instead.',
                  icon: Icons.location_off_outlined,
                ),
              )
            else if (!_searching && _results.isEmpty)
              _RecentsSection(
                onPick: (loc) => _confirm(loc.label, loc.lat, loc.lng),
                onUseGps: _useGps,
              ),
            if ((_searched || _searching) && _results.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 160),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (context, i) {
                    final r = _results[i];
                    return ListTile(
                      leading: const Icon(Icons.place_outlined, color: AppColors.primary),
                      title: Text(r.label),
                      subtitle: r.subtitle != null ? Text(r.subtitle!) : null,
                      onTap: () => _confirm(r.label, r.lat, r.lng),
                    );
                  },
                ),
              ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: _pinCenter,
                    initialZoom: _zoom,
                    onTap: (tapPos, latLng) => setState(() {
                      _pinCenter = latLng;
                      _zoom = 12;
                    }),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.route2go.route2go',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _pinCenter,
                          width: 44,
                          height: 44,
                          child: const Icon(Icons.location_pin, size: 44, color: AppColors.error),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _locating ? null : _useGps,
                      icon: _locating
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.my_location),
                      label: const Text('Use my location'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final geo = await ref.read(geocodingRepositoryProvider).reverseGeocode(
                              _pinCenter.latitude,
                              _pinCenter.longitude,
                            );
                        if (mounted) {
                          _confirm(
                            geo?.label ?? 'Selected point ${_pinCenter.latitude.toStringAsFixed(4)}, ${_pinCenter.longitude.toStringAsFixed(4)}',
                            _pinCenter.latitude,
                            _pinCenter.longitude,
                          );
                        }
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Use this spot'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    setState(() {
      _searched = q.trim().isNotEmpty;
      _searchFailed = false;
      _searchError = null;
      if (q.trim().length < 2) {
        _results = const [];
        _searching = false;
      }
    });
    if (q.trim().length < 2) return;
    _debounce = Timer(const Duration(milliseconds: 350), () => _runSearch(q));
  }

  Future<void> _runSearch(String q) async {
    setState(() {
      _searching = true;
      _searchFailed = false;
    });
    try {
      final results = await ref.read(geocodingRepositoryProvider).geocode(q);
      if (!mounted || _searchCtrl.text.trim() != q) return;
      setState(() {
        _results = results;
        _searching = false;
        _searched = true;
      });
      if (results.isNotEmpty) {
        setState(() => _pinCenter = LatLng(results.first.lat, results.first.lng));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchFailed = true;
        _searchError = 'Search is temporarily unavailable.';
      });
    }
  }

  Future<void> _useGps() async {
    final explainer = PermissionExplainer(
      icon: Icons.gps_fixed,
      title: 'Use your current location',
      reasons: const [
        'Set the route start point exactly where you are.',
        'Find places and stays near your route.',
        'Location is only used while you are picking or planning a route.',
      ],
      permissionLabel: 'Allow location',
      onRequest: () => Navigator.of(context).pop(),
    );
    await explainer.showModal(context);

    setState(() => _locating = true);
    final place = await ref.read(geocodingRepositoryProvider).deviceLocation();
    if (!mounted) return;
    setState(() => _locating = false);
    if (place == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location is unavailable. You can search above or drag the map pin instead.'),
        ),
      );
      return;
    }
    setState(() {
      _pinCenter = LatLng(place.lat, place.lng);
      _zoom = 12;
    });
    _confirm('Current location', place.lat, place.lng);
  }

  void _confirm(String label, double lat, double lng) {
    final store = ref.read(preferencesStoreProvider).valueOrNull;
    if (store != null) {
      store.upsertRecentLocation(RecentLocation(label: label, lat: lat, lng: lng, usedAt: DateTime.now()));
    }
    Navigator.pop(context, GeoPlace(label: label, lat: lat, lng: lng));
  }
}

class _RecentsSection extends StatelessWidget {
  const _RecentsSection({required this.onPick, required this.onUseGps});

  final void Function(RecentLocation) onPick;
  final VoidCallback? onUseGps;

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, _) {
      final store = ref.watch(preferencesStoreProvider).valueOrNull;
      final recents = store?.getRecentLocations() ?? const <RecentLocation>[];
      if (recents.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Text(
            'Search above, or drag the map pin to set an exact point.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
            child: Text('Recent locations', style: Theme.of(context).textTheme.headlineSmall),
          ),
          Container(
            constraints: const BoxConstraints(maxHeight: 150),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: recents.length,
              itemBuilder: (context, i) {
                final loc = recents[i];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.history, size: 20),
                  title: Text(loc.label),
                  onTap: () => onPick(loc),
                );
              },
            ),
          ),
        ],
      );
    });
  }
}