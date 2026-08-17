import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:route2go/core/config/map_tile_config.dart';
import 'package:route2go/core/router/app_router.dart';
import 'package:route2go/data/datasources/geocoding_providers.dart';
import 'package:route2go/data/location/location_source.dart';
import 'package:route2go/data/repositories/geocoding_repository.dart';
import 'package:route2go/domain/entities/geo.dart';
import 'package:route2go/domain/entities/misc_entities.dart';
import 'package:route2go/domain/entities/navigation.dart';
import 'package:route2go/domain/entities/route_option.dart';
import 'package:route2go/presentation/providers/auth_provider.dart';
import 'package:route2go/presentation/providers/connectivity_provider.dart';
import 'package:route2go/presentation/providers/favorites_search_provider.dart';
import 'package:route2go/presentation/providers/trip_planning_provider.dart';
import 'package:route2go/presentation/screens/home/home_screen.dart';
import 'package:route2go/presentation/screens/trip_planning/route_results_screen.dart';
import 'package:route2go/presentation/services/voice_service.dart';

void main() {
  Future<void> pumpMap(WidgetTester tester,
      {Map<String, Object> initialPrefs = const {}}) async {
    // In-memory SharedPreferences so the map tab's local state (recent
    // searches, map style) resolves without a platform channel.
    SharedPreferences.setMockInitialValues(initialPrefs);
    final overrides = <Override>[
      // Guest mode (authState == null). No Firebase, no network needed.
      authStateProvider.overrideWith((ref) => Stream.value(null)),
      // Offline map tiles keep the map laying out with zero network (both the
      // standard and styled providers render a transparent tile).
      mapTileConfigProvider.overrideWithValue(MapTileConfig(
        urlTemplate: 'https://offline.invalid/{z}/{x}/{y}.png',
        styledUrlTemplate: 'https://offline-styled.invalid/{z}/{x}/{y}.png',
        tileProviderFactory: TransparentTileProvider.new,
        styledTileProviderFactory: TransparentTileProvider.new,
      )),
      // Deterministic search: return canned results without any network.
      searchProvider.overrideWith(SearchNotifierStub.new),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const MaterialApp(home: Scaffold(body: HomeScreen())),
      ),
    );
    await tester.pumpAndSettle();

    // The Map tab is the third tab; select it to reach the maps-mode UI.
    await tester.tap(find.text('Map'));
    await tester.pumpAndSettle();
  }

  testWidgets('maps mode shows the search bar and current-location action',
      (tester) async {
    await pumpMap(tester);

    // Search entry is present on the map.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Search places, addresses, or POIs'), findsOneWidget);

    // Current-location controls exist (search-bar button + floating CTA).
    expect(find.byTooltip('Use my current location'), findsWidgets);
    expect(find.text('Use my current location'), findsWidgets);
  });

  testWidgets(
      'searching shows a result sheet and selecting a result shows the '
      'destination sheet', (tester) async {
    await pumpMap(tester);

    await tester.enterText(find.byType(TextField), 'Kahale, HI');
    // The search bar debounces keystrokes (300ms) before querying; advance
    // past the debounce so the request fires.
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    // Result sheet appears with the canned result.
    expect(find.text('Search Results'), findsOneWidget);
    expect(find.text('Kahale'), findsOneWidget);

    // Tapping a result hides the result sheet and opens the destination
    // sheet with Directions / Start Navigation / Share actions.
    await tester.tap(find.text('Kahale'));
    await tester.pumpAndSettle();

    expect(find.text('Search Results'), findsNothing);
    expect(find.text('Directions'), findsOneWidget);
    expect(find.text('Start Navigation'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
  });

  testWidgets('closing the search sheet hides it', (tester) async {
    await pumpMap(tester);

    await tester.enterText(find.byType(TextField), 'Kahale, HI');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('Search Results'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Search Results'), findsNothing);
  });

  testWidgets('search debounces: a burst of keystrokes fires one request',
      (tester) async {
    await pumpMap(tester);
    SearchNotifierStub.searchCalls = 0;

    // Rapid typing resets the 300ms debounce each keystroke.
    for (final text in ['K', 'Ka', 'Kah', 'Kaha', 'Kahal', 'Kahale, HI']) {
      await tester.enterText(find.byType(TextField), text);
      await tester.pump(const Duration(milliseconds: 50));
    }
    // 50ms after the last keystroke — still inside the debounce window.
    expect(SearchNotifierStub.searchCalls, 0);

    // Once the query settles for 300ms, exactly one search fires.
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(SearchNotifierStub.searchCalls, 1);
    expect(find.text('Search Results'), findsOneWidget);
  });

  testWidgets('pausing mid-typing fires, then the next burst fires again',
      (tester) async {
    await pumpMap(tester);
    SearchNotifierStub.searchCalls = 0;

    await tester.enterText(find.byType(TextField), 'Kahale, HI');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(SearchNotifierStub.searchCalls, 1);

    await tester.enterText(find.byType(TextField), 'Kauai, HI');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(SearchNotifierStub.searchCalls, 2);
  });

  testWidgets('destination sheet shows distance from you and Save to favorites',
      (tester) async {
    await pumpMapRouter(tester);

    // Grant a current location so the distance line is computed (never
    // fabricated: with no location there is no distance line).
    await tester.tap(find.byTooltip('Use my current location').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Allow location'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Kahale, HI');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kahale'));
    await tester.pumpAndSettle();

    expect(find.textContaining('km from you'), findsOneWidget);
    expect(find.text('Save to favorites'), findsOneWidget);
  });

  testWidgets('Save to favorites as a guest shows the sign-in gate',
      (tester) async {
    await pumpMapRouter(tester);

    await tester.enterText(find.byType(TextField), 'Kahale, HI');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kahale'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save to favorites'));
    await tester.pumpAndSettle();

    expect(find.text('Create an account to keep this'), findsOneWidget);
  });

  testWidgets(
      'Start Navigation resolves the real route and opens the live-trip screen',
      (tester) async {
    await pumpMapRouter(tester);

    await tester.enterText(find.byType(TextField), 'Kahale, HI');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kahale'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start Navigation'));
    await tester.pumpAndSettle();

    // The direct-navigation path hands off to the live-trip screen (stubbed
    // here) with the calculated route — no invisible session.
    expect(find.text('live-trip-stub'), findsOneWidget);
  });

  testWidgets('map tab exposes zoom in/out controls', (tester) async {
    await pumpMap(tester);

    expect(find.byTooltip('Zoom in'), findsOneWidget);
    expect(find.byTooltip('Zoom out'), findsOneWidget);

    // Both controls are actionable (zoom changes camera, never crashes).
    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Zoom out'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('destination sheet shows the server category and city',
      (tester) async {
    await pumpMap(tester);

    await tester.enterText(find.byType(TextField), 'Kahale, HI');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kahale'));
    await tester.pumpAndSettle();

    // Enrichment line: category · city, straight from the search payload.
    expect(find.text('Cafe · Hawaii'), findsOneWidget);
  });

  testWidgets('destination sheet falls back to Place when category is unknown',
      (tester) async {
    await pumpMap(tester);

    // City only, no category → "Place · Hawaii" (never a fabricated category).
    SearchNotifierStub.nextResult = const AsyncData(SearchResponse(
      results: [
        SearchResult(
          kind: 'nearby',
          id: 'geo-1',
          title: 'Kahale',
          subtitle: '',
          lat: 21.3156,
          lng: -157.8766,
          city: 'Hawaii',
        ),
      ],
      nearbyDegraded: false,
    ));
    await tester.enterText(find.byType(TextField), 'Kahale, HI');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kahale'));
    await tester.pumpAndSettle();

    expect(find.text('Place · Hawaii'), findsOneWidget);
  });

  testWidgets('map tab exposes compass and layer switcher', (tester) async {
    await pumpMap(tester);

    expect(find.byTooltip('Reset map north'), findsOneWidget);
    expect(find.byTooltip('Map style: Styled'), findsOneWidget);

    // Tapping the compass returns to north-up (never crashes).
    await tester.tap(find.byTooltip('Reset map north'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Toggling the layer switcher flips to Standard and confirms via snackbar.
    await tester.tap(find.byTooltip('Map style: Styled'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Map style: Standard'), findsOneWidget);
    expect(find.text('Standard map'), findsOneWidget);
    // Let the 1s snackbar timer fire so no timers leak from the test.
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();
  });

  testWidgets('layer switcher swaps the tile URL and persists the choice',
      (tester) async {
    await pumpMap(tester);

    TileLayer tileLayer() => tester.widget<TileLayer>(find.byType(TileLayer));
    // Default style is styled (styled provider first).
    expect(tileLayer().urlTemplate,
        'https://offline-styled.invalid/{z}/{x}/{y}.png');

    await tester.tap(find.byTooltip('Map style: Styled'));
    await tester.pumpAndSettle();
    expect(tileLayer().urlTemplate, 'https://offline.invalid/{z}/{x}/{y}.png');
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();

    // The choice is persisted locally (device-only).
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('map_style'), 'standard');
  });

  testWidgets('empty search shows recent searches and a recent re-runs it',
      (tester) async {
    await pumpMap(tester, initialPrefs: {
      'recent_searches': jsonEncode(['Kahale, HI']),
    });
    SearchNotifierStub.searchCalls = 0;

    // Interacting with the (empty) field surfaces the local history.
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(find.text('Recent searches'), findsOneWidget);
    expect(find.text('Kahale, HI'), findsOneWidget);

    // Tapping a recent runs that search.
    await tester.tap(find.text('Kahale, HI'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(SearchNotifierStub.searchCalls, 1);
    expect(find.text('Search Results'), findsOneWidget);
  });

  testWidgets('a completed search is saved to local recent searches',
      (tester) async {
    await pumpMap(tester);

    await tester.enterText(find.byType(TextField), 'Kahale, HI');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.pump();

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('recent_searches');
    expect(raw, isNotNull);
    expect(jsonDecode(raw!) as List, contains('Kahale, HI'));
  });

  testWidgets('route results exposes a share action once a route exists',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapTileConfigProvider.overrideWithValue(MapTileConfig(
            urlTemplate: 'https://offline.invalid/{z}/{x}/{y}.png',
            tileProviderFactory: TransparentTileProvider.new,
          )),
          tripCalculationProvider
              .overrideWith(() => _FixedCalc(_cannedResult())),
          selectedRouteTypeProvider.overrideWith((ref) => 'recommended'),
          tripPlanningFormProvider.overrideWith(
            (ref) => const TripPlanningForm(
              originLabel: 'Home',
              originLat: 12.9,
              originLng: 77.5,
              destinationLabel: 'Kahale',
              destinationLat: 21.3156,
              destinationLng: -157.8766,
            ),
          ),
        ],
        child: const MaterialApp(home: RouteResultsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // The share action is present and enabled (a real route exists).
    expect(find.byTooltip('Share route'), findsOneWidget);
    final shareButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.share_outlined));
    expect(shareButton.onPressed, isNotNull);
  });
}

/// Router-backed harness: exercises the map tab's navigation flows
/// (Directions / Start Navigation / Save) which use GoRouter.
Future<void> pumpMapRouter(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final overrides = <Override>[
    // Guest mode (authState == null). No Firebase, no network needed.
    authStateProvider.overrideWith((ref) => Stream.value(null)),
    // Offline map tiles keep the map laying out with zero network (both the
    // standard and styled providers render a transparent tile).
    mapTileConfigProvider.overrideWithValue(MapTileConfig(
      urlTemplate: 'https://offline.invalid/{z}/{x}/{y}.png',
      styledUrlTemplate: 'https://offline-styled.invalid/{z}/{x}/{y}.png',
      tileProviderFactory: TransparentTileProvider.new,
      styledTileProviderFactory: TransparentTileProvider.new,
    )),
    // Deterministic search: return canned results without any network.
    searchProvider.overrideWith(SearchNotifierStub.new),
    // Deterministic GPS: current location is Bengaluru, no platform channel.
    geocodingRepositoryProvider.overrideWithValue(_FakeGeocodingRepository()),
    // Deterministic route calculation: the canned alternative, no network.
    tripCalculationProvider.overrideWith(() => _FixedCalc(_cannedResult())),
    // Navigation permission denied -> no GPS subscription, no pending timers.
    locationSourceProvider.overrideWithValue(_DeniedLocationSource()),
    // TTS stub: never touches the platform channel.
    voiceServiceProvider.overrideWithValue(_SilentVoice()),
    connectivityProvider.overrideWith((ref) => Stream.value(true)),
  ];

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(routerConfig: _router),
    ),
  );
  await tester.pumpAndSettle();

  // The Map tab is the third tab; select it to reach the maps-mode UI.
  await tester.tap(find.text('Map'));
  await tester.pumpAndSettle();
}

