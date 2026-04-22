import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/models/badge_style.dart';

/// Build the silhouette [Path] for a badge shape fitting the given
/// bounding rectangle. The caller chooses the rect's size; this routine
/// only draws the outline. For `starburst` and `ribbon` the path extends
/// fully to the rect's edges — callers that want breathing room should
/// inflate the rect before calling.
Path buildBadgePath(Rect rect, BadgeShape shape) {
  switch (shape) {
    case BadgeShape.roundedPill:
      return Path()
        ..addRRect(RRect.fromRectAndRadius(
            rect, Radius.circular(rect.shortestSide * 0.28)));

    case BadgeShape.circle:
      // Draw the circle centred on the rect, sized to the shorter edge.
      final r = rect.shortestSide / 2;
      return Path()
        ..addOval(Rect.fromCircle(center: rect.center, radius: r));

    case BadgeShape.starburst:
      return _starPath(rect, points: 10, innerOuterRatio: 0.78);

    case BadgeShape.ribbon:
      return _ribbonPath(rect, notchDepth: rect.height * 0.35);

    case BadgeShape.diagonalBanner:
      return _diagonalBannerPath(rect, slant: rect.height * 0.35);
  }
}

/// Paint the badge silhouette + optional border + decor + text into
/// [canvas] occupying [rect]. This is the single source of truth used by
/// the Flutter-preview `CustomPainter` AND `TextRenderer._drawBadge` so
/// the exported PNG matches what users see on-screen.
///
/// [fontSize] is the text's em size. The caller is responsible for sizing
/// [rect] to accommodate the text — usually `textWidth + 2*padH` ×
/// `textHeight + 2*padV`, further inflated for shapes like starburst that
/// need room for their spikes.
void paintBadgeOn(
  Canvas canvas, {
  required Rect rect,
  required BadgeStyle style,
  required String text,
  required double fontSize,
}) {
  // 1. Drop shadow under the whole shape.
  if (style.shadow) {
    final shadowPath = buildBadgePath(rect.shift(const Offset(1.5, 2.5)), style.shape);
    canvas.drawPath(
      shadowPath,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.32)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
  }

  // 2. Fill.
  final mainPath = buildBadgePath(rect, style.shape);
  if (style.fillColor.a > 0) {
    canvas.drawPath(mainPath, Paint()..color = style.fillColor);
  }

  // 3. Decor on top of fill (under text).
  _paintDecor(canvas, rect, style);

  // 4. Border (always on top of fill & decor, under text).
  final border = style.borderColor;
  if (border != null) {
    canvas.drawPath(
      mainPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = border
        ..strokeWidth = rect.shortestSide * 0.04,
    );
  }

  // 5. Text — centred inside the rect.
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: GoogleFonts.getFont(style.fontFamily).copyWith(
        color: style.textColor,
        fontSize: fontSize,
        fontWeight: _weightForIndex(style.fontWeightIndex),
        letterSpacing: style.letterSpacing,
        height: 1.0,
      ),
    ),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: rect.width - _horizontalTextPadding(style.shape, rect));

  final textOffset = Offset(
    rect.center.dx - painter.width / 2,
    rect.center.dy - painter.height / 2,
  );
  painter.paint(canvas, textOffset);
}

double _horizontalTextPadding(BadgeShape shape, Rect rect) {
  // Extra side padding for shapes that clip content at the edges.
  switch (shape) {
    case BadgeShape.ribbon:
      return rect.height * 0.8; // notches eat both ends
    case BadgeShape.starburst:
      return rect.width * 0.25; // stay inside the star's convex hull
    case BadgeShape.diagonalBanner:
      return rect.height * 0.7;
    case BadgeShape.circle:
      return rect.width * 0.2;
    case BadgeShape.roundedPill:
      return rect.height * 0.8;
  }
}

/// Paint the decor glyphs on top of the fill.
void _paintDecor(Canvas canvas, Rect rect, BadgeStyle style) {
  switch (style.decor) {
    case BadgeDecor.none:
      return;
    case BadgeDecor.shine:
      // Diagonal glossy highlight in the upper-left portion.
      final shinePath = Path()
        ..moveTo(rect.left, rect.top + rect.height * 0.15)
        ..lineTo(rect.left + rect.width * 0.55, rect.top + rect.height * 0.05)
        ..lineTo(rect.left + rect.width * 0.2, rect.top + rect.height * 0.55)
        ..lineTo(rect.left, rect.top + rect.height * 0.65)
        ..close();
      // Clip the highlight to the badge silhouette so it doesn't bleed.
      canvas.save();
      canvas.clipPath(buildBadgePath(rect, style.shape));
      canvas.drawPath(
        shinePath,
        Paint()..color = Colors.white.withValues(alpha: 0.25),
      );
      canvas.restore();
      return;
    case BadgeDecor.doubleBorder:
      // Insert an inset stroke — "ribbon award" feel.
      final inset = rect.shortestSide * 0.14;
      final innerRect = rect.deflate(inset);
      final innerPath = buildBadgePath(innerRect, style.shape);
      canvas.drawPath(
        innerPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = (style.borderColor ?? style.textColor)
              .withValues(alpha: 0.85)
          ..strokeWidth = rect.shortestSide * 0.025,
      );
      return;
  }
}

// ─── Shape-building helpers ─────────────────────────────────────────────────

