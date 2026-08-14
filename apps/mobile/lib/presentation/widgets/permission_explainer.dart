import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// In-app "Permission Explainer" — shown BEFORE any native permission prompt
/// so the OS prompt is never the user's first explanation of why Route2Go
/// wants access (App Store Guideline 5.1.1 / Play User Data policy).
class PermissionExplainer extends StatelessWidget {
  const PermissionExplainer({
    super.key,
    required this.icon,
    required this.title,
    required this.reasons,
    required this.permissionLabel,
    this.onRequest,
  });

  final IconData icon;
  final String title;
  final List<String> reasons;
  final String permissionLabel;
  final VoidCallback? onRequest;

  Future<void> showModal(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
      ),
      builder: (context) => this,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(icon, size: 48, color: AppColors.primary),
            const SizedBox(height: AppSpacing.md),
            Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.lg),
            ...reasons.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_outline, size: 18, color: AppColors.accent),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(r, style: Theme.of(context).textTheme.bodyLarge)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (onRequest != null)
              ElevatedButton(onPressed: onRequest, child: Text(permissionLabel))
            else
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(permissionLabel),
              ),
            if (onRequest == null) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Not now'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}