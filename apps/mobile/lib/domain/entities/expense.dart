/// An expense tracked against a trip (spec Section 5.12): estimated vs actual.
class Expense {
  const Expense({
    required this.id,
    required this.tripId,
    required this.category,
    this.estimatedAmount = 0,
    this.actualAmount,
    this.paidBy,
    this.splitType = 'equal',
    this.description,
  });

  final String id;
  final String tripId;
  final String category; // fuel | toll | stay | food | misc
  final double estimatedAmount;
  final double? actualAmount;
  final String? paidBy;
  final String splitType;
  final String? description;

  bool get hasActual => actualAmount != null;

  double get bestAmount => actualAmount ?? estimatedAmount;

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      category: json['category'] as String,
      estimatedAmount: (json['estimated_amount'] as num?)?.toDouble() ?? 0,
      actualAmount: (json['actual_amount'] as num?)?.toDouble(),
      paidBy: json['paid_by'] as String?,
      splitType: json['split_type'] as String? ?? 'equal',
      description: json['description'] as String?,
    );
  }
}