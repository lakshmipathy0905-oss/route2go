import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/errors/app_exception.dart';

/// Live budget meter (spec Section 13/20): GREEN/YELLOW/RED, always paired
/// with a text label + icon, never color alone (accessibility requirement).
class BudgetMeter extends StatelessWidget {
  const BudgetMeter({
    super.key,
    required this.status,
    required this.usedPct,
    required this.remaining,
  });

  final String status; // GREEN | YELLOW | RED
  final double usedPct;
  final double remaining;

  Color get _color {
    switch (status) {
      case 'RED':
        return AppColors.error;
      case 'YELLOW':
        return AppColors.warning;
      case 'GREEN':
      default:
        return AppColors.success;
    }
  }

  IconData get _icon {
    switch (status) {
      case 'RED':
        return Icons.error_outline;
      case 'YELLOW':
        return Icons.warning_amber_outlined;
      case 'GREEN':
      default:
        return Icons.check_circle_outline;
    }
  }

  String get _label {
    switch (status) {
      case 'RED':
        return 'Over budget';
      case 'YELLOW':
        return 'Near budget limit';
      case 'GREEN':
      default:
        return 'Within budget';
    }
  }

  @override
  Widget build(BuildContext context) {
    final clampedPct = (usedPct / 100).clamp(0.0, 1.0);
    return Semantics(
      label: '$_label, ${usedPct.toStringAsFixed(0)} percent of budget used',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_icon, color: _color, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Text(_label,
                      style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: clampedPct),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 10,
                    backgroundColor: Colors.black.withValues(alpha: 0.06),
                    valueColor: AlwaysStoppedAnimation(_color),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                remaining >= 0
                    ? '₹${remaining.toStringAsFixed(0)} remaining of your budget'
                    : '₹${remaining.abs().toStringAsFixed(0)} over your budget',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small badge showing where a number came from and how fresh it is —
/// required on every estimate-bearing screen (spec: "Estimated / source /
/// last updated / confidence").
class ConfidenceBadge extends StatelessWidget {
  const ConfidenceBadge({super.key, required this.confidence});
  final String confidence; // calculated | verified | estimated | unavailable

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String text;
    switch (confidence) {
      case 'verified':
      case 'calculated':
        color = AppColors.success;
        text = 'Verified estimate';
        break;
      case 'estimated':
        color = AppColors.warning;
        text = 'Estimated';
        break;
      default:
        color = AppColors.textSecondary;
        text = 'Data unavailable';
    }
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Standard loading state — every screen consuming AsyncValue uses this
/// instead of a bare CircularProgressIndicator so loading feels consistent.
class AppLoadingState extends StatelessWidget {
  const AppLoadingState({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(message!, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ],
      ),
    );
  }
}

/// Pulsing placeholder used while lists and images load — keeps loading
/// states feeling designed rather than a bare spinner.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    this.width = double.infinity,
    this.height = 64,
    this.radius = AppRadius.md,
  });

  final double width;
  final double height;
  final double radius;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Standard error state — always human language + retry, never a raw
/// exception string (ERROR UX requirement).
class AppErrorState extends StatelessWidget {
  const AppErrorState({super.key, required this.error, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is AppException
        ? (error as AppException).message
        : 'Something went wrong. Please try again.';
    final retryable =
        error is AppException ? (error as AppException).retryable : true;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 40, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (retryable && onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                  onPressed: onRetry, child: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }
}

/// Standard empty state with optional headline + call-to-action.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    this.title,
    required this.message,
    this.icon = Icons.map_outlined,
    this.action,
  });

  final String? title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (title != null) ...[
              Text(title!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Pulsing placeholder used while lists and images load — keeps loading
/// states feeling designed rather than a bare spinner.

/// Offline banner — shown at the top of any screen serving cached data.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.warning.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm, horizontal: AppSpacing.lg),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, size: 16, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Text(
            "You're offline — showing your last saved trip.",
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
