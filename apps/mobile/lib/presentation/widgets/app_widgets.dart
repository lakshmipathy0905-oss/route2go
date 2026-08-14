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

/// Standard empty state.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState(
      {super.key, required this.message, this.icon = Icons.map_outlined});
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.md),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

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
