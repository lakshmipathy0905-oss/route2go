import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/router/app_router.dart';

/// Friendly "you need an account for this" sheet shown when a guest taps an
/// account-bound action. Never a crash, never a dead end — per spec 5.2 the
/// guest can always go back or sign in here.
Future<void> showGuestGate(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (context) => const GuestGateSheet(),
  );
}

class GuestGateSheet extends StatelessWidget {
  const GuestGateSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.account_circle_outlined, size: 48, color: AppColors.primary),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Create an account to keep this',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Saving trips, vehicles, expenses and notifications works with a free Route2Go account. You can plan and estimate routes without one.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: () {
                context.pop();
                context.push(AppRoutes.login);
              },
              child: const Text('Sign in or create an account'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
  }
}