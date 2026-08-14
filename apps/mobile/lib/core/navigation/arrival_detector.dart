/// Detects arrival at the final destination using a combination of remaining
/// route distance, route progress, and current movement speed. Uses a small
/// debounce so a GPS blip near the destination does not fire repeated
/// "arrived" announcements.
class ArrivalDetector {
  ArrivalDetector({
    this.arrivalRadiusM = 150,
    this.minProgress = 0.995,
    this.stillSpeedMps = 4.0,
    this.requiredSamples = 3,
  });

  /// Remaining route distance under which arrival is plausible.
  final double arrivalRadiusM;

  /// Progress fraction above which arrival is plausible.
  final double minProgress;

  /// Speed (m/s) below which the user is treated as having stopped.
  final double stillSpeedMps;

  /// Consecutive qualifying readings before arrival is confirmed.
  final int requiredSamples;

  bool _arrived = false;
  int _samples = 0;

  bool get isArrived => _arrived;

  bool update({
    required double remainingKm,
    required double progress,
    required double speedMps,
  }) {
    if (_arrived) return true;

    final nearDestination =
        remainingKm <= (arrivalRadiusM / 1000) || progress >= minProgress;
    final movingSlowly = speedMps >= 0 && speedMps <= stillSpeedMps;

    if (nearDestination && movingSlowly) {
      _samples++;
      if (_samples >= requiredSamples) {
        _arrived = true;
      }
    } else {
      _samples = 0;
    }
    return _arrived;
  }

  void reset() {
    _arrived = false;
    _samples = 0;
  }
}
