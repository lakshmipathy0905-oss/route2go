/// A hotel/stay result from `stays-near-route` (spec Section 5.9).
class Stay {
  const Stay({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.pricePerNight,
    this.rating,
    this.amenities = const [],
    this.partnerId,
    this.partnerName,
    this.commission,
    this.isSponsored = false,
    this.bookingUrl,
    this.distanceFromRouteKm,
  });

  final String id;
  final String name;
  final double lat;
  final double lng;
  final double? pricePerNight;
  final double? rating;
  final List<String> amenities;
  final String? partnerId;
  final String? partnerName;
  final double? commission;
  final bool isSponsored;

  /// Partner deep link. Opens the provider's site; Route2Go logs the click
  /// via POST /affiliate/click before redirecting.
  final String? bookingUrl;
  final double? distanceFromRouteKm;

  factory Stay.fromJson(Map<String, dynamic> json) {
    return Stay(
      id: json['id'] as String,
      name: json['name'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      pricePerNight: (json['price_per_night'] as num?)?.toDouble(),
      rating: (json['rating'] as num?)?.toDouble(),
      amenities:
          (json['amenities'] as List<dynamic>? ?? const []).cast<String>(),
      partnerId: json['partner_id'] as String?,
      partnerName: json['partner_name'] as String?,
      commission: (json['commission'] as num?)?.toDouble(),
      isSponsored: json['is_sponsored'] as bool? ?? false,
      bookingUrl: json['booking_url'] as String?,
      distanceFromRouteKm: (json['distance_from_route_km'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'lat': lat,
        'lng': lng,
        if (pricePerNight != null) 'price_per_night': pricePerNight,
        if (rating != null) 'rating': rating,
        'amenities': amenities,
        if (partnerId != null) 'partner_id': partnerId,
        if (partnerName != null) 'partner_name': partnerName,
        if (commission != null) 'commission': commission,
        'is_sponsored': isSponsored,
        if (bookingUrl != null) 'booking_url': bookingUrl,
        if (distanceFromRouteKm != null)
          'distance_from_route_km': distanceFromRouteKm,
      };
}
