import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Context-aware palette shortcut. Resolves to the correct color for the
/// active theme (dark vs light) so widgets don't have to write
/// `Theme.of(context).brightness == Brightness.dark ? … : …` inline.
///
/// Build once per build() method:
///
///     final tone = PrTone.of(context);
///     ...
///     color: tone.content
///     decoration: BoxDecoration(color: tone.surfaceRaised)
///
/// Use this (not raw `AppColors.*Dark` / `AppColors.*Light`) wherever a
/// widget needs a semantic color that should flip with the theme.
class PrTone {
  PrTone._(this._scheme, this._isDark);

  final ColorScheme _scheme;
  final bool _isDark;

  factory PrTone.of(BuildContext context) {
    final theme = Theme.of(context);
    return PrTone._(
      theme.colorScheme,
      theme.brightness == Brightness.dark,
    );
  }

  // ── Content (text, icons) ──────────────────────────────────────────────
  Color get content => _scheme.onSurface;
  Color get contentSecondary => _scheme.onSurfaceVariant;

  /// The "fourth tier" — below secondary, used for timestamps, micro-copy.
  /// MD3 doesn't ship this so we mix a local value per theme.
  Color get contentMuted =>
      _isDark ? AppColors.contentMutedDark : AppColors.contentMutedLight;

  /// Disabled text / icons — lowest legible tier.
  Color get contentDisabled =>
      _isDark ? AppColors.contentDisabledDark : AppColors.contentDisabledLight;

  // ── Surfaces ───────────────────────────────────────────────────────────
  /// Page background — what's behind everything.
  Color get canvas =>
      _isDark ? AppColors.canvasDark : AppColors.canvasLight;

  /// Base content surface (below raised cards).
  Color get surface =>
      _isDark ? AppColors.surfaceDark : AppColors.surfaceLight;

  /// Cards, tiles, bottom sheets.
  Color get surfaceRaised => _isDark
      ? AppColors.surfaceRaisedDark
      : AppColors.surfaceRaisedLight;

  /// Popovers, tooltips, floating menus — highest.
  Color get surfaceOverlay => _isDark
      ? AppColors.surfaceOverlayDark
      : AppColors.surfaceOverlayLight;

  // ── Dividers / borders ─────────────────────────────────────────────────
  /// Hairline — barely-there separator.
  Color get hairline =>
      _isDark ? AppColors.hairlineDark : AppColors.hairlineLight;

  /// Stronger border — focus rings, emphasis.
  Color get border =>
      _isDark ? AppColors.borderDark : AppColors.borderLight;

  // ── Brand ──────────────────────────────────────────────────────────────
  /// Primary brand color for the active theme.
  /// Dark: `brandEmber`. Light: `brandEmberDeep` (for contrast).
  Color get brand => _scheme.primary;

  /// Soft brand accent — lighter on dark, deeper on light. Used for
  /// italicised display-text emphasis and the ember highlight colour.
  Color get brandAccent =>
      _isDark ? AppColors.brandEmberSoft : AppColors.brandEmberDeep;

  /// Brand glow — used as a halo colour on hero surfaces.
  Color get brandGlow => AppColors.brandEmber.withValues(alpha: 0.12);

  bool get isDark => _isDark;
}
