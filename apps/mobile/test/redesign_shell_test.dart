import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:route2go/core/config/map_tile_config.dart';
import 'package:route2go/core/router/app_router.dart';
import 'package:route2go/core/theme/app_theme.dart';
import 'package:route2go/presentation/providers/auth_provider.dart';
import 'package:route2go/presentation/screens/book/book_screen.dart';
import 'package:route2go/presentation/screens/explore/explore_screen.dart';
import 'package:route2go/presentation/screens/home/home_dashboard.dart';
import 'package:route2go/presentation/screens/settings/profile_tab.dart';
import 'package:route2go/presentation/screens/trips/trips_dashboard.dart';
import 'package:route2go/presentation/widgets/brand_widgets.dart';

void main() {
  Future<GoRouter> pumpRouter(WidgetTester tester) async {
    final overrides = <Override>[
      authStateProvider.overrideWith((ref) => Stream.value(null)),
      mapTileConfigProvider.overrideWithValue(MapTileConfig(
        urlTemplate: 'https://offline.invalid/{z}/{x}/{y}.png',
        tileProviderFactory: TransparentTileProvider.new,
      )),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const _App(),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold).first);
    return GoRouter.of(context);
  }

  Finder navLabel(String label) => find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      );

  // Scopes a text finder to a single tab screen so offstage branches don't
  // contribute duplicate matches (the shell uses an IndexedStack).
  Finder inScreen(WidgetTester tester, Type screen, Finder finder) {
    final screenFinder = find.byType(screen).first;
    return find.descendant(of: screenFinder, matching: finder);
  }

  testWidgets('shell renders the five bottom-nav destinations', (tester) async {
    final router = await pumpRouter(tester);
    router.go(AppRoutes.home);
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    for (final label in ['Home', 'Explore', 'Book', 'Trips', 'Profile']) {
      expect(navLabel(label), findsOneWidget, reason: '$label tab must exist');
    }
    // Home dashboard hero (spec Section 6).
    expect(find.text('Where do you want to go?'), findsOneWidget);
    expect(inScreen(tester, HomeDashboardScreen, find.text('Plan a Trip')),
        findsOneWidget);
    expect(
        inScreen(tester, HomeDashboardScreen, find.text('Book your journey')),
        findsOneWidget);
    expect(find.byType(BrandIcon), findsWidgets);
  });

  testWidgets('Book tab renders the mode selector and honest provider UI',
      (tester) async {
    final router = await pumpRouter(tester);
    router.go(AppRoutes.book);
    await tester.pumpAndSettle();

    expect(find.byType(BookScreen), findsOneWidget);
    expect(find.text('Where are you headed?'), findsOneWidget);
    expect(inScreen(tester, BookScreen, find.text('Train')), findsOneWidget);
    expect(inScreen(tester, BookScreen, find.text('Bus')), findsOneWidget);
    expect(inScreen(tester, BookScreen, find.text('Flight')), findsOneWidget);
  });

  testWidgets('Explore tab renders real destinations', (tester) async {
    final router = await pumpRouter(tester);
    router.go(AppRoutes.explore);
    await tester.pumpAndSettle();

    expect(find.byType(ExploreScreen), findsOneWidget);
    expect(find.text('Find your next destination'), findsOneWidget);
    expect(
        inScreen(tester, ExploreScreen, find.text('Jaipur')), findsOneWidget);
  });

  testWidgets('Trips tab shows an honest guest gate', (tester) async {
    final router = await pumpRouter(tester);
    router.go(AppRoutes.trips);
    await tester.pumpAndSettle();

    expect(find.byType(TripsDashboardScreen), findsOneWidget);
    expect(
        inScreen(
            tester, TripsDashboardScreen, find.text('Saved trips are private')),
        findsOneWidget);
  });

  testWidgets('Profile tab shows the account menu', (tester) async {
    final router = await pumpRouter(tester);
    router.go(AppRoutes.profile);
    await tester.pumpAndSettle();

    expect(find.byType(ProfileTabScreen), findsOneWidget);
    expect(inScreen(tester, ProfileTabScreen, find.text('My travel')),
        findsOneWidget);
    expect(inScreen(tester, ProfileTabScreen, find.text('My Vehicles')),
        findsOneWidget);
    expect(inScreen(tester, ProfileTabScreen, find.text('Favorites')),
        findsOneWidget);
  });
}

class _App extends ConsumerWidget {
  const _App();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Route2Go',
      theme: AppTheme.light(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