final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const Scaffold(body: HomeScreen()),
    ),
    GoRoute(
      path: AppRoutes.routeResults,
      builder: (context, state) =>
          const Scaffold(body: Center(child: Text('route-results-stub'))),
    ),
    GoRoute(
      path: AppRoutes.liveTrip,
      builder: (context, state) =>
          const Scaffold(body: Center(child: Text('live-trip-stub'))),
    ),
    GoRoute(
      path: AppRoutes.locationPicker,
      builder: (context, state) =>
          const Scaffold(body: Center(child: Text('location-picker-stub'))),
    ),
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) =>
          const Scaffold(body: Center(child: Text('login-stub'))),
    ),
  ],
);

/// Deterministic, offline search notifier that never touches the network.
class SearchNotifierStub extends SearchNotifier {
  /// Counts how many times [search] was invoked, so debounce tests can assert
  /// that a burst of keystrokes collapses into a single request.
  static int searchCalls = 0;

  /// Result returned by the next [search]. Tests override it to exercise
  /// specific payload shapes (e.g. a result with no category).
  static AsyncValue<SearchResponse> nextResult = const AsyncData(SearchResponse(
    results: [
      SearchResult(
        kind: 'place',
        id: 'kahale-1',
        title: 'Kahale',
        subtitle: 'Hawaii, United States',
        lat: 21.3156,
        lng: -157.8766,
        category: 'Cafe',
        city: 'Hawaii',
      ),
    ],
    nearbyDegraded: false,
  ));

