import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Streams network connectivity for the OfflineBanner requirement: every
/// screen that can serve cached data shows "You're offline" instead of a
/// spinner or crash (spec Section 3.11 / admin checklist item 3).
final connectivityProvider = StreamProvider<bool>((ref) {
  return Connectivity()
      .onConnectivityChanged
      .map(
        (results) => !results.contains(ConnectivityResult.none),
      )
      .distinct();
});

/// Non-stream convenience for one-off checks inside actions.
final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityProvider).valueOrNull ?? true;
});
