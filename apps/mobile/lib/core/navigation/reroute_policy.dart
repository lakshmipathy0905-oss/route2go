import 'dart:async';
import 'dart:math' as math;

/// Guards reroute requests so live navigation never hammers the routing
/// provider (a public OSRM server may rate-limit).
///
/// Rules:
///  - [cooldown]: minimum time between two reroute requests.
///  - dedupe: a reroute already in flight is never re-issued.
///  - [backoffBase]/[maxBackoff]: on failure, retry is delayed with
///    exponential backoff instead of immediately retrying.
class ReroutePolicy {
  ReroutePolicy({
    this.cooldown = const Duration(seconds: 20),
    this.backoffBase = const Duration(seconds: 5),
    this.maxBackoff = const Duration(seconds: 120),
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final Duration cooldown;
  final Duration backoffBase;
  final Duration maxBackoff;
  final DateTime Function() _now;

  DateTime? _lastRequestAt;
  DateTime? _nextAllowedAt;
  bool _inFlight = false;
  int _failures = 0;

  bool get isInFlight => _inFlight;

  /// Whether a new reroute may be issued right now (respecting cooldown and
  /// in-flight deduplication).
  bool canRequest() {
    if (_inFlight) return false;
    final now = _now();
    if (_nextAllowedAt != null && now.isBefore(_nextAllowedAt!)) return false;
    return true;
  }

  /// Marks the start of a reroute request. Call only after [canRequest].
  void requestStarted() {
    _inFlight = true;
    _lastRequestAt = _now();
  }

  /// Marks the end of a reroute attempt. [success] controls backoff.
  void requestFinished({required bool success}) {
    _inFlight = false;
    if (success) {
      _failures = 0;
      _nextAllowedAt = _lastRequestAt!.add(cooldown);
    } else {
      _failures++;
      final delayMs = (backoffBase.inMilliseconds * math.pow(2, _failures - 1))
          .clamp(0, maxBackoff.inMilliseconds)
          .toInt();
      _nextAllowedAt = _now().add(Duration(milliseconds: delayMs));
    }
  }

  /// Convenience: waits until a request is allowed (used before issuing).
  Future<void> waitUntilAllowed() async {
    while (!canRequest()) {
      final now = _now();
      final next = _nextAllowedAt ?? now;
      final waitMs = next.isAfter(now) ? next.difference(now).inMilliseconds : 0;
      await Future<void>.delayed(Duration(milliseconds: waitMs > 0 ? waitMs : 1));
    }
  }

  void reset() {
    _lastRequestAt = null;
    _nextAllowedAt = null;
    _inFlight = false;
    _failures = 0;
  }
}