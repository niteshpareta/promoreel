import 'package:flutter/services.dart';

/// Semantic haptics — call by intent, not by HapticFeedback variant.
///
/// The named methods carry meaning: [tap] is what a button does, [select]
/// is when a chip flips state, [success] is an export completing. This
/// centralisation means we can re-tune all "success" feedback in one place
/// (say, switching from heavyImpact to a custom vibration pattern) rather
/// than chasing calls across the app.
abstract final class PrHaptics {
  /// Button or tile press — fires on pointer down for responsiveness.
  static Future<void> tap() => HapticFeedback.selectionClick();

  /// Toggle, chip selection, tab switch.
  static Future<void> select() => HapticFeedback.lightImpact();

  /// A commit — save, apply, next-step.
  static Future<void> commit() => HapticFeedback.mediumImpact();

  /// Celebratory — export done, first-render complete.
  static Future<void> success() async {
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.mediumImpact();
  }

  /// Something blocked the user — paywall hit, permission denied.
  static Future<void> warn() => HapticFeedback.vibrate();

  /// Destructive confirmation — delete draft, clear project.
  static Future<void> destructive() => HapticFeedback.heavyImpact();
}
