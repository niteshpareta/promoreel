import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'pr_button.dart';
import 'tokens.dart';

/// Unified "nothing here yet" surface. Every screen that can be empty must
/// render this (never raw Text/CTA), so the empty-state language stays one.
class PrEmptyState extends StatelessWidget {
  const PrEmptyState({
    super.key,
    required this.headline,
    required this.body,
    this.icon,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String headline;
  final String body;
  final IconData? icon;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: PrSpacing.xl, vertical: PrSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null)
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.brandEmber.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(PrRadius.xl),
                border: Border.all(
                  color: AppColors.brandEmber.withValues(alpha: 0.25),
                  width: 0.7,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: AppColors.brandEmber, size: 28),
            ),
          const SizedBox(height: PrSpacing.lg),
          Text(
            headline,
            style: AppTextStyles.displaySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: PrSpacing.xs),
          Text(
            body,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (primaryLabel != null) ...[
            const SizedBox(height: PrSpacing.xl),
            PrButton(
              label: primaryLabel!,
              onPressed: onPrimary,
              expand: false,
              size: PrButtonSize.md,
            ),
          ],
          if (secondaryLabel != null) ...[
            const SizedBox(height: PrSpacing.xs),
            PrButton(
              label: secondaryLabel!,
              onPressed: onSecondary,
              variant: PrButtonVariant.ghost,
              expand: false,
              size: PrButtonSize.md,
            ),
          ],
        ],
      ),
    );
  }
}
