import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'tokens.dart';

enum PrBadgeTone {
  /// Brand ember — for "new", highlights, active filters.
  brand,

  /// Leaf — for success, saved, published states.
  success,

  /// Crimson — for sale, price, urgent.
  crimson,

  /// Amber — for warnings, "Free" tier reminder.
  warn,

  /// Sky — for info, tips.
  info,

  /// Pro gold — reserved for Pro-only markers.
  pro,

  /// Neutral — for timestamps, durations, counters.
  neutral,
}

/// Pill-shaped micro-label. Use for metadata, never for CTAs.
class PrBadge extends StatelessWidget {
  const PrBadge({
    super.key,
    required this.label,
    this.tone = PrBadgeTone.neutral,
    this.icon,
    this.dense = false,
  });

  final String label;
  final PrBadgeTone tone;
  final IconData? icon;

  /// Dense = 2px less vertical padding. Use on tight rows (video card chips).
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: PrSpacing.xs + 2,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(PrRadius.pill),
        border: Border.all(color: fg.withValues(alpha: 0.25), width: 0.7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: fg,
              fontSize: 10.5,
              letterSpacing: 0.4,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color) _colors(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (tone) {
      case PrBadgeTone.brand:
        return (
          AppColors.brandEmber.withValues(alpha: isDark ? 0.14 : 0.18),
          isDark ? AppColors.brandEmberSoft : AppColors.brandEmberDeep,
        );
      case PrBadgeTone.success:
        return (
          AppColors.signalLeaf.withValues(alpha: isDark ? 0.12 : 0.18),
          isDark ? AppColors.signalLeaf : const Color(0xFF1F7D3D),
        );
      case PrBadgeTone.crimson:
        return (
          AppColors.signalCrimson.withValues(alpha: isDark ? 0.14 : 0.18),
          isDark ? const Color(0xFFFF8AB2) : AppColors.signalCrimson,
        );
      case PrBadgeTone.warn:
        return (
          AppColors.signalAmber.withValues(alpha: isDark ? 0.14 : 0.2),
          isDark ? AppColors.signalAmber : const Color(0xFF8A5A00),
        );
      case PrBadgeTone.info:
        return (
          AppColors.signalSky.withValues(alpha: isDark ? 0.14 : 0.18),
          isDark ? AppColors.signalSky : const Color(0xFF1D4ED8),
        );
      case PrBadgeTone.pro:
        return (
          AppColors.proAurum.withValues(alpha: isDark ? 0.18 : 0.22),
          isDark ? AppColors.proAurum : AppColors.proAurumDeep,
        );
      case PrBadgeTone.neutral:
        return (
          isDark
              ? AppColors.surfaceOverlayDark
              : AppColors.surfaceOverlayLight,
          isDark
              ? AppColors.contentSecondaryDark
              : AppColors.contentSecondaryLight,
        );
    }
  }
}
