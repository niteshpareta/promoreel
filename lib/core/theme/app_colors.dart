import 'package:flutter/material.dart';

/// PromoReel "Studio Cinematic" palette.
///
/// Warm blacks instead of blue-purple greys, an amber "cinema light" brand
/// instead of violet, and a restrained tri-signal system (crimson/leaf/gold)
/// for price/success/pro. The palette is intentionally narrow: any new color
/// fights this system and should be justified.
///
/// Token names live on two axes:
///   • *semantic role* (brand, surface, content, signal, pro)
///   • *modulation* (base, raised, overlay, muted)
///
/// Legacy member names (primary, secondary, textPrimary…) are kept as
/// forwarders so existing screens compile unchanged while we migrate.
abstract final class AppColors {
  // ── Brand: Ember ─────────────────────────────────────────────────────────
  /// Signature cinema-light amber. Only for brand moments, CTAs, focus.
  static const brandEmber = Color(0xFFF2A848);
  static const brandEmberDeep = Color(0xFFB8772A);
  static const brandEmberSoft = Color(0xFFF7C688);
  static const brandEmberGlow = Color(0x33F2A848);
  static const onBrand = Color(0xFF1A0E03);

  // ── Signals ──────────────────────────────────────────────────────────────
  /// Crimson — sale, price, urgency. Not a generic error red.
  static const signalCrimson = Color(0xFFE63E7A);
  static const signalCrimsonSoft = Color(0xFF4A0F25);

  /// Leaf — success, confirmation, saved.
  static const signalLeaf = Color(0xFF4ADE80);
  static const signalLeafSoft = Color(0xFF0E3E23);

  /// Amber warning (distinct from brand ember — slightly cooler, yellower).
  static const signalAmber = Color(0xFFFFB547);

  /// Sky — informational hints, "did you know" moments.
  static const signalSky = Color(0xFF60A5FA);

  /// Error (destructive only — delete confirmations, failed exports).
  static const signalError = Color(0xFFF87171);
  static const signalErrorSoft = Color(0xFF4A1414);

  // ── Pro tier: Aurum ──────────────────────────────────────────────────────
  /// Gold reserved for paid tier — never used for brand or signals.
  static const proAurum = Color(0xFFF2C661);
  static const proAurumDeep = Color(0xFFD4A234);
  static const proAurumSoft = Color(0xFF3D2B00);

  // ── Dark surfaces (default) ──────────────────────────────────────────────
  /// Canvas — the darkest layer, behind everything. Warm black.
  static const canvasDark = Color(0xFF0A0807);

  /// Base surface for content blocks.
  static const surfaceDark = Color(0xFF141110);

  /// Raised — cards, sheets, modals.
  static const surfaceRaisedDark = Color(0xFF1F1B1A);

  /// Overlay — highest layer (tooltips, popovers).
  static const surfaceOverlayDark = Color(0xFF2A2523);

  /// Hairline — subtle separator, card borders.
  static const hairlineDark = Color(0xFF2E2928);

  /// Emphasis — stronger border, focus ring.
  static const borderDark = Color(0xFF3A3634);

  // ── Dark content ─────────────────────────────────────────────────────────
  static const contentPrimaryDark = Color(0xFFF6F2EA);
  static const contentSecondaryDark = Color(0xFFC9C2B5); // WCAG AA on canvas
  static const contentMutedDark = Color(0xFF8B8478);
  static const contentDisabledDark = Color(0xFF554F46);

  // ── Light surfaces ───────────────────────────────────────────────────────
  /// Warm cream canvas — not a cool lavender, not pure white.
  static const canvasLight = Color(0xFFF7F3ED);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceRaisedLight = Color(0xFFFCF8F1);
  static const surfaceOverlayLight = Color(0xFFF2ECE1);
  static const hairlineLight = Color(0xFFE6DED0);
  static const borderLight = Color(0xFFD2C8B5);

  // ── Light content ────────────────────────────────────────────────────────
  static const contentPrimaryLight = Color(0xFF1C1815);
  static const contentSecondaryLight = Color(0xFF605A52);
  static const contentMutedLight = Color(0xFF938C81);
  static const contentDisabledLight = Color(0xFFBCB4A7);

  // ── Scrims & overlays ────────────────────────────────────────────────────
  static const scrim = Color(0xB30A0807);
  static const brandingStrip = Color(0xCC0A0807);

  // ═════════════════════════════════════════════════════════════════════════
  // Legacy aliases — keep existing imports compiling until migration is done.
  // Don't use these in new code. Map to the semantic tokens above.
  // ═════════════════════════════════════════════════════════════════════════
  static const primary = brandEmber;
  static const primaryDark = brandEmberDeep;
  static const primaryLight = brandEmberSoft;
  static const primaryContainer = Color(0xFF3D2307);
  static const onPrimary = onBrand;

  static const secondary = signalCrimson;
  static const secondaryDark = Color(0xFFB42860);
  static const secondaryLight = Color(0xFFF38DB5);
  static const secondaryContainer = signalCrimsonSoft;
  static const onSecondary = Color(0xFFFFF5F9);

  static const bgDark = canvasDark;
  static const bgSurface = surfaceDark;
  static const bgSurfaceVariant = surfaceRaisedDark;
  static const bgElevated = surfaceOverlayDark;

  static const bgLight = canvasLight;
  static const bgSurfaceLight = surfaceLight;
  static const bgSurfaceVariantLight = surfaceOverlayLight;

  static const textPrimary = contentPrimaryDark;
  static const textSecondary = contentSecondaryDark;
  static const textDisabled = contentDisabledDark;
  static const textHint = contentMutedDark;

  static const textPrimaryLight = contentPrimaryLight;
  static const textSecondaryLight = contentSecondaryLight;

  static const success = signalLeaf;
  static const successContainer = signalLeafSoft;
  static const error = signalError;
  static const errorContainer = signalErrorSoft;
  static const warning = signalAmber;

  static const proGold = proAurum;
  static const proGoldContainer = proAurumSoft;
  static const proGoldLight = Color(0xFFF9DDA0);

  static const divider = hairlineDark;
  static const dividerLight = hairlineLight;
  static const border = borderDark;

  static const cardGradientStart = Color(0x00F2A848);
  static const cardGradientEnd = Color(0x99F2A848);
}
