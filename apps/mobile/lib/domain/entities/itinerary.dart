/// A generated itinerary: day-by-day plan bounded by the max-driving-hours
/// safety cap (spec Section 5.10 / 18).
class ItineraryItem {
  const ItineraryItem({
    required this.itemType,
    this.refId,
    this.name,
    this.startTime,
    this.endTime,
    this.estCost = 0,
  });

  final String itemType; // place | hotel | restaurant | drive | rest
  final String? refId;
  final String? name;
  final DateTime? startTime;
  final DateTime? endTime;
  final double estCost;

  factory ItineraryItem.fromJson(Map<String, dynamic> json) {
    return ItineraryItem(
      itemType: json['item_type'] as String,
      refId: json['ref_id'] as String?,
      name: json['name'] as String?,
      startTime: DateTime.tryParse(json['start_time'] as String? ?? ''),
      endTime: DateTime.tryParse(json['end_time'] as String? ?? ''),
      estCost: (json['est_cost'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ItineraryDay {
  const ItineraryDay({required this.dayNumber, required this.items});

  final int dayNumber;
  final List<ItineraryItem> items;

  double get totalCost => items.fold(0, (sum, i) => sum + i.estCost);

  factory ItineraryDay.fromJson(Map<String, dynamic> json) {
    return ItineraryDay(
      dayNumber: json['day_number'] as int,
      items: (json['items'] as List<dynamic>? ?? const [])
          .map((i) => ItineraryItem.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ItineraryPlan {
  const ItineraryPlan({required this.days, this.durationDays = 1});

  final List<ItineraryDay> days;
  final int durationDays;

  double get totalCost =>
      days.fold(0, (sum, d) => sum + d.totalCost);

  factory ItineraryPlan.fromJson(Map<String, dynamic> json) {
    return ItineraryPlan(
      durationDays: json['duration_days'] as int? ?? 1,
      days: (json['days'] as List<dynamic>? ?? const [])
          .map((d) => ItineraryDay.fromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }
}