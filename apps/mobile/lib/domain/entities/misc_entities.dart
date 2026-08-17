/// A server-side feature flag. Clients may only READ flags; only a Super
/// Admin can change them (spec 2.14). Never let a client toggle its own flag.
class FeatureFlag {
  const FeatureFlag(
      {required this.key, required this.enabled, this.description});

  final String key;
  final bool enabled;
  final String? description;

  factory FeatureFlag.fromJson(Map<String, dynamic> json) {
    return FeatureFlag(
      key: json['key'] as String,
      enabled: json['enabled'] as bool? ?? false,
      description: json['description'] as String?,
    );
  }
}

/// Global search result across places/hotels/routes/saved items (spec 5.14).
class SearchResult {
  const SearchResult({
    required this.kind, // place | hotel | route | saved_trip | place_category
    required this.id,
    required this.title,
    required this.subtitle,
    this.lat,
    this.lng,
    this.category,
    this.city,
  });

  final String kind;
  final String id;
  final String title;
  final String subtitle;
  final double? lat;
  final double? lng;

  /// Optional category/city enrichment from the server (Photon/Overpass or the
  /// DB). Absent when the server had nothing usable — never fabricated. The
  /// destination sheet renders these as e.g. "Cafe · Bengaluru".
  final String? category;
  final String? city;

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      kind: json['kind'] as String,
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      category: json['category'] as String?,
      city: json['city'] as String?,
    );
  }
}

/// A global search response: the results plus whether the nearby (POI)
/// provider was unavailable for this request, so callers can distinguish
/// "no matches" from "matches exist but couldn't be fetched".
class SearchResponse {
  const SearchResponse({
    required this.results,
    required this.nearbyDegraded,
  });

  final List<SearchResult> results;
  final bool nearbyDegraded;
}
