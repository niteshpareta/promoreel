import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'haptics.dart';
import 'tokens.dart';

/// Button variants are explicit, not inferred from usage. Every CTA in the
/// app picks one of these — no more one-off gradient Containers.
enum PrButtonVariant {
  /// Solid ember — the single most important action on a screen.
  primary,

  /// Outlined — secondary action paired with a primary.
  secondary,

  /// Subtle text-only — tertiary / dismissive.
  ghost,

  /// Crimson solid — destructive confirmations only (delete draft, discard).
  destructive,

  /// Pro gold — CTA for paywall and Pro-only features.
  pro,
}

enum PrButtonSize { sm, md, lg }

/// The only button in the app. Always-capitalised typography via [labelLarge],
/// fixed min-height by size, built-in haptic feedback, loading state.
class PrButton extends StatelessWidget {
  const PrButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PrButtonVariant.primary,
    this.size = PrButtonSize.lg,
    this.icon,
    this.trailing,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final PrButtonVariant variant;
  final PrButtonSize size;
  final IconData? icon;
  final Widget? trailing;
  final bool loading;

  /// When true (default), the button takes the full width of its parent.
  /// Set false for inline / paired buttons.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (bg, fg, border) = switch (variant) {
      PrButtonVariant.primary => (
          scheme.primary,
          scheme.onPrimary,
          null as Color?,
        ),
      PrButtonVariant.secondary => (
          Colors.transparent,
          scheme.onSurface,
          isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      PrButtonVariant.ghost => (
          Colors.transparent,
          scheme.onSurface,
          null,
        ),
      PrButtonVariant.destructive => (
          AppColors.signalCrimson,
          Colors.white,
          null,
        ),
      PrButtonVariant.pro => (
          AppColors.proAurum,
          const Color(0xFF1A1205),
          null,
        ),
    };

    final (height, hPad, textStyle) = switch (size) {
      PrButtonSize.sm => (
          40.0,
          PrSpacing.md,
          AppTextStyles.labelMedium,
        ),
      PrButtonSize.md => (
          48.0,
          PrSpacing.lg,
          AppTextStyles.labelLarge,
        ),
      PrButtonSize.lg => (
          54.0,
          PrSpacing.xl,
          AppTextStyles.labelLarge,
        ),
    };

    final disabled = onPressed == null || loading;

    Widget content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          )
        else if (icon != null) ...[
          Icon(icon, size: size == PrButtonSize.sm ? 16 : 18, color: fg),
          const SizedBox(width: PrSpacing.xs),
        ],
        if (!loading)
          Flexible(
            child: Text(
              label,
              style: textStyle.copyWith(color: fg),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        if (trailing != null && !loading) ...[
          const SizedBox(width: PrSpacing.xs),
          IconTheme(
            data: IconThemeData(color: fg, size: 18),
            child: trailing!,
          ),
        ],
      ],
    );

    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled
              ? null
              : () {
                  PrHaptics.tap();
                  onPressed?.call();
                },
          borderRadius: BorderRadius.circular(PrRadius.md),
          splashColor: fg.withValues(alpha: 0.1),
          highlightColor: fg.withValues(alpha: 0.05),
          child: Ink(
            height: height,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(PrRadius.md),
              border:
                  border != null ? Border.all(color: border, width: 1) : null,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Center(child: content),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact icon-only button with haptic + 44x44 tap target (a11y floor).
class PrIconButton extends StatelessWidget {
  const PrIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
    this.size = 22,
    this.background = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final double size;

  /// When true, renders a subtle surface-overlay background (for icons
  /// sitting on media / images where they'd otherwise disappear).
  final bool background;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = color ?? Theme.of(context).colorScheme.onSurface;

    Widget btn = InkWell(
      onTap: onPressed == null
          ? null
          : () {
              PrHaptics.tap();
              onPressed!();
            },
      borderRadius: BorderRadius.circular(PrRadius.pill),
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: background
            ? BoxDecoration(
                color: (isDark ? Colors.black : Colors.white)
                    .withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(PrRadius.pill),
                border: Border.all(
                  color: fg.withValues(alpha: 0.12),
                  width: 0.7,
                ),
              )
            : null,
        child: Icon(icon, color: fg, size: size),
      ),
    );

    if (tooltip != null) {
      btn = Tooltip(message: tooltip!, child: btn);
    }
    return Material(color: Colors.transparent, child: btn);
  }
}
