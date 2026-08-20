/// Live details for one specific hotel, from `/hotel-details` (spec 2.5).
///
/// Always the real listing from the upstream provider. Every field is
/// optional: the backend returns `details: null` when no live listing matches
/// the requested hotel, and the UI degrades to the existing no-photo card.
class HotelDetails {
  const HotelDetails({
    required this.name,
    this.photoUrl,
    this.rating,
    this.reviewCount,
    this.pricePerNight,
    this.bookingUrl,
  });

  final String name;
  final String? photoUrl;
  final double? rating;
  final int? reviewCount;
  final double? pricePerNight;
  final String? bookingUrl;

  factory HotelDetails.fromJson(Map<String, dynamic> json) {
    return HotelDetails(
      name: json['name'] as String? ?? '',
      photoUrl: json['photo_url'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      reviewCount: (json['review_count'] as num?)?.toInt(),
      pricePerNight: (json['price_per_night'] as num?)?.toDouble(),
      bookingUrl: json['booking_url'] as String?,
    );
  }
}
