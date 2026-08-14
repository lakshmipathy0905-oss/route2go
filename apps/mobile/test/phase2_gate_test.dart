import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:route2go/presentation/providers/favorites_search_provider.dart';
import 'package:route2go/presentation/widgets/phase2_gate.dart';

class _StubFeatureFlagsNotifier extends FeatureFlagsNotifier {
  _StubFeatureFlagsNotifier(this.flags);

  final Map<String, bool> flags;

  @override
  Future<Map<String, bool>> build() async => flags;
}

void main() {
  Future<void> pumpGate(WidgetTester tester, {required bool enabled}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          featureFlagsProvider.overrideWith(
            () => _StubFeatureFlagsNotifier({'phase2_weather': enabled}),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Phase2Gate(
              flagKey: 'phase2_weather',
              title: 'Weather & road alerts',
              subtitle: 'Along-route forecasts before you leave',
              icon: Icons.wb_sunny_outlined,
              child: Text('WEATHER_CONTENT'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows locked shell when flag is off', (tester) async {
    await pumpGate(tester, enabled: false);
    expect(find.text('WEATHER_CONTENT'), findsNothing);
    expect(find.text('Weather & road alerts'), findsOneWidget);
  });

  testWidgets('shows unlocked child when flag is on', (tester) async {
    await pumpGate(tester, enabled: true);
    expect(find.text('WEATHER_CONTENT'), findsOneWidget);
    expect(find.text('Weather & road alerts'), findsNothing);
  });
}