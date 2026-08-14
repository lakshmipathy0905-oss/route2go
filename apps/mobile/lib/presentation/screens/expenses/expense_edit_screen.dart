import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/expense_provider.dart';
import '../../../domain/entities/expense.dart';

class ExpenseEditScreen extends ConsumerStatefulWidget {
  const ExpenseEditScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<ExpenseEditScreen> createState() => _ExpenseEditScreenState();
}

class _ExpenseEditScreenState extends ConsumerState<ExpenseEditScreen> {
  String _category = 'fuel';
  final _estimatedCtrl = TextEditingController();
  final _actualCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _estimatedCtrl.dispose();
    _actualCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Expense')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: const [
                DropdownMenuItem(value: 'fuel', child: Text('Fuel')),
                DropdownMenuItem(value: 'toll', child: Text('Toll')),
                DropdownMenuItem(value: 'stay', child: Text('Stay / Hotel')),
                DropdownMenuItem(value: 'food', child: Text('Food')),
                DropdownMenuItem(value: 'misc', child: Text('Misc')),
              ],
              onChanged: (v) => setState(() => _category = v ?? 'fuel'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _descriptionCtrl,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _estimatedCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Estimated amount (₹)'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _actualCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Actual amount (₹) — optional, record after paying',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            ],
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(onPressed: _onSave, child: const Text('Save Expense')),
          ],
        ),
      ),
    );
  }

  Future<void> _onSave() async {
    setState(() => _error = null);
    final estimated = double.tryParse(_estimatedCtrl.text.trim());
    if (estimated == null || estimated < 0) {
      setState(() => _error = 'Enter a valid estimated amount (₹).');
      return;
    }

    final notifier = ref.read(expensesProvider.notifier);
    await notifier.add(
      Expense(
        id: '',
        tripId: widget.tripId,
        category: _category,
        estimatedAmount: estimated,
        actualAmount: double.tryParse(_actualCtrl.text.trim()),
        description: _descriptionCtrl.text.trim().isEmpty
            ? null
            : _descriptionCtrl.text.trim(),
        splitType: 'equal',
      ),
    );

    if (!mounted) return;
    if (ref.read(expensesProvider).hasError) {
      setState(() => _error = 'Could not save the expense. Please try again.');
      return;
    }
    Navigator.pop(context);
  }
}