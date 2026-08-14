// Navigation domain models (Phase 2 in-app GPS navigation).

/// A single turn-by-turn instruction extracted from the routing provider's
/// response. Empty `instruction` means the provider gave no usable guidance —
/// the UI must show route-progress information instead of fabricating text.
class NavigationStep {
  const NavigationStep({
    required this.instruction,
    required this.maneuverType,
    this.modifier,
    this.name,
    required this.distanceKm,
    required this.durationMin,
    required this.lat,
    required this.lng,
  });

  final String instruction;
  final String
      maneuverType; // depart | turn | new name | continue | arrive | roundabout | ...
  final String? modifier; // left | right | straight | slight left | uturn | ...
  final String? name; // road name when the provider supplies one
  final double distanceKm;
  final int durationMin;
  final double lat;
  final double lng;

  factory NavigationStep.fromJson(Map<String, dynamic> json) {
    return NavigationStep(
      instruction: json['instruction'] as String? ?? '',
      maneuverType: json['maneuver_type'] as String? ?? 'continue',
      modifier: json['modifier'] as String?,
      name: json['name'] as String?,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
      durationMin: (json['duration_min'] as num?)?.toInt() ?? 0,
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Whether this step is a usable turn-by-turn instruction (the provider
  /// actually described the maneuver rather than returning an empty shape).
  bool get isUsable => instruction.isNotEmpty && maneuverType != 'depart';
}

/// A live GPS reading from the device (or the test fake).
class LocationUpdate {
  const LocationUpdate({
    required this.lat,
    required this.lng,
    required this.timestamp,
    this.accuracyMeters,
    this.speedMps,
    this.headingDegrees,
  });

  final double lat;
  final double lng;
  final DateTime timestamp;

  /// Horizontal accuracy in meters, when the device reports it.
  final double? accuracyMeters;

  /// Ground speed in m/s, when the device reports it.
  final double? speedMps;

  /// Bearing in degrees (0–360, 0 = north), when the device reports it.
  final double? headingDegrees;

  bool get hasUsableHeading =>
      headingDegrees != null && headingDegrees! >= 0 && (speedMps ?? 0) > 1.5;

  bool get hasUsableSpeed => (speedMps ?? 0) >= 0;
}

/// A point the user wants to visit along the way (added during navigation)
/// or the final destination being navigated to.
class NavStop {
  const NavStop({
    required this.label,
    required this.lat,
    required this.lng,
  });

  final String label;
  final double lat;
  final double lng;
}

/// Current route-following progress relative to the active route geometry.
class RouteProgress {
  const RouteProgress({
    required this.remainingKm,
    required this.remainingDurationMin,
    required this.progress,
    required this.distanceFromRouteM,
    required this.nearestLat,
    required this.nearestLng,
  });

  final double remainingKm;
  final int remainingDurationMin;

  /// Fraction 0.0–1.0 of the route already travelled along its geometry.
  final double progress;

  /// Distance in meters from the current position to the nearest route point.
  final double distanceFromRouteM;

  final double nearestLat;
  final double nearestLng;

  /// Estimated arrival time given [now].
  DateTime eta({required DateTime now}) =>
      now.add(Duration(minutes: remainingDurationMin));
}

/// Lifecycle state of an in-app navigation session.
enum NavigationStatus {
  idle,
  starting,
  navigating,
  recalculating,
  offRoute,
  arrived,
  paused,
  error,
  locationUnavailable,
}

extension NavigationStatusX on NavigationStatus {
  bool get isActive =>
      this == NavigationStatus.starting ||
      this == NavigationStatus.navigating ||
      this == NavigationStatus.recalculating ||
      this == NavigationStatus.offRoute ||
      this == NavigationStatus.paused;

  bool get isErrorLike =>
      this == NavigationStatus.error ||
      this == NavigationStatus.locationUnavailable;
}
