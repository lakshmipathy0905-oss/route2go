/// Real off-route detection with hysteresis + debouncing so navigation never
/// flips between on-route/off-route on a single noisy GPS fix.
///
/// Two thresholds form a dead-band:
///  - [offRouteThresholdM]: sustained distance BEYOND this marks off-route.
///  - [onRouteThresholdM]: dropping BELOW this clears off-route (recovery).
///
/// A reading must stay beyond the trigger threshold for [requiredSamples]
/// consecutive samples before off-route is confirmed, and must stay below the
/// recovery threshold for [requiredRecoverySamples] before it clears. This
/// absorbs temporary GPS noise and brief run-offs while still catching a
/// sustained, meaningful deviation.
class OffRouteDetector {
  OffRouteDetector({
    required this.offRouteThresholdM,
    required this.onRouteThresholdM,
    this.requiredSamples = 3,
    this.requiredRecoverySamples = 2,
  }) : assert(offRouteThresholdM > onRouteThresholdM,
            'off-route threshold must exceed the on-route recovery threshold');

  final double offRouteThresholdM;
  final double onRouteThresholdM;
  final int requiredSamples;
  final int requiredRecoverySamples;

  bool _offRoute = false;
  int _offRouteSamples = 0;
  int _recoverySamples = 0;

  bool get isOffRoute => _offRoute;

  /// Feeds one distance-from-route reading (meters) and returns whether the
  /// detector now considers the user off route.
  bool update({required double distanceFromRouteM}) {
    if (distanceFromRouteM > offRouteThresholdM) {
      _offRouteSamples++;
      _recoverySamples = 0;
      if (_offRouteSamples >= requiredSamples) {
        _offRoute = true;
      }
    } else if (distanceFromRouteM < onRouteThresholdM) {
      _recoverySamples++;
      _offRouteSamples = 0;
      if (_recoverySamples >= requiredRecoverySamples) {
        _offRoute = false;
      }
    } else {
      // Inside the dead-band: keep current state, reset the debounce counters
      // so a stall in the middle never accumulates towards a transition.
      _offRouteSamples = 0;
      _recoverySamples = 0;
    }
    return _offRoute;
  }

  void reset() {
    _offRoute = false;
    _offRouteSamples = 0;
    _recoverySamples = 0;
  }
}
