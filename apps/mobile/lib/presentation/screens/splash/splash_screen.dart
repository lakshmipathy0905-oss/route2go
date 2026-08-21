import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/local/preferences_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../widgets/brand_widgets.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  bool _handled = false;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();
    _routeAfterLoad();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _routeAfterLoad() async {
    try {
      final store = await ref.read(preferencesStoreProvider.future);
      if (!mounted || _handled) return;
      _handled = true;
      context
          .go(store.onboardingComplete ? AppRoutes.home : AppRoutes.onboarding);
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _RouteTrail(),
          SafeArea(
            child: Column(
              children: [
                const Spacer(),
                ScaleTransition(
                  scale: Tween(begin: 0.96, end: 1.04).animate(
                    CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                  ),
                  child: Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: AppShadows.float,
                    ),
                    padding: const EdgeInsets.all(6),
                    child: const BrandIcon(size: 92),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const Text(
                  Brand.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const SloganText(size: 15, invert: true),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  Brand.tagline,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.6,
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        minimumSize: const Size.fromHeight(54),
                      ),
                      onPressed: () => context.go(AppRoutes.onboarding),
                      child: const Text('Get Started'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Subtle animated route trail (dashed line + moving node) on the splash.
class _RouteTrail extends StatefulWidget {
  const _RouteTrail();

  @override
  State<_RouteTrail> createState() => _RouteTrailState();
}

class _RouteTrailState extends State<_RouteTrail>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    )..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(
        painter: _RouteTrailPainter(progress: _c.value),
      ),
    );
  }
}

class _RouteTrailPainter extends CustomPainter {
  const _RouteTrailPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final white = Colors.white.withValues(alpha: 0.14);
    final paint = Paint()
      ..color = white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final points = <Offset>[
      Offset(size.width * 0.06, size.height * 0.16),
      Offset(size.width * 0.3, size.height * 0.3),
      Offset(size.width * 0.62, size.height * 0.18),
      Offset(size.width * 0.9, size.height * 0.34),
    ];

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);

    // Dashed overlay for a "route in progress" feel.
    final dash = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    // Moving node along the path.
    final metric = path.computeMetrics().first;
    final offset =
        metric.getTangentForOffset(metric.length * progress)!.position;
    canvas.drawCircle(offset, 6, dash);

    // Stationary node dots.
    for (final p in points) {
      canvas.drawCircle(p, 4, Paint()..color = white);
    }
  }

  @override
  bool shouldRepaint(covariant _RouteTrailPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
