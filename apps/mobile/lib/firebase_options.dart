// GENERATED PLACEHOLDER — DO NOT USE AS-IS.
//
// This file must be regenerated for your real Firebase project before the
// app will run. From apps/mobile/, run:
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure
//
// That command talks to your Firebase project and overwrites this file with
// real, correct platform configuration (API keys, app IDs, etc. — these are
// safe to commit for Firebase client apps, unlike server secrets). Values
// below are structurally valid but non-functional placeholders so the
// project compiles for review before you've run flutterfire configure.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Web is not configured. Run `flutterfire configure` and add a web app in Firebase.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform. Run `flutterfire configure`.',
        );
    }
  }

  static const android = FirebaseOptions(
    apiKey: 'REPLACE_WITH_FLUTTERFIRE_CONFIGURE_OUTPUT',
    appId: 'REPLACE_WITH_FLUTTERFIRE_CONFIGURE_OUTPUT',
    messagingSenderId: 'REPLACE_WITH_FLUTTERFIRE_CONFIGURE_OUTPUT',
    projectId: 'REPLACE_WITH_FLUTTERFIRE_CONFIGURE_OUTPUT',
    storageBucket: 'REPLACE_WITH_FLUTTERFIRE_CONFIGURE_OUTPUT',
  );

  static const ios = FirebaseOptions(
    apiKey: 'REPLACE_WITH_FLUTTERFIRE_CONFIGURE_OUTPUT',
    appId: 'REPLACE_WITH_FLUTTERFIRE_CONFIGURE_OUTPUT',
    messagingSenderId: 'REPLACE_WITH_FLUTTERFIRE_CONFIGURE_OUTPUT',
    projectId: 'REPLACE_WITH_FLUTTERFIRE_CONFIGURE_OUTPUT',
    storageBucket: 'REPLACE_WITH_FLUTTERFIRE_CONFIGURE_OUTPUT',
    iosBundleId: 'com.route2go.app',
  );
}
