import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/local/preferences_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    // Target: cold start to first interactive frame < 2.5s (spec Section 25).
    // Returning users who finished onboarding skip straight to Home; only
    // first-time users see the onboarding cards. The flag is read after the
    // local preferences store resolves (never at post-frame, where the store
    // may still be loading).
    _routeAfterLoad();
  }

  Future<void> _routeAfterLoad() async {
    try {
      final store = await ref.read(preferencesStoreProvider.future);
      if (!mounted || _handled) return;
      _handled = true;
      context.go(
          store.onboardingComplete ? AppRoutes.home : AppRoutes.onboarding);
    } catch (_) {
      if (!mounted || _handled) return;
      _handled = true;
      context.go(AppRoutes.onboarding);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.route_outlined,
                  color: AppColors.primary, size: 44),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Route2Go',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Route. Cost. Places. One trip.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
