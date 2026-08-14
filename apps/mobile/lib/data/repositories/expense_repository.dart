import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datasources/api_client.dart';
import 'base_repository.dart';
import '../../domain/entities/expense.dart';

class ExpenseRepository extends BaseRepository {
  ExpenseRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<List<Expense>> listForTrip(String tripId) async {
    final res =
        await _apiClient.get('/expenses', queryParameters: {'trip_id': tripId});
    return parseList(res, Expense.fromJson);
  }

  Future<Expense> createExpense({
    required String tripId,
    required String category,
    required double estimatedAmount,
    double? actualAmount,
    String? paidBy,
    String splitType = 'equal',
    String? description,
  }) async {
    final res = await _apiClient.post('/expenses', body: {
      'trip_id': tripId,
      'category': category,
      'estimated_amount': estimatedAmount,
      if (actualAmount != null) 'actual_amount': actualAmount,
      if (paidBy != null) 'paid_by': paidBy,
      'split_type': splitType,
      if (description != null) 'description': description,
    });
    return parseObject(res, Expense.fromJson);
  }

  Future<Expense> updateExpense(Expense expense) async {
    final res = await _apiClient.patch('/expenses', body: {
      'expense_id': expense.id,
      'category': expense.category,
      'estimated_amount': expense.estimatedAmount,
      if (expense.actualAmount != null) 'actual_amount': expense.actualAmount,
      if (expense.paidBy != null) 'paid_by': expense.paidBy,
      'split_type': expense.splitType,
      if (expense.description != null) 'description': expense.description,
    });
    return parseObject(res, Expense.fromJson);
  }

  Future<void> recordActual({
    required String expenseId,
    required double actualAmount,
  }) async {
    await _apiClient.patch('/expenses', body: {
      'expense_id': expenseId,
      'actual_amount': actualAmount,
    });
  }

  Future<void> deleteExpense(String expenseId) async {
    await _apiClient
        .delete('/expenses', queryParameters: {'expense_id': expenseId});
  }
}

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(ref.watch(apiClientProvider));
});
