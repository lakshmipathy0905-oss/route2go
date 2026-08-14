/// A geocoded search result from the Location Picker (spec 2.2).
class GeoPlace {
  const GeoPlace({
    required this.label,
    required this.lat,
    required this.lng,
    this.subtitle,
  });

  final String label;
  final double lat;
  final double lng;
  final String? subtitle;

  factory GeoPlace.fromJson(Map<String, dynamic> json) {
    return GeoPlace(
      label: json['label'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      subtitle: json['subtitle'] as String?,
    );
  }
}
