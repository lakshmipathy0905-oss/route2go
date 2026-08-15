import 'route_option.dart';

/// A saved trip summary (spec Section 5.11 / Screen 35).
class TripSummary {
  const TripSummary({
    required this.id,
    required this.originLabel,
    required this.destinationLabel,
    required this.tripType,
    this.startDate,
    this.endDate,
    this.travellers = 1,
    this.budgetTotal,
    this.status = 'draft',
    this.bestRouteCost,
    this.bestDurationMin,
    this.bestDistanceKm,
    this.originLat,
    this.originLng,
    this.destinationLat,
    this.destinationLng,
    this.bestRouteGeometry,
    this.createdAt,
  });

  final String id;
  final String originLabel;
  final String destinationLabel;
  final String tripType;
  final DateTime? startDate;
  final DateTime? endDate;
  final int travellers;
  final double? budgetTotal;
  final String status; // draft | calculated | confirmed | completed | cancelled
  final double? bestRouteCost;
  final int? bestDurationMin;
  final double? bestDistanceKm;
  final double? originLat;
  final double? originLng;
  final double? destinationLat;
  final double? destinationLng;

  /// Best route shape as GeoJSON LineString (verbatim from the routing
  /// provider), used to draw the route on a map. Null when the trip has no
  /// calculated routes yet.
  final Map<String, dynamic>? bestRouteGeometry;

  final DateTime? createdAt;

  /// The best route's polyline as [lng, lat] pairs (GeoJSON order), or null
  /// if no parseable geometry was returned.
  List<List<double>>? get bestRouteCoordinates {
    final g = bestRouteGeometry;
    if (g == null) return null;
    if (g['type'] != 'LineString') return null;
    final coords = g['coordinates'];
    if (coords is! List) return null;
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

  factory TripSummary.fromJson(Map<String, dynamic> json) {
    return TripSummary(
      id: json['id'] as String,
      originLabel: json['origin_label'] as String,
      destinationLabel: json['destination_label'] as String,
      tripType: json['trip_type'] as String,
      startDate: DateTime.tryParse(json['start_date'] as String? ?? ''),
      endDate: DateTime.tryParse(json['end_date'] as String? ?? ''),
      travellers: (json['travellers'] as num?)?.toInt() ?? 1,
      budgetTotal: (json['budget_total'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'draft',
      bestRouteCost: (json['best_route_cost'] as num?)?.toDouble(),
      bestDurationMin: (json['best_duration_min'] as num?)?.toInt(),
      bestDistanceKm: (json['best_distance_km'] as num?)?.toDouble(),
      originLat: (json['origin_lat'] as num?)?.toDouble(),
      originLng: (json['origin_lng'] as num?)?.toDouble(),
      destinationLat: (json['destination_lat'] as num?)?.toDouble(),
      destinationLng: (json['destination_lng'] as num?)?.toDouble(),
      bestRouteGeometry: json['best_route_geometry'] is Map<String, dynamic>
          ? (json['best_route_geometry'] as Map<String, dynamic>)
          : null,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }
}

/// Client-side wrapper pairing a saved trip with the detail view data needed
/// by the shareable trip-summary card (spec 2.8).
class SavedTripDetail {
  const SavedTripDetail({required this.summary, this.routes = const []});

  final TripSummary summary;
  final List<RouteOption> routes;

  RouteOption? get recommendedRoute {
    for (final r in routes) {
      if (r.routeType == 'recommended') return r;
    }
    return routes.isNotEmpty ? routes.first : null;
  }
}
