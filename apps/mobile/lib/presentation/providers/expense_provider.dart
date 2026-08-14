import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/expense_repository.dart';
import '../../domain/entities/expense.dart';

class ExpensesNotifier extends AsyncNotifier<List<Expense>> {
  String? _tripId;

  @override
  Future<List<Expense>> build() async => const [];

  Future<void> load(String tripId) async {
    _tripId = tripId;
    state = const AsyncLoading();
    final repo = ref.read(expenseRepositoryProvider);
    state = await AsyncValue.guard(() => repo.listForTrip(tripId));
  }

  Future<void> add(
    Expense expense, {
    double? actualAmount,
  }) async {
    final tripId = _tripId;
    if (tripId == null) return;
    final repo = ref.read(expenseRepositoryProvider);
    state = await AsyncValue.guard(() async {
      await repo.createExpense(
        tripId: tripId,
        category: expense.category,
        estimatedAmount: expense.estimatedAmount,
        actualAmount: actualAmount ?? expense.actualAmount,
        paidBy: expense.paidBy,
        splitType: expense.splitType,
        description: expense.description,
      );
      return repo.listForTrip(tripId);
    });
  }

  Future<void> recordActual(String expenseId, double actual) async {
    final tripId = _tripId;
    if (tripId == null) return;
    final repo = ref.read(expenseRepositoryProvider);
    state = await AsyncValue.guard(() async {
      await repo.recordActual(expenseId: expenseId, actualAmount: actual);
      return repo.listForTrip(tripId);
    });
  }

  Future<void> updateExpense(Expense expense) async {
    final tripId = _tripId;
    if (tripId == null) return;
    final repo = ref.read(expenseRepositoryProvider);
    state = await AsyncValue.guard(() async {
      await repo.updateExpense(expense);
      return repo.listForTrip(tripId);
    });
  }

  Future<void> remove(String expenseId) async {
    final tripId = _tripId;
    if (tripId == null) return;
    final repo = ref.read(expenseRepositoryProvider);
    state = await AsyncValue.guard(() async {
      await repo.deleteExpense(expenseId);
      return repo.listForTrip(tripId);
    });
  }

  /// Aggregate for the Budget Tracker: estimated vs recorded actuals by category.
  Map<String, double> totals({required bool estimateOnly}) {
    final current = state.valueOrNull ?? const <Expense>[];
    final result = <String, double>{};
    for (final e in current) {
      final value =
          estimateOnly || !e.hasActual ? e.estimatedAmount : e.actualAmount!;
      result[e.category] = (result[e.category] ?? 0) + value;
    }
    return result;
  }
}

final expensesProvider = AsyncNotifierProvider<ExpensesNotifier, List<Expense>>(
  ExpensesNotifier.new,
);