  @override
  Future<void> search(String q) async {
    searchCalls++;
    state = nextResult;
  }
}

/// Geocoding provider stub: never touches the network.
class _FakeGeocodingProvider implements GeocodingProvider {
  @override
  Future<List<GeoPlace>> geocode(String query) async => const [];

  @override
  Future<GeoPlace?> reverseGeocode(double lat, double lng) async => null;

  @override
  Future<List<GeoPlace>> searchNear(
    String query, {
    required double lat,
    required double lng,
    double radiusKm = 10,
  }) async =>
      const [];
}

/// Geocoding repository stub: GPS resolves to a fixed point without the
/// geolocator platform channel.
class _FakeGeocodingRepository extends GeocodingRepository {
  _FakeGeocodingRepository() : super(_FakeGeocodingProvider());

  @override
  Future<GeoPlace?> deviceLocation() async =>
      const GeoPlace(label: 'Current location', lat: 12.9, lng: 77.5);
}

/// Location source whose permission is denied: startNavigation records the
/// unavailable state and returns without subscribing to a GPS stream, so no
/// periodic timers leak into the test.
class _DeniedLocationSource implements LocationSource {
  @override
  Stream<LocationUpdate> get updates => const Stream.empty();

  @override
  Future<LocationUpdate?> getCurrentPosition() async => null;

