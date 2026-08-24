import 'package:flutter/material.dart';

/// Accessibility helper for respecting user's motion preferences (spec Section 25.2).
///
/// Use this wrapper for animations that should be disabled when the user
/// has enabled "Reduce Motion" / "Remove Animations" in system settings.
class RespectMotion extends StatelessWidget {
  const RespectMotion({
    super.key,
    required this.child,
    this.animation,
    this.duration = const Duration(milliseconds: 300),
  });

  final Widget child;
  final Animation<double>? animation;
  final Duration duration;

  bool _reduceMotion(BuildContext context) {
    return MediaQuery.disableAnimationsOf(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion(context)) {
      return child;
    }
    if (animation != null) {
      return AnimatedBuilder(
        animation: animation!,
        builder: (context, child) => this.child,
      );
    }
    return AnimatedSwitcher(
      duration: duration,
      child: child,
    );
  }
}

/// Returns the appropriate duration based on motion preference.
/// Returns Duration.zero when reduce motion is enabled.
Duration respectMotionDuration(
  BuildContext context,
  Duration normalDuration,
) {
  if (MediaQuery.disableAnimationsOf(context)) {
    return Duration.zero;
  }
  return normalDuration;
}

/// Returns the appropriate curve based on motion preference.
/// Returns a linear curve when reduce motion is enabled.
Curve respectMotionCurve(BuildContext context, Curve normalCurve) {
  if (MediaQuery.disableAnimationsOf(context)) {
    return Curves.linear;
  }
  return normalCurve;
}
