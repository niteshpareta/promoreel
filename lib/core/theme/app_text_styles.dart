import 'package:flutter/material.dart';
import 'app_colors.dart';

// Uses system font — handles both Latin and Devanagari natively on Android/iOS.
abstract final class AppTextStyles {
  static const TextStyle _base = TextStyle(color: AppColors.textPrimary, height: 1.4);

  static final displayLarge  = _base.copyWith(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.5);
  static final displayMedium = _base.copyWith(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.3);

  static final headlineLarge  = _base.copyWith(fontSize: 22, fontWeight: FontWeight.w700);
  static final headlineMedium = _base.copyWith(fontSize: 18, fontWeight: FontWeight.w700);
  static final headlineSmall  = _base.copyWith(fontSize: 16, fontWeight: FontWeight.w600);

  static final titleLarge  = _base.copyWith(fontSize: 15, fontWeight: FontWeight.w600);
  static final titleMedium = _base.copyWith(fontSize: 14, fontWeight: FontWeight.w600);
  static final titleSmall  = _base.copyWith(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.1);

  static final bodyLarge  = _base.copyWith(fontSize: 16, fontWeight: FontWeight.w400);
  static final bodyMedium = _base.copyWith(fontSize: 14, fontWeight: FontWeight.w400);
  static final bodySmall  = _base.copyWith(fontSize: 12, fontWeight: FontWeight.w400);

  static final labelLarge  = _base.copyWith(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1);
  static final labelMedium = _base.copyWith(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5);
  static final labelSmall  = _base.copyWith(fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 0.5);

  static final proBadge = _base.copyWith(
    fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.proGold,
  );
}
