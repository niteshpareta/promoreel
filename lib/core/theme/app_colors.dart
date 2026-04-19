import 'package:flutter/material.dart';

abstract final class AppColors {
  // Primary — Electric Violet
  static const primary = Color(0xFF7C4DFF);
  static const primaryDark = Color(0xFF5E35B1);
  static const primaryLight = Color(0xFFB39DDB);
  static const primaryContainer = Color(0xFF2D1B69);
  static const onPrimary = Color(0xFFFFFFFF);

  // Secondary — Coral Orange
  static const secondary = Color(0xFFFF6E40);
  static const secondaryDark = Color(0xFFE64A19);
  static const secondaryLight = Color(0xFFFFAB91);
  static const secondaryContainer = Color(0xFF4D1A00);
  static const onSecondary = Color(0xFFFFFFFF);

  // Backgrounds (dark theme)
  static const bgDark = Color(0xFF0D0D1A);
  static const bgSurface = Color(0xFF1A1A2E);
  static const bgSurfaceVariant = Color(0xFF252540);
  static const bgElevated = Color(0xFF2A2A45);

  // Backgrounds (light theme)
  static const bgLight = Color(0xFFF5F0FF);
  static const bgSurfaceLight = Color(0xFFFFFFFF);
  static const bgSurfaceVariantLight = Color(0xFFEDE7F6);

  // Text (dark theme)
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFB0AFCC);
  static const textDisabled = Color(0xFF606080);
  static const textHint = Color(0xFF7070A0);

  // Text (light theme)
  static const textPrimaryLight = Color(0xFF0D0D1A);
  static const textSecondaryLight = Color(0xFF5C5C7A);

  // Semantic
  static const success = Color(0xFF00C853);
  static const successContainer = Color(0xFF003D17);
  static const error = Color(0xFFFF5252);
  static const errorContainer = Color(0xFF4D0000);
  static const warning = Color(0xFFFFB300);

  // Pro / Paywall
  static const proGold = Color(0xFFFFB300);
  static const proGoldContainer = Color(0xFF3D2B00);
  static const proGoldLight = Color(0xFFFFE082);

  // Divider / Border
  static const divider = Color(0xFF2E2E4A);
  static const dividerLight = Color(0xFFE0D9F7);
  static const border = Color(0xFF3A3A5C);

  // Overlay
  static const scrim = Color(0x80000000);
  static const brandingStrip = Color(0xCC0D0D1A);
  static const cardGradientStart = Color(0x007C4DFF);
  static const cardGradientEnd = Color(0x997C4DFF);
}
