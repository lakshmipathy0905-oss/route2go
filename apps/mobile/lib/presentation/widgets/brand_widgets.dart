import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

/// Brand visual identity: icon-only mark and wordmark lockups.
///
/// [BrandIcon] is the generated travel mark (route line ending in a pin).
class BrandIcon extends StatelessWidget {
  const BrandIcon({
    super.key,
    this.size = 48,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo_icon.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stack) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(size * 0.24),
        ),
        child: const Icon(Icons.route_outlined, color: Colors.white, size: 28),
      ),
    );
  }
}

/// "Route2Go" wordmark with a glyph. [invert] flips text to white for dark
/// backgrounds (e.g. splash).
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({
    super.key,
    this.size = 24,
    this.invert = false,
    this.showGlyph = true,
  });

  final double size;
  final bool invert;
  final bool showGlyph;

  @override
  Widget build(BuildContext context) {
    final color = invert ? Colors.white : AppColors.textPrimary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showGlyph) ...[
          BrandIcon(size: size * 1.15),
          SizedBox(width: size * 0.45),
        ],
        Text(
          Brand.name,
          style: GoogleFonts.inter(
            fontSize: size,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// The Route2Go slogan as styled text.
class SloganText extends StatelessWidget {
  const SloganText({
    super.key,
    this.size = 14,
    this.invert = false,
    this.textAlign = TextAlign.center,
  });

  final double size;
  final bool invert;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      Brand.slogan,
      textAlign: textAlign,
      style: GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        height: 1.3,
        color: invert
            ? Colors.white.withValues(alpha: 0.85)
            : AppColors.textSecondary,
      ),
    );
  }
}
