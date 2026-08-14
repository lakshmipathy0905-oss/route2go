/// A place of interest near a route (spec Section 5.8).
class Place {
  const Place({
    required this.id,
    required this.name,
    this.categoryId,
    this.category,
    required this.lat,
    required this.lng,
    this.photos = const [],
    this.hours,
    this.entryFee,
    this.rating,
    this.description,
    this.detourKm,
    this.detourDurationMin,
    this.detourAddedCost,
  });

  final String id;
  final String name;
  final String? categoryId;
  final String? category;
  final double lat;
  final double lng;
  final List<String> photos;
  final String? hours;
  final double? entryFee;
  final double? rating;
  final String? description;

  /// Real delta of adding this place to the trip — always surfaced before
  /// the user adds it; never presented as free (spec: "Intelligent Detour").
  final double? detourKm;
  final int? detourDurationMin;
  final double? detourAddedCost;

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      id: json['id'] as String,
      name: json['name'] as String,
      categoryId: json['category_id'] as String?,
      category: json['category'] as String?,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      photos: (json['photos'] as List<dynamic>? ?? const []).cast<String>(),
      hours: json['hours'] as String?,
      entryFee: (json['entry_fee'] as num?)?.toDouble(),
      rating: (json['rating'] as num?)?.toDouble(),
      description: json['description'] as String?,
      detourKm: (json['detour_km'] as num?)?.toDouble(),
      detourDurationMin: (json['detour_duration_min'] as num?)?.toInt(),
      detourAddedCost: (json['detour_added_cost'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        if (categoryId != null) 'category_id': categoryId,
        'lat': lat,
        'lng': lng,
        if (entryFee != null) 'entry_fee': entryFee,
        if (rating != null) 'rating': rating,
        if (detourKm != null) 'detour_km': detourKm,
        if (detourDurationMin != null) 'detour_duration_min': detourDurationMin,
        if (detourAddedCost != null) 'detour_added_cost': detourAddedCost,
      };
}

/// Place categories available for filtering (spec Section 5.8).
class PlaceCategory {
  const PlaceCategory({required this.id, required this.name});
  final String id;
  final String name;

  factory PlaceCategory.fromJson(Map<String, dynamic> json) {
    return PlaceCategory(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }
}