Path _starPath(
  Rect rect, {
  required int points,
  required double innerOuterRatio,
}) {
  // Scale outer star to fit inside the longer edge; inner points ride the
  // shorter edge minus margin for breathing room.
  final center = rect.center;
  final outerR = rect.shortestSide / 2;
  final innerR = outerR * innerOuterRatio;
  final totalVertices = points * 2;
  final step = 2 * math.pi / totalVertices;
  // Start pointing up so one spike is at 12 o'clock.
  final startAngle = -math.pi / 2;
  final path = Path();
  for (int i = 0; i < totalVertices; i++) {
    final r = i.isEven ? outerR : innerR;
    final angle = startAngle + i * step;
    final x = center.dx + r * math.cos(angle);
    final y = center.dy + r * math.sin(angle);
    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  path.close();
  return path;
}

Path _ribbonPath(Rect rect, {required double notchDepth}) {
  // Shape:
  //       ┌────────────────────────┐
  //       │                        │
  //     <─┤                        ├─>    (triangular notches on both ends)
  //       │                        │
  //       └────────────────────────┘
  return Path()
    ..moveTo(rect.left, rect.top)
    ..lineTo(rect.right, rect.top)
    ..lineTo(rect.right - notchDepth * 0.6, rect.center.dy)
    ..lineTo(rect.right, rect.bottom)
    ..lineTo(rect.left, rect.bottom)
    ..lineTo(rect.left + notchDepth * 0.6, rect.center.dy)
    ..lineTo(rect.left, rect.top)
    ..close();
}

Path _diagonalBannerPath(Rect rect, {required double slant}) {
  return Path()
    ..moveTo(rect.left + slant, rect.top)
    ..lineTo(rect.right, rect.top)
    ..lineTo(rect.right - slant, rect.bottom)
    ..lineTo(rect.left, rect.bottom)
    ..close();
}

FontWeight _weightForIndex(int i) {
  // Round to the nearest FontWeight bucket.
  const weights = [
    FontWeight.w100, FontWeight.w200, FontWeight.w300, FontWeight.w400,
    FontWeight.w500, FontWeight.w600, FontWeight.w700, FontWeight.w800,
    FontWeight.w900,
  ];
  final bucket = ((i.clamp(100, 900) - 100) / 100).round();
  return weights[bucket.clamp(0, weights.length - 1)];
}

/// Flutter widget that draws a [BadgeStyle] silhouette + text at whatever
/// size it's given. Use inside a `SizedBox` or `Align` to position the
/// badge on the frame.
class StyledBadge extends StatelessWidget {
  const StyledBadge({
    super.key,
    required this.style,
    required this.text,
    required this.fontSize,
  });

  final BadgeStyle style;
  final String text;
  final double fontSize;

  /// Natural size for this badge at the given font size. Callers use this
  /// to lay the badge out via `SizedBox` so intrinsic painting works.
  Size naturalSize() {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: _weightForIndex(style.fontWeightIndex),
          letterSpacing: style.letterSpacing,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final padH = fontSize * 0.8;
    final padV = fontSize * 0.5;
    double w = painter.width + padH * 2;
    double h = painter.height + padV * 2;
    // Shape-specific inflation so the text isn't clipped by the silhouette.
    switch (style.shape) {
      case BadgeShape.starburst:
        // Inflate for spikes; keep roughly square so the star is symmetric.
        final dim = math.max(w, h) * 1.25;
        w = h = dim;
        break;
      case BadgeShape.circle:
        final dim = math.max(w, h) * 1.05;
        w = h = dim;
        break;
      case BadgeShape.ribbon:
        w += h * 0.9; // room for notches on both ends
        break;
      case BadgeShape.diagonalBanner:
        w += h * 0.9;
        break;
      case BadgeShape.roundedPill:
        break;
    }
    return Size(w, h);
  }

  @override
  Widget build(BuildContext context) {
    final size = naturalSize();
    return SizedBox.fromSize(
      size: size,
      child: CustomPaint(
        painter: _BadgeCustomPainter(
          style: style,
          text: text,
          fontSize: fontSize,
        ),
      ),
    );
  }
}

class _BadgeCustomPainter extends CustomPainter {
  _BadgeCustomPainter({
    required this.style,
    required this.text,
    required this.fontSize,
  });

  final BadgeStyle style;
  final String text;
  final double fontSize;

  @override
  void paint(Canvas canvas, Size size) {
    paintBadgeOn(
      canvas,
      rect: Offset.zero & size,
      style: style,
      text: text,
      fontSize: fontSize,
    );
  }

  @override
  bool shouldRepaint(covariant _BadgeCustomPainter old) =>
      old.style.id != style.id ||
      old.style.fillColor != style.fillColor ||
      old.style.textColor != style.textColor ||
      old.text != text ||
      old.fontSize != fontSize;
}

/// Natural-size computation reused by [StyledBadge] and
/// `TextRenderer._drawBadge`. Kept as a top-level function so the renderer
/// can call it without constructing a widget.
Size measureBadge(BadgeStyle style, String text, double fontSize) {
  return StyledBadge(style: style, text: text, fontSize: fontSize)
      .naturalSize();
}

/// Paint [text] styled as [style] straight into an arbitrary canvas. The
/// badge will land at [origin] with its computed natural size.
void paintBadgeAt(
  ui.Canvas canvas, {
  required Offset origin,
  required BadgeStyle style,
  required String text,
  required double fontSize,
}) {
  final size = measureBadge(style, text, fontSize);
  paintBadgeOn(
    canvas,
    rect: origin & size,
    style: style,
    text: text,
    fontSize: fontSize,
  );
}
