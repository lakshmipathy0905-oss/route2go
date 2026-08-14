import 'navigation.dart';

/// A single calculated route alternative, mirroring the /trip/calculate
/// response shape from the trip-calculate edge function.
class RouteOption {
  const RouteOption({
    required this.routeType,
    required this.distanceKm,
    required this.durationMin,
    required this.fuelCost,
    required this.fuelCostConfidence,
    required this.tollCost,
    required this.tollConfidence,
    required this.totalCost,
    required this.provider,
    required this.fetchedAt,
    this.geometry,
    this.steps = const [],
  });

  final String routeType; // fastest | cheapest | shortest | no_toll | recommended
  final double distanceKm;
  final int durationMin;
  final double? fuelCost;
  final String fuelCostConfidence; // calculated | unavailable
  final double tollCost;
  final String tollConfidence; // verified | estimated | unavailable
  final double totalCost;
  final String provider;
  final DateTime fetchedAt;

  /// Route shape as GeoJSON LineString, verbatim from the routing provider
  /// (`{type: "LineString", coordinates: [[lng, lat], ...]}`). Null when the
  /// provider returned no geometry or the response shape wasn't parseable.
  final Map<String, dynamic>? geometry;

  /// Turn-by-turn instructions from the provider. Empty when the provider
  /// returned none (e.g. the dev mock) — navigation must then fall back to
  /// route-progress display and never fabricate instructions.
  final List<NavigationStep> steps;

  /// The route's polyline points as [lng, lat] coordinate pairs (GeoJSON
  /// order), or null if no parseable geometry was returned. Rendering layers
  /// convert to flutter_map LatLng (lat, lng) — reversing here would leak
  /// provider specifics into widgets.
  List<List<double>>? get geometryCoordinates {
    final g = geometry;
    if (g == null) return null;
    final type = g['type'];
    final coords = g['coordinates'];
    if (type != 'LineString' || coords is! List) return null;
    final points = <List<double>>[];
    for (final c in coords) {
      if (c is List && c.length >= 2) {
        final lng = (c[0] as num?)?.toDouble();
        final lat = (c[1] as num?)?.toDouble();
        if (lng == null || lat == null) return null;
        points.add([lng, lat]);
      } else {
        return null;
      }
    }
    return points.isEmpty ? null : points;
  }

  String get label {
    switch (routeType) {
      case 'fastest':
        return 'Fastest';
      case 'cheapest':
        return 'Cheapest';
      case 'shortest':
        return 'Shortest';
      case 'no_toll':
        return 'No Toll';
      case 'recommended':
      default:
        return 'Recommended';
    }
  }

  factory RouteOption.fromJson(Map<String, dynamic> json) {
    return RouteOption(
      routeType: json['route_type'] as String,
      distanceKm: (json['distance_km'] as num).toDouble(),
      durationMin: (json['duration_min'] as num).toInt(),
      fuelCost: (json['fuel_cost'] as num?)?.toDouble(),
      fuelCostConfidence: json['fuel_cost_confidence'] as String? ?? 'unavailable',
      tollCost: (json['toll_cost'] as num?)?.toDouble() ?? 0,
      tollConfidence: json['toll_confidence'] as String? ?? 'unavailable',
      totalCost: (json['total_cost'] as num?)?.toDouble() ?? 0,
      provider: json['provider'] as String? ?? 'unknown',
      geometry: json['geometry'] is Map<String, dynamic>
          ? (json['geometry'] as Map<String, dynamic>)
          : null,
      steps: json['steps'] is List
          ? (json['steps'] as List)
              .whereType<Map<String, dynamic>>()
              .map(NavigationStep.fromJson)
              .toList()
          : const [],
      fetchedAt: DateTime.tryParse(json['fetched_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// Budget status matching the GREEN/YELLOW/RED engine in spec Section 13.
class BudgetStatus {
  const BudgetStatus({
    required this.status,
    required this.totalEstimated,
    required this.budgetTotal,
    required this.usedPct,
    required this.remaining,
    required this.suggestions,
  });

  final String status; // GREEN | YELLOW | RED
  final double totalEstimated;
  final double budgetTotal;
  final double usedPct;
  final double remaining;
  final List<String> suggestions;

  factory BudgetStatus.fromJson(Map<String, dynamic> json) {
    return BudgetStatus(
      status: json['status'] as String,
      totalEstimated: (json['total_estimated'] as num).toDouble(),
      budgetTotal: (json['budget_total'] as num).toDouble(),
      usedPct: (json['used_pct'] as num).toDouble(),
      remaining: (json['remaining'] as num).toDouble(),
      suggestions: (json['suggestions'] as List<dynamic>? ?? []).cast<String>(),
    );
  }
}

class TripCalculationResult {
  const TripCalculationResult({
    required this.tripId,
    required this.routes,
    required this.budgetStatus,
  });

  final String? tripId;
  final List<RouteOption> routes;
  final BudgetStatus? budgetStatus;

  factory TripCalculationResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return TripCalculationResult(
      tripId: data['trip_id'] as String?,
      routes: (data['routes'] as List<dynamic>)
          .map((r) => RouteOption.fromJson(r as Map<String, dynamic>))
          .toList(),
      budgetStatus: data['budget_status'] != null
          ? BudgetStatus.fromJson(data['budget_status'] as Map<String, dynamic>)
          : null,
    );
  }
}
