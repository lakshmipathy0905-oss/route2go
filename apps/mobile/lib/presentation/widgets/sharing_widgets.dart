import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Numeric formatting helpers shared across screens.
String formatCurrency(double value) =>
    '₹${value < 0 ? '-' : ''}${value.abs().toStringAsFixed(0)}';

String formatDistance(double km) =>
    km >= 100 ? '${km.toStringAsFixed(0)} km' : '${km.toStringAsFixed(1)} km';

String formatDuration(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  return '${h}h ${m}m';
}

/// Share text for a map-tab destination when no route has been calculated yet.
/// Honest by construction: the place (with category/city when known) and its
/// coordinates only — never a fabricated "Calculating..." or a route that does
/// not exist. Pure so it can be unit-tested without the platform share sheet.
String buildDestinationShareText({
  required String title,
  String? subtitle,
  String? category,
  String? city,
  double? lat,
  double? lng,
}) {
  final lines = <String>[title];
  final categoryLabel = category?.trim() ?? '';
  final cityLabel = city?.trim() ?? '';
  if (categoryLabel.isNotEmpty || cityLabel.isNotEmpty) {
    // Mirrors the destination sheet: "Place · City" is the honest fallback
    // when the category is unknown.
    lines.add(categoryLabel.isNotEmpty
        ? (cityLabel.isNotEmpty ? '$categoryLabel · $cityLabel' : categoryLabel)
        : 'Place · $cityLabel');
  }
  final sub = subtitle?.trim() ?? '';
  if (sub.isNotEmpty) lines.add(sub);
  if (lat != null && lng != null) {
    lines.add('Location: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}');
  }
  return lines.join('\n');
}

/// Share text for an existing calculated route (e.g. the route-results screen
/// or a saved trip): real route info + both coordinates so a recipient can
/// open the same places. Route2Go has no deep-link URL scheme configured, so a
/// route2go:// link would be non-functional and is never emitted. Pure.
String buildRouteShareText({
  required String originLabel,
  required String destinationLabel,
  required String routeLabel,
  required double distanceKm,
  required int durationMin,
  double? totalCost,
  double? originLat,
  double? originLng,
  double? destinationLat,
  double? destinationLng,
}) {
  final lines = <String>['Route2Go route'];
  lines.add('$originLabel → $destinationLabel');
  lines.add(
      '$routeLabel · ${formatDistance(distanceKm)} · ${formatDuration(durationMin)}');
  if (totalCost != null && totalCost > 0) {
    lines.add('Est. total: ${formatCurrency(totalCost)}');
  }
  if (originLat != null &&
      originLng != null &&
      destinationLat != null &&
      destinationLng != null) {
    lines.add(
        'Origin: ${originLat.toStringAsFixed(6)}, ${originLng.toStringAsFixed(6)}');
    lines.add(
        'Destination: ${destinationLat.toStringAsFixed(6)}, ${destinationLng.toStringAsFixed(6)}');
  }
  return lines.join('\n');
}

/// Star rating display (place/hotel cards). Always paired with the numeric
/// rating so status/quality is never conveyed by color or stars alone.
class StarRating extends StatelessWidget {
  const StarRating({super.key, this.rating, this.size = 16});

  final double? rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (rating == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_outline,
              size: 16, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.xs),
          Text('No rating yet', style: Theme.of(context).textTheme.bodySmall),
        ],
      );
    }
    final full = rating!.floor();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          Icon(
            i < full ? Icons.star : Icons.star_border,
            size: size,
            color: AppColors.warning,
          ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          rating!.toStringAsFixed(1),
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// "Partner" / "Sponsored" disclosure label at the same visual weight as the
/// rating badge — required by spec 23.2 and both stores' anti-deception
/// policies (Section 3.6). Never rendered with the accent color or made
/// smaller than adjacent badges so it can't be missed.
class DisclosureBadge extends StatelessWidget {
  const DisclosureBadge({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: AppColors.textSecondary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.business_outlined,
              size: 12, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
          ),
        ],
      ),
    );
  }
}

/// Small filter chip used by Places and Stays filters.
class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.primary : AppColors.surface;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected
                  ? AppColors.primary
                  : AppColors.textSecondary.withValues(alpha: 0.2)),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: selected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

/// Section header used consistently across list screens.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Terse helper text caption.
class HintText extends StatelessWidget {
  const HintText(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .bodySmall
          ?.copyWith(color: AppColors.textSecondary),
    );
  }
}

/// Deterministic color from a string (used for avatar placeholders).
Color colorFromSeed(String seed) {
  final hash =
      seed.codeUnits.fold<int>(0, (acc, c) => (acc * 31 + c) & 0x7fffffff);
  return HSLColor.fromAHSL(
    1,
    (hash % 360).toDouble(),
    0.5,
    0.45,
  ).toColor();
}

/// Truncate long strings without breaking the layout.
String ellipsize(String s, int max) =>
    s.length <= max ? s : '${s.substring(0, max - 1)}…';

double deg2rad(double d) => d * math.pi / 180;

/// Simple two-place haversine distance for detour computations on-device
/// (kept mirror-synchronous with the server's provider helper).
double haversineDistanceKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = deg2rad(lat2 - lat1);
  final dLng = deg2rad(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(deg2rad(lat1)) *
          math.cos(deg2rad(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}
