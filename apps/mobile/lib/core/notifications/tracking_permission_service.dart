import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App Tracking Transparency (iOS). Declared in Info.plist and now also
/// *invoked at runtime* (spec/store-compliance gap). The first time the app
/// runs on iOS, the system prompt appears; the user's answer gates analytics:
///   - authorized  -> analytics stays enabled (subject to the user's explicit
///                    opt-out in Settings, enforced in ProfileNotifier)
///   - denied/notDetermined/restricted -> analytics disabled immediately
///
/// On Android there is no ATT concept — this is a no-op and analytics is
/// enabled (again subject to the Settings opt-out).
class TrackingPermissionService {
  Future<void> requestAndGateAnalytics() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      final status =
          await AppTrackingTransparency.requestTrackingAuthorization();
      final authorized = status == TrackingStatus.authorized;
      await FirebaseAnalytics.instance
          .setAnalyticsCollectionEnabled(authorized);
    } catch (_) {
      // Never let a permission flow break launch; default = no analytics
      // (conservative) if the request fails.
      try {
        await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(false);
      } catch (_) {}
    }
  }
}

final trackingPermissionServiceProvider = Provider<TrackingPermissionService>(
  (ref) => TrackingPermissionService(),
);
