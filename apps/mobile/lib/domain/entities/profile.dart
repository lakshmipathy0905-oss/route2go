/// User profile + preferences (spec Section 5.3 / Screen 45).
class Profile {
  const Profile({
    this.name,
    this.photoUrl,
    this.language = 'en',
    this.homeLocationLat,
    this.homeLocationLng,
    this.homeLocationLabel,
    this.travelPref = 'balanced',
    this.accommodationPref,
    this.analyticsOptOut = false,
  });

  final String? name;
  final String? photoUrl;
  final String language;
  final double? homeLocationLat;
  final double? homeLocationLng;
  final String? homeLocationLabel;
  final String travelPref; // budget | balanced | premium
  final String? accommodationPref;
  final bool analyticsOptOut;

  Profile copyWith({
    String? name,
    String? photoUrl,
    String? language,
    double? homeLocationLat,
    double? homeLocationLng,
    String? homeLocationLabel,
    String? travelPref,
    String? accommodationPref,
    bool? analyticsOptOut,
    bool clearHome = false,
  }) {
    return Profile(
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      language: language ?? this.language,
      homeLocationLat:
          clearHome ? null : (homeLocationLat ?? this.homeLocationLat),
      homeLocationLng:
          clearHome ? null : (homeLocationLng ?? this.homeLocationLng),
      homeLocationLabel:
          clearHome ? null : (homeLocationLabel ?? this.homeLocationLabel),
      travelPref: travelPref ?? this.travelPref,
      accommodationPref: accommodationPref ?? this.accommodationPref,
      analyticsOptOut: analyticsOptOut ?? this.analyticsOptOut,
    );
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      name: json['name'] as String?,
      photoUrl: json['photo_url'] as String?,
      language: json['language'] as String? ?? 'en',
      homeLocationLat: (json['home_location_lat'] as num?)?.toDouble(),
      homeLocationLng: (json['home_location_lng'] as num?)?.toDouble(),
      homeLocationLabel: json['home_location_label'] as String?,
      travelPref: json['travel_pref'] as String? ?? 'balanced',
      accommodationPref: json['accommodation_pref'] as String?,
      analyticsOptOut: json['analytics_opt_out'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (photoUrl != null) 'photo_url': photoUrl,
        'language': language,
        if (homeLocationLat != null) 'home_location_lat': homeLocationLat,
        if (homeLocationLng != null) 'home_location_lng': homeLocationLng,
        if (homeLocationLabel != null) 'home_location_label': homeLocationLabel,
        'travel_pref': travelPref,
        if (accommodationPref != null) 'accommodation_pref': accommodationPref,
        'analytics_opt_out': analyticsOptOut,
      };
}
