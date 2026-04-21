import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'tokens.dart';

/// Consistent bottom-sheet shell — grab handle, title row, scroll container,
/// optional footer. Every bottom sheet in the app should wrap its content
/// in this, not re-roll the chrome.
class PrBottomSheet extends StatelessWidget {
  const PrBottomSheet({
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    required this.child,
    this.footer,
    this.maxHeightFraction = 0.9,
  });

  final String? title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final Widget child;
  final Widget? footer;

  /// Fraction of screen height the sheet is allowed to grow to.
  final double maxHeightFraction;

  /// Convenience wrapper to show this sheet with all the shell defaults
  /// (scrollable, rounded, drag-handle, safe-area). Use instead of
  /// [showModalBottomSheet] at call sites.
  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    String? subtitle,
    Widget? leading,
    Widget? trailing,
    Widget? footer,
    double maxHeightFraction = 0.9,
    required Widget Function(BuildContext) builder,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.scrim,
      builder: (ctx) => PrBottomSheet(
        title: title,
        subtitle: subtitle,
        leading: leading,
        trailing: trailing,
        footer: footer,
        maxHeightFraction: maxHeightFraction,
        child: builder(ctx),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final media = MediaQuery.of(context);
    final bg = isDark
        ? AppColors.surfaceRaisedDark
        : AppColors.surfaceRaisedLight;
    final hairline =
        isDark ? AppColors.hairlineDark : AppColors.hairlineLight;

    return Container(
      constraints: BoxConstraints(
        maxHeight: media.size.height * maxHeightFraction,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(PrRadius.xl),
        ),
        border: Border(top: BorderSide(color: hairline, width: 0.7)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: PrSpacing.sm),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: hairline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  PrSpacing.lg, PrSpacing.md, PrSpacing.lg, PrSpacing.xs),
              child: Row(
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: PrSpacing.sm),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title!, style: AppTextStyles.headlineMedium),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
            Divider(color: hairline, height: 1),
          ],
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                PrSpacing.lg,
                PrSpacing.md,
                PrSpacing.lg,
                footer != null ? PrSpacing.md : PrSpacing.lg,
              ),
              child: child,
            ),
          ),
          if (footer != null) ...[
            Divider(color: hairline, height: 1),
            Padding(
              padding: EdgeInsets.fromLTRB(
                PrSpacing.lg,
                PrSpacing.md,
                PrSpacing.lg,
                PrSpacing.md + media.padding.bottom,
              ),
              child: footer!,
            ),
          ] else
            SizedBox(height: media.padding.bottom),
        ],
      ),
    );
  }
}
