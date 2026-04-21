import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// PromoReel typography — "Studio Cinematic" voice.
///
/// Two faces:
///   • **Fraunces** (editorial serif, SOFT axis set to +) for headlines,
///     display moments, brand moments. Warm, authored, slightly theatrical.
///   • **Manrope** (humanist geometric sans) for body, UI labels, numerics.
///
/// Both are shipped via `google_fonts` — first use downloads + caches.
///
/// **Colors deliberately NOT baked in.** These styles return with `color: null`
/// so they inherit from the enclosing `DefaultTextStyle` (which `Theme` sets
/// to `colorScheme.onSurface` per theme). That means `Text('foo', style:
/// AppTextStyles.titleLarge)` renders the correct color in both light and
/// dark automatically. Callers that want a specific color should
/// `.copyWith(color: …)` at the call site.
///
/// Exceptions: [kicker] and [proBadge] carry intrinsic brand colors
/// (`brandEmberDeep`, `proAurumDeep`) that read acceptably in both themes.
abstract final class AppTextStyles {
  // ── Display — Fraunces Soft, used sparingly for hero moments ───────────
  static TextStyle get displayLarge => GoogleFonts.fraunces(
        fontSize: 40,
        height: 1.05,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.8,
        fontFeatures: const [FontFeature.enable('SOFT'), FontFeature.enable('ss01')],
      );

  static TextStyle get displayMedium => GoogleFonts.fraunces(
        fontSize: 32,
        height: 1.08,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.5,
        fontFeatures: const [FontFeature.enable('SOFT')],
      );

  static TextStyle get displaySmall => GoogleFonts.fraunces(
        fontSize: 26,
        height: 1.1,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.3,
        fontFeatures: const [FontFeature.enable('SOFT')],
      );

  // ── Headline — Manrope bold, screen titles ─────────────────────────────
  static TextStyle get headlineLarge => GoogleFonts.manrope(
        fontSize: 24,
        height: 1.2,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      );

  static TextStyle get headlineMedium => GoogleFonts.manrope(
        fontSize: 20,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      );

  static TextStyle get headlineSmall => GoogleFonts.manrope(
        fontSize: 17,
        height: 1.3,
        fontWeight: FontWeight.w700,
      );

  // ── Title — card / row leads ───────────────────────────────────────────
  static TextStyle get titleLarge => GoogleFonts.manrope(
        fontSize: 16,
        height: 1.3,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get titleMedium => GoogleFonts.manrope(
        fontSize: 14,
        height: 1.35,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get titleSmall => GoogleFonts.manrope(
        fontSize: 12,
        height: 1.35,
        fontWeight: FontWeight.w600,
      );

  // ── Body ───────────────────────────────────────────────────────────────
  static TextStyle get bodyLarge => GoogleFonts.manrope(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get bodyMedium => GoogleFonts.manrope(
        fontSize: 14,
        height: 1.5,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get bodySmall => GoogleFonts.manrope(
        fontSize: 12.5,
        height: 1.45,
        fontWeight: FontWeight.w400,
      );

  // ── Label — buttons, chips ─────────────────────────────────────────────
  static TextStyle get labelLarge => GoogleFonts.manrope(
        fontSize: 14,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      );

  static TextStyle get labelMedium => GoogleFonts.manrope(
        fontSize: 12,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      );

  static TextStyle get labelSmall => GoogleFonts.manrope(
        fontSize: 11,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      );

  // ── Kicker — brand-coloured; deep ember reads on both themes ───────────
  static TextStyle get kicker => GoogleFonts.manrope(
        color: AppColors.brandEmberDeep,
        fontSize: 10.5,
        height: 1.2,
        fontWeight: FontWeight.w800,
        letterSpacing: 2.4,
      );

  // ── Numeric — tabular figures ──────────────────────────────────────────
  static TextStyle get numeric => GoogleFonts.manrope(
        fontSize: 14,
        height: 1.2,
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle get numericLarge => GoogleFonts.manrope(
        fontSize: 28,
        height: 1,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  // ── Pro badge — brand-coloured; deep aurum reads on both themes ────────
  static TextStyle get proBadge => GoogleFonts.manrope(
        color: AppColors.proAurumDeep,
        fontSize: 10,
        height: 1,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      );

  // ── Hindi variants — Noto Sans Devanagari stack ────────────────────────
  /// Body text containing Hindi characters.
  static TextStyle get bodyHindi => GoogleFonts.notoSansDevanagari(
        fontSize: 14.5,
        height: 1.6,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get titleHindi => GoogleFonts.notoSansDevanagari(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get displayHindi => GoogleFonts.tiroDevanagariHindi(
        fontSize: 28,
        height: 1.4,
        fontWeight: FontWeight.w400,
      );
}
