import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:route2go/core/router/app_router.dart';
import 'package:route2go/core/theme/app_theme.dart';
import 'package:route2go/presentation/providers/auth_provider.dart';

void main() {
  Future<GoRouter> pumpRouter(WidgetTester tester) async {
    final overrides = <Override>[
      // Guest mode (authState == null). No Firebase, no network needed.
      authStateProvider.overrideWith((ref) => Stream.value(null)),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const _App(),
      ),
    );
    // Let the splash's 900ms auto-advance timer fire deterministically:
    // splash -> onboarding, then settle.
    await tester.pumpAndSettle();

    // Grab the router instance actually attached to the widget tree (the
    // provider-held one rebuilds whenever the auth stream emits, so we never
    // hold a stale copy). Use a Scaffold context so GoRouter.of resolves.
    final context = tester.element(find.byType(Scaffold).first);
    return GoRouter.of(context);
  }

  /// The top of the router stack. `currentConfiguration.uri` stays at the base
  /// URI for imperative pushes, so we must read the last match instead.
  String topPath(GoRouter router) =>
      router.routerDelegate.currentConfiguration.matches.last.matchedLocation;

  Future<void> goHome(WidgetTester tester, GoRouter router) async {
    router.go(AppRoutes.home);
    await tester.pumpAndSettle();
    expect(topPath(router), AppRoutes.home);
  }

  testWidgets(
      'back navigation pops one screen at a time through the plan-trip flow',
      (tester) async {
    final router = await pumpRouter(tester);
    await goHome(tester, router);

    // Home -> Plan a Trip via the real CTA (uses context.push).
    await tester.tap(find.text('Plan a Trip'));
    await tester.pumpAndSettle();
    expect(topPath(router), AppRoutes.planTrip,
        reason: 'Plan a Trip CTA must push, keeping home beneath it');

    // Plan Trip -> location picker via the real Starting point field.
    await tester.tap(find.text('Starting point'));
    await tester.pumpAndSettle();
    expect(topPath(router), AppRoutes.locationPicker,
        reason: 'Starting point field must push the location picker');

    // System back #1: from the picker we must return to Plan Trip — never
    // to Home, never to Login.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(topPath(router), AppRoutes.planTrip,
        reason: 'back from location picker lands on plan trip');

    // System back #2: from Plan Trip we return to Home.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(topPath(router), AppRoutes.home,
        reason: 'back from plan trip lands on home');

    // System back #3: home is the stack root — must exit, not land anywhere.
    expect(router.routerDelegate.canPop(), isFalse,
        reason: 'home is the stack root; canPop must be false');
    final handled = await tester.binding.handlePopRoute();
    expect(handled, isFalse,
        reason: 'back at home reports "not handled" (app exits)');
  });

  testWidgets('pop from the trip flow never lands on login', (tester) async {
    final router = await pumpRouter(tester);
    await goHome(tester, router);

    // Push the whole trip flow programmatically to mimic a deeper stack, then
    // pop through it: budget -> results -> plan trip -> home.
    router.push(AppRoutes.planTrip);
    await tester.pumpAndSettle();
    router.push(AppRoutes.routeResults);
    await tester.pumpAndSettle();
    router.push(AppRoutes.budgetTracker);
    await tester.pumpAndSettle();
    expect(topPath(router), AppRoutes.budgetTracker);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(topPath(router), AppRoutes.routeResults,
        reason: 'pop #1 from budget -> results');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(topPath(router), AppRoutes.planTrip,
        reason: 'pop #2 from results -> plan trip');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(topPath(router), AppRoutes.home,
        reason: 'pop #3 from plan trip -> home');

    expect(router.routerDelegate.canPop(), isFalse,
        reason: 'home is the stack root; canPop must be false');
  });
}

class _App extends ConsumerWidget {
  const _App();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mirrors main.dart: watch the provider so the tree always holds the
    // current GoRouter instance.
    return MaterialApp.router(
      title: 'Route2Go',
      theme: AppTheme.light(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
