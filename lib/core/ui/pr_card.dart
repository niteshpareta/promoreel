import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'haptics.dart';
import 'tokens.dart';

enum PrCardVariant {
  /// Flat surface, hairline border. Most content cards use this.
  surface,

  /// Slightly brighter, used when a card sits *on top* of surface cards.
  raised,

  /// Tappable — shows press state + adds haptic. Identical visuals to
  /// [surface] at rest.
  interactive,

  /// Hero — ember-glow ring, aurora tint. Reserved for the single most
  /// important card on any given screen.
  hero,
}

/// The card primitive. Consistent 20px radius, hairline border, no Material
/// shadow (we use subtle tonal shifts instead — shadows look cheap on OLED).
class PrCard extends StatelessWidget {
  const PrCard({
    super.key,
    required this.child,
    this.variant = PrCardVariant.surface,
    this.padding = const EdgeInsets.all(PrSpacing.md),
    this.onTap,
    this.radius = PrRadius.lg,
  });

  final Widget child;
  final PrCardVariant variant;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (bg, border) = switch (variant) {
      PrCardVariant.surface => (
          isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          isDark ? AppColors.hairlineDark : AppColors.hairlineLight,
        ),
      PrCardVariant.raised => (
          isDark
              ? AppColors.surfaceRaisedDark
              : AppColors.surfaceRaisedLight,
          isDark ? AppColors.hairlineDark : AppColors.hairlineLight,
        ),
      PrCardVariant.interactive => (
          isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          isDark ? AppColors.hairlineDark : AppColors.hairlineLight,
        ),
      PrCardVariant.hero => (
          isDark ? AppColors.surfaceRaisedDark : Colors.white,
          AppColors.brandEmber.withValues(alpha: 0.35),
        ),
    };

    Widget card = Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border, width: 0.7),
        // Subtle ember glow only on the hero variant.
        boxShadow: variant == PrCardVariant.hero
            ? [
                BoxShadow(
                  color: AppColors.brandEmber.withValues(alpha: 0.12),
                  blurRadius: 32,
                  spreadRadius: -4,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap != null || variant == PrCardVariant.interactive) {
      card = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  PrHaptics.tap();
                  onTap!();
                },
          borderRadius: BorderRadius.circular(radius),
          splashColor: AppColors.brandEmber.withValues(alpha: 0.06),
          highlightColor: AppColors.brandEmber.withValues(alpha: 0.04),
          child: card,
        ),
      );
    }

    return card;
  }
}
