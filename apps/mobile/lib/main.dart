import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/notifications/fcm_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') {
      rethrow; // any other Firebase init failure should still surface, not be swallowed
    }
    // Native Android layer already initialized the default app from
    // google-services.json before Dart ran — expected, not an error.
  }

  // Crashlytics: catch Flutter framework errors and uncaught async errors.
  // Never logs tokens, auth headers or precise location — see SECURITY.md.
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // Supabase client here uses only the anon key — safe for the mobile app.
  // The service-role key NEVER ships in this app; privileged writes go
  // through the Edge Functions in supabase/functions/.
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL', defaultValue: ''),
    publishableKey:
        const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: ''),
  );

  runApp(const ProviderScope(child: Route2GoApp()));
}

class Route2GoApp extends ConsumerWidget {
  const Route2GoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Register the FCM token lazily on first launch (spec 2.10). Runs
    // post-frame so it never blocks first paint.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(fcmServiceProvider).init());
    });

    return MaterialApp.router(
      title: 'Route2Go',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
    );
  }
}
