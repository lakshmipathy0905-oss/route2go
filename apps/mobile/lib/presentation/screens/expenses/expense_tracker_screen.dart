import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../providers/expense_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/sharing_widgets.dart';
import '../../widgets/guest_gate.dart';
import '../../widgets/phase2_gate.dart';
import '../../../domain/entities/expense.dart';

class ExpenseTrackerScreen extends ConsumerStatefulWidget {
  const ExpenseTrackerScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<ExpenseTrackerScreen> createState() => _ExpenseTrackerScreenState();
}

class _ExpenseTrackerScreenState extends ConsumerState<ExpenseTrackerScreen> {
  bool _estimateOnly = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(expensesProvider.notifier).load(widget.tripId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = ref.watch(isLoggedInProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          if (isLoggedIn)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add expense',
              onPressed: () => context.push(AppRoutes.expenseAddOf(widget.tripId)),
            ),
        ],
      ),
      body: SafeArea(
        child: isLoggedIn
            ? ref.watch(expensesProvider).when(
                loading: () => const AppLoadingState(message: 'Loading expenses…'),
                error: (err, st) => AppErrorState(
                  error: err,
                  onRetry: () => ref.read(expensesProvider.notifier).load(widget.tripId),
                ),
                data: (expenses) => _ExpensesList(
                  expenses: expenses,
                  estimateOnly: _estimateOnly,
                  onToggleEstimateOnly: (v) => setState(() => _estimateOnly = v),
                  onRecordActual: (e) => _recordActual(e),
                  onDelete: (e) => _delete(e),
                  onAdd: () => context.push(AppRoutes.expenseAddOf(widget.tripId)),
                ),
              )
            : _GuestExpenseView(onSignIn: () => showGuestGate(context)),
      ),
    );
  }

  Future<void> _recordActual(Expense e) async {
    final ctrl = TextEditingController(text: e.estimatedAmount.toStringAsFixed(0));
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record actual amount'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Actual amount (₹)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, double.tryParse(ctrl.text.trim())),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (value == null) return;
    await ref.read(expensesProvider.notifier).recordActual(e.id, value);
  }

  Future<void> _delete(Expense e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text('${e.description ?? e.category} — this cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(expensesProvider.notifier).remove(e.id);
    }
  }
}

class _GuestExpenseView extends StatelessWidget {
  const _GuestExpenseView({required this.onSignIn});
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.receipt_long_outlined, size: 44, color: AppColors.textSecondary),
        const SizedBox(height: AppSpacing.md),
        const Text('Track expenses against a saved trip.'),
        const SizedBox(height: AppSpacing.lg),
        ElevatedButton(onPressed: onSignIn, child: const Text('Sign in to track expenses')),
      ],
    );
  }
}

class _ExpensesList extends StatelessWidget {
  const _ExpensesList({
    required this.expenses,
    required this.estimateOnly,
    required this.onToggleEstimateOnly,
    required this.onRecordActual,
    required this.onDelete,
    required this.onAdd,
  });

  final List<Expense> expenses;
  final bool estimateOnly;
  final ValueChanged<bool> onToggleEstimateOnly;
  final ValueChanged<Expense> onRecordActual;
  final ValueChanged<Expense> onDelete;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) {
      return const AppEmptyState(
        message: 'No expenses yet — add fuel, toll, stay or food entries as you go.',
        icon: Icons.receipt_long_outlined,
      );
    }

    final total = _total(expenses);
    final categories = _byCategory(expenses);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text('Total ${estimateOnly ? 'estimated' : 'actual'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyLarge),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Flexible(
                      child: Text(formatCurrency(total),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppColors.primary)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('Categories: ${categories.entries.map((e) => '${e.key} ${formatCurrency(e.value)}').join(' · ')}',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: AppSpacing.md),
                SwitchListTile(
                  value: estimateOnly,
                  onChanged: onToggleEstimateOnly,
                  title: const Text('Show estimates'),
                  subtitle: const Text('Off: use recorded actual amounts where available'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const Phase2Gate(
          flagKey: 'phase2_group_split',
          title: 'Group expense splitting',
          subtitle: 'Split costs between trip participants',
          icon: Icons.group_outlined,
          child: SizedBox.shrink(),
        ),
        const SizedBox(height: AppSpacing.md),
        ...expenses.map((e) => Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              child: ListTile(
                leading: Icon(_iconFor(e.category), color: AppColors.primary),
                title: Text(e.description ?? e.category),
                subtitle: Text(
                  '${e.category} · Est ${formatCurrency(e.estimatedAmount)}'
                  '${e.hasActual ? ' · Actual ${formatCurrency(e.actualAmount!)}' : ''}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!estimateOnly && !e.hasActual)
                      TextButton(
                        onPressed: () => onRecordActual(e),
                        child: const Text('Actual'),
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      tooltip: 'Delete',
                      onPressed: () => onDelete(e),
                    ),
                  ],
                ),
              ),
            )),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Add expense')),
      ],
    );
  }

  IconData _iconFor(String category) {
    switch (category) {
      case 'fuel':
        return Icons.local_gas_station_outlined;
      case 'toll':
        return Icons.toll_outlined;
      case 'stay':
        return Icons.hotel_outlined;
      case 'food':
        return Icons.restaurant_outlined;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  double _total(List<Expense> list) {
    return list.fold<double>(
      0,
      (sum, e) => sum + (estimateOnly || !e.hasActual ? e.estimatedAmount : e.actualAmount!),
    );
  }

  Map<String, double> _byCategory(List<Expense> list) {
    final map = <String, double>{};
    for (final e in list) {
      final v = estimateOnly || !e.hasActual ? e.estimatedAmount : e.actualAmount!;
      map[e.category] = (map[e.category] ?? 0) + v;
    }
    return map;
  }
}