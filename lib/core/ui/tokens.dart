import 'package:flutter/animation.dart';

/// Design tokens for the PromoReel "Studio Cinematic" system.
///
/// Use these instead of raw numbers or hex colors in widgets. One source of
/// truth for spacing, radii, motion, and elevation keeps every surface in
/// visual rhythm — the thing that separates a generic Material app from a
/// product that feels authored.
abstract final class PrSpacing {
  /// 4 — hairline gap, only between tightly-coupled elements.
  static const double xxs = 4;

  /// 8 — chip/badge internal padding, stacked icon-label gap.
  static const double xs = 8;

  /// 12 — tight grid gaps, form field padding.
  static const double sm = 12;

  /// 16 — default card padding, list gutters.
  static const double md = 16;

  /// 20 — screen edge padding (the PromoReel page gutter).
  static const double lg = 20;

  /// 24 — section spacing, bottom-sheet padding.
  static const double xl = 24;

  /// 32 — hero padding, between unrelated groups.
  static const double xxl = 32;

  /// 48 — top-of-screen breathing room.
  static const double xxxl = 48;
}

abstract final class PrRadius {
  /// 6 — chips, inline tags.
  static const double xs = 6;

  /// 10 — input fields, small buttons.
  static const double sm = 10;

  /// 14 — primary buttons.
  static const double md = 14;

  /// 20 — cards, tiles.
  static const double lg = 20;

  /// 28 — hero surfaces, bottom sheets.
  static const double xl = 28;

  /// 999 — pill / fully rounded.
  static const double pill = 999;
}

abstract final class PrDuration {
  /// 120ms — tap feedback, chip toggles.
  static const Duration fast = Duration(milliseconds: 120);

  /// 220ms — default transitions, card reveals.
  static const Duration base = Duration(milliseconds: 220);

  /// 360ms — cross-screen fades, larger component state changes.
  static const Duration slow = Duration(milliseconds: 360);

  /// 560ms — hero moments (export celebration, onboarding cards).
  static const Duration hero = Duration(milliseconds: 560);

  /// 2800ms — ambient loops (aurora backdrop, reel rotation).
  static const Duration ambient = Duration(milliseconds: 2800);
}

abstract final class PrCurves {
  /// Snappy exit — decelerate quickly, used for things leaving view.
  static const Curve exit = Curves.easeInCubic;

  /// Default entrance — feels responsive without bouncing.
  static const Curve enter = Curves.easeOutCubic;

  /// Signature "camera pan" easing for cross-fades, page transitions.
  static const Curve cinematic = Cubic(0.16, 1, 0.3, 1);

  /// Spring-like overshoot for delight moments.
  static const Curve spring = Curves.elasticOut;

  /// Gentle sine loop for ambient, non-intrusive motion.
  static const Curve ambient = Curves.easeInOutSine;
}

abstract final class PrElevation {
  /// Flat surface — no shadow, borders only.
  static const double flat = 0;

  /// Soft lift — cards, tiles, chips.
  static const double soft = 1;

  /// Raised — sticky headers, bottom bars.
  static const double raised = 2;

  /// Modal — bottom sheets, dialogs.
  static const double modal = 4;
}
