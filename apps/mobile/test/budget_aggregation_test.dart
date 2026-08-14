import 'package:flutter_test/flutter_test.dart';
import 'package:route2go/data/datasources/api_client.dart';
import 'package:route2go/data/repositories/trip_repository.dart';
import 'package:route2go/domain/entities/route_option.dart';

/// A no-op ApiClient — aggregateBudget is pure and never touches the network.
class _FakeApiClient implements ApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late TripRepository repo;

  setUp(() => repo = TripRepository(_FakeApiClient()));

  BudgetStatus base({double budgetTotal = 10000}) => BudgetStatus(
        status: 'GREEN',
        totalEstimated: 0,
        budgetTotal: budgetTotal,
        usedPct: 0,
        remaining: budgetTotal,
        suggestions: const [],
      );

  group('aggregateBudget status thresholds', () {
    test('stays GREEN below 80% of budget', () {
      final result = repo.aggregateBudget(
        base: base(),
        stayCost: 1000,
        foodCost: 2000,
        miscCost: 500, // 3500 / 10000 = 35%
      );
      expect(result.status, 'GREEN');
      expect(result.usedPct, closeTo(35, 0.01));
    });

    test('crosses to YELLOW at or above 80% but <= 100%', () {
      final result = repo.aggregateBudget(
        base: base(),
        stayCost: 4000,
        foodCost: 3000,
        miscCost: 1000, // 8000 / 10000 = 80%
      );
      expect(result.status, 'YELLOW');
      expect(result.usedPct, closeTo(80, 0.01));
    });

    test('goes RED above 100% of budget', () {
      final result = repo.aggregateBudget(
        base: base(),
        stayCost: 6000,
        foodCost: 3000,
        miscCost: 2000, // 11000 / 10000 = 110%
      );
      expect(result.status, 'RED');
    });
  });

  group('aggregateBudget totals and suggestions', () {
    test('totals transport + stay + food + misc', () {
      final result = repo.aggregateBudget(
        base: base(budgetTotal: 20000),
        stayCost: 1000,
        foodCost: 1000,
        miscCost: 1000,
      );
      expect(result.totalEstimated, 3000);
      expect(result.remaining, closeTo(17000, 0.01));
    });

    test('suggests corrective actions only when RED', () {
      final green = repo.aggregateBudget(
        base: base(),
        stayCost: 100,
        foodCost: 100,
        miscCost: 100,
      );
      expect(green.suggestions, isEmpty);

      final red = repo.aggregateBudget(
        base: base(),
        stayCost: 9000,
        foodCost: 1000,
        miscCost: 1000,
      );
      expect(red.suggestions, isNotEmpty);
    });

    test('keeps base suggestions when already RED', () {
      const baseRed = BudgetStatus(
        status: 'RED',
        totalEstimated: 0,
        budgetTotal: 10000,
        usedPct: 0,
        remaining: 10000,
        suggestions: ['Switch fuel'],
      );
      final result = repo.aggregateBudget(
        base: baseRed,
        stayCost: 9000,
        foodCost: 1000,
        miscCost: 1000,
      );
      expect(result.suggestions, ['Switch fuel']);
    });
  });
}
