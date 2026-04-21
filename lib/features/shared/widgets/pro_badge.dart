import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class ProBadge extends StatelessWidget {
  const ProBadge({super.key, this.label = 'FREE'});

  final String label;

  @override
  Widget build(BuildContext context) {
    if (!kSubscriptionEnabled) return const SizedBox.shrink();
    final isPro = label != 'FREE';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPro ? AppColors.proGoldContainer : AppColors.bgSurfaceVariant,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isPro ? AppColors.proGold.withValues(alpha: 0.6) : AppColors.border,
        ),
      ),
      child: Text(
        label,
        style: AppTextStyles.proBadge.copyWith(
          color: isPro ? AppColors.proGold : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class ProLockOverlay extends StatelessWidget {
  const ProLockOverlay({super.key, required this.child, required this.isPro, this.onTap});

  final Widget child;
  final bool isPro;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (!kSubscriptionEnabled || isPro) return child;
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(Icons.lock_rounded, color: AppColors.proGold, size: 24),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
