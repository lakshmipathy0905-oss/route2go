import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:route2go/core/config/map_tile_config.dart';
import 'package:route2go/domain/entities/misc_entities.dart';
import 'package:route2go/presentation/providers/auth_provider.dart';
import 'package:route2go/presentation/providers/favorites_search_provider.dart';
import 'package:route2go/presentation/screens/home/home_screen.dart';

void main() {
  Future<void> pumpMap(WidgetTester tester) async {
    final overrides = <Override>[
      // Guest mode (authState == null). No Firebase, no network needed.
      authStateProvider.overrideWith((ref) => Stream.value(null)),
      // Offline map tiles keep the map laying out with zero network.
      mapTileConfigProvider.overrideWithValue(MapTileConfig(
        urlTemplate: 'https://offline.invalid/{z}/{x}/{y}.png',
        tileProviderFactory: TransparentTileProvider.new,
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

  testWidgets('searching shows a result sheet and selecting a result shows the '
      'destination sheet', (tester) async {
    await pumpMap(tester);

    await tester.enterText(
        find.byType(TextField), 'Kahale, HI');
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
    await tester.pumpAndSettle();
    expect(find.text('Search Results'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Search Results'), findsNothing);
  });
}

/// Deterministic, offline search notifier that never touches the network.
class SearchNotifierStub extends SearchNotifier {
  @override
  Future<void> search(String q) async {
    state = AsyncData(const SearchResponse(
      results: [
        SearchResult(
          kind: 'place',
          id: 'kahale-1',
          title: 'Kahale',
          subtitle: 'Hawaii, United States',
          lat: 21.3156,
          lng: -157.8766,
        ),
      ],
      nearbyDegraded: false,
    ));
  }
}
