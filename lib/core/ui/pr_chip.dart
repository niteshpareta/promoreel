import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'haptics.dart';
import 'tokens.dart';

/// Filter/selection chip. Pill shape, ember-fill when selected, hairline at
/// rest. Always tappable (toggles [selected]).
class PrChip extends StatelessWidget {
  const PrChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = selected
        ? AppColors.brandEmber
        : (isDark
            ? AppColors.surfaceRaisedDark
            : AppColors.surfaceOverlayLight);
    final fg = selected
        ? AppColors.onBrand
        : (isDark
            ? AppColors.contentPrimaryDark
            : AppColors.contentPrimaryLight);
    final border = selected
        ? Colors.transparent
        : (isDark ? AppColors.hairlineDark : AppColors.hairlineLight);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(PrRadius.pill),
        onTap: () {
          PrHaptics.select();
          onTap();
        },
        child: AnimatedContainer(
          duration: PrDuration.fast,
          curve: PrCurves.enter,
          padding: const EdgeInsets.symmetric(
              horizontal: PrSpacing.md, vertical: PrSpacing.xs + 1),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(PrRadius.pill),
            border: Border.all(color: border, width: 0.7),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: AppTextStyles.labelMedium.copyWith(color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