  @override
  Future<bool> get hasPermission async => false;
}

/// TTS stub — never touches the real platform channel in tests.
class _SilentVoice extends VoiceService {
  @override
  Future<String?> announce(String message) async => null;

  @override
  void setMuted(bool value) {}

  @override
  void stop() {}
}

/// Fixed route calculation: build() AND calculate() return the canned result
/// without any repository/network access (the map tab's Start Navigation /
/// Directions flows call calculate()).
class _FixedCalc extends TripCalculationNotifier {
  _FixedCalc(this._result);

  final TripCalculationResult _result;

  @override
  Future<TripCalculationResult?> build() async => _result;

  @override
  Future<void> calculate() async => state = AsyncData(_result);
}

TripCalculationResult _cannedResult() => TripCalculationResult(
      tripId: null,
      routes: [_cannedRoute()],
      budgetStatus: null,
    );

RouteOption _cannedRoute() => RouteOption(
      routeType: 'recommended',
      distanceKm: 4.2,
      durationMin: 12,
      fuelCost: null,
      fuelCostConfidence: 'unavailable',
      tollCost: 0,
      tollConfidence: 'unavailable',
      totalCost: 0,
      provider: 'test-fixture',
      fetchedAt: DateTime(2026, 1, 1),
      geometry: const {
        'type': 'LineString',
        'coordinates': [
          [77.5, 12.9],
          [77.51, 12.91],
          [77.52, 12.92],
        ],
      },
      steps: const [
        NavigationStep(
          instruction: 'Head north on Main St',
          maneuverType: 'depart',
          modifier: 'north',
          name: 'Main St',
          distanceKm: 2,
          durationMin: 6,
          lat: 12.91,
          lng: 77.51,
        ),
      ],
    );
