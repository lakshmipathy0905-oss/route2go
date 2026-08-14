import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../providers/favorites_search_provider.dart';

/// Phase-2 gated section (spec 2.14).
///
/// Renders `child` only when the feature flag `flagKey` is enabled (from the
/// server via /feature-flags). When disabled, shows an honest "coming soon"
/// shell instead — the UI never fakes availability of a feature that isn't
/// switched on, and never lets a client toggle its own flag.
class Phase2Gate extends ConsumerWidget {
  const Phase2Gate({
    super.key,
    required this.flagKey,
    required this.title,
    this.subtitle,
    this.icon,
    required this.child,
  });

  final String flagKey;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(featureFlagsProvider).valueOrNull ?? const <String, bool>{};
    final enabled = flags[flagKey] ?? false;
    if (enabled) return child;
    return _Phase2Shell(title: title, subtitle: subtitle, icon: icon);
  }
}

class _Phase2Shell extends StatelessWidget {
  const _Phase2Shell({required this.title, this.subtitle, this.icon});

  final String title;
  final String? subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Icon(icon ?? Icons.auto_awesome_outlined, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '$subtitle  Coming soon.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}