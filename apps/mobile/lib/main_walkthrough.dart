import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {}

  try {
    await Supabase.initialize(
      url: const String.fromEnvironment('SUPABASE_URL',
          defaultValue: 'https://example.supabase.co'),
      publishableKey: const String.fromEnvironment('SUPABASE_ANON_KEY',
          defaultValue: 'example'),
    ).timeout(const Duration(seconds: 3));
  } catch (_) {}

  runApp(const ProviderScope(child: WalkthroughApp()));
}

class WalkthroughApp extends ConsumerStatefulWidget {
  const WalkthroughApp({super.key});

  @override
  ConsumerState<WalkthroughApp> createState() => _WalkthroughAppState();
}

class _WalkthroughAppState extends ConsumerState<WalkthroughApp> {
  final List<String> paths = [
    AppRoutes.home,
    AppRoutes.planTrip,
    AppRoutes.locationPicker,
    AppRoutes.routeResults,
    AppRoutes.budgetTracker,
    AppRoutes.places,
    AppRoutes.stays,
    AppRoutes.itinerary,
    AppRoutes.confirmTrip,
    AppRoutes.liveTrip,
    AppRoutes.vehicles,
    AppRoutes.vehicleAdd,
    AppRoutes.notifications,
    AppRoutes.settings,
    AppRoutes.profileEdit,
    AppRoutes.privacy,
    AppRoutes.terms,
    AppRoutes.help,
    AppRoutes.deleteAccount,
    AppRoutes.favorites,
    AppRoutes.search,
    AppRoutes.admin,
    AppRoutes.adminFlags,
    AppRoutes.adminAudit,
    AppRoutes.adminSupport,
    AppRoutes.adminAffiliate,
    AppRoutes.adminUsers,
  ];

  int currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 4), _startWalkthrough);
  }

  void _startWalkthrough() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (currentIndex >= paths.length) {
        timer.cancel();
        return;
      }
      final router = ref.read(routerProvider);
      router.go(paths[currentIndex]);
      currentIndex++;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Route2Go Walkthrough',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
    );
  }
}
