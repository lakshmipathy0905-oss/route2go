import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/notification_repository.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/providers/notifications_provider.dart';

/// FCM wiring for push notifications (spec 2.10).
///
/// Responsibilities:
///   - Request push permission lazily on first launch (iOS) and after the
///     user signs in (Android 13+ needs no pre-signup request, but iOS does).
///   - Retrieve the FCM token and register it with the server via
///     POST /notifications (register_token) so the backend can target this
///     device.
///   - Listen for foreground messages (onMessage) so the in-app feed can be
///     refreshed without a manual pull.
///
/// Tokens are registered only while signed in; signing out intentionally does
/// NOT unregister the token (a token is device-scoped, and Firebase dedupes),
/// but no notifications are sent while the user is signed out.
class FcmService {
  FcmService(this._ref);

  final Ref _ref;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Called once at app startup.
  Future<void> init() async {
    if (kIsWeb) return; // Web push is out of scope for MVP notifications.
    await _requestPermissionAndRegister();
    // Refresh the in-app feed when a message arrives while the app is open.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final userId = _ref.read(authStateProvider).valueOrNull?.uid;
      if (userId != null) {
        unawaited(_ref.read(notificationsProvider.notifier).refresh());
      }
    });
  }

  Future<void> _requestPermissionAndRegister() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await _messaging.getToken();
      if (token == null) return;

      final userId = _ref.read(authStateProvider).valueOrNull?.uid;
      if (userId == null) return; // Guests do not receive push.

      // Best-effort: a failed registration must never block the app.
      try {
        await _ref.read(notificationRepositoryProvider).registerFcmToken(token);
      } catch (_) {
        debugPrint('FCM token registration deferred (will retry on next launch).');
      }
    } catch (_) {
      // Push is an enhancement; never throw out of init().
    }
  }
}

/// Provider so the service can be invoked from main()/splash.
final fcmServiceProvider = Provider<FcmService>((ref) => FcmService(ref));