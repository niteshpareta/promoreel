import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/utils/text_position.dart';
import '../data/models/badge_style.dart';
import '../data/models/caption_style.dart';
import 'badge_painter.dart';

/// Build the `TextStyle` for a caption styled according to [style].
///
/// Shared by the renderer (for baked PNG overlays) and the preview widget
/// (for live editor feedback) so what users see on-screen matches the
/// exported video exactly. Fonts are resolved via `google_fonts`; the first
/// call per family reaches out to fetch the font, subsequent calls hit the
/// on-disk cache.
TextStyle googleFontsStyleFor(
  CaptionStyle style, {
  required double fontSize,
  double height = 1.2,
}) {
  List<Shadow>? shadows;
  Paint? foreground;
  Color? fillColor = style.textColor;
  switch (style.effect) {
    case CaptionEffect.glow:
      final glow = style.glowColor ?? const Color(0xFF4DE1FF);
      shadows = [
        Shadow(color: glow, blurRadius: fontSize * 0.45),
        Shadow(color: glow.withValues(alpha: 0.85), blurRadius: fontSize * 0.25),
        Shadow(color: glow.withValues(alpha: 0.70), blurRadius: fontSize * 0.12),
      ];
      break;
    case CaptionEffect.shadow:
      shadows = [
        Shadow(
          color: const Color(0xB3000000),
          blurRadius: fontSize * 0.18,
          offset: Offset(0, fontSize * 0.025),
        ),
      ];
      break;
    case CaptionEffect.outline:
      // Crisp stroke around glyphs. When `foreground` is set the `color`
      // field must be null, so drop the fill here; the stroke draws on top
      // of nothing — which is exactly the "hollow text" look.
      foreground = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (fontSize * 0.04).clamp(1.2, 3.0)
        ..color = style.textColor;
      fillColor = null;
      break;
    case CaptionEffect.none:
      shadows = null;
      break;
  }

  final base = GoogleFonts.getFont(
    style.fontFamily,
    fontSize: fontSize,
    fontWeight: style.fontWeight,
    height: height,
  );
  return base.copyWith(
    color: fillColor,
    foreground: foreground,
    shadows: shadows,
  );
}

/// Renders caption, price tag, and offer badge onto a transparent 720×1280 PNG.
class TextRenderer {
  static const Map<String, Color> _badgeColors = {
    'SALE':       Color(0xFFFF6E40),
    'NEW':        Color(0xFF00C853),
    'HOT':        Color(0xFFFF3D00),
    '50% OFF':    Color(0xFF7C4DFF),
    'LIMITED':    Color(0xFFFFB300),
    'TODAY ONLY': Color(0xFF00BCD4),
  };

  // Size factor per badge size setting
  static const Map<String, double> _sizeFactors = {
    'small':  0.65,
    'medium': 1.00,
    'large':  1.50,
  };

  static Future<String> renderToFile({
    required String headline,
    required String priceTag,
    required String mrpTag,
    required String offerBadge,
    required String textPosition,
    required String outputPath,
    String badgeSize = 'medium',
    CaptionStyle? captionStyle,
    BadgeStyle? badgeStyle,
    bool uppercase = false,
    int rotationDegrees = 0,
    int width = 720,
    int height = 1280,
  }) async {
    final bytes = await _renderPng(
      headline: uppercase ? headline.toUpperCase() : headline,
      priceTag: priceTag,
      mrpTag: mrpTag,
      offerBadge: offerBadge,
      textPosition: textPosition,
      badgeSize: badgeSize,
      captionStyle: captionStyle ?? CaptionStyle.defaultStyle,
      badgeStyle: badgeStyle ?? BadgeStyle.defaultStyle,
      rotationDegrees: rotationDegrees,
      width: width,
      height: height,
    );
    await File(outputPath).writeAsBytes(bytes);
    return outputPath;
  }

  static Future<List<int>> _renderPng({
    required String headline,
    required String priceTag,
    required String mrpTag,
    required String offerBadge,
    required String textPosition,
    required String badgeSize,
    required CaptionStyle captionStyle,
    required BadgeStyle badgeStyle,
    required int rotationDegrees,
    required int width,
    required int height,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));

    final hasText  = headline.isNotEmpty;
    final hasPrice = priceTag.isNotEmpty;
    final hasMrp   = mrpTag.isNotEmpty;
    final hasBadge = offerBadge.isNotEmpty;
    final hasBadgeOverlay = hasPrice || hasMrp || hasBadge;

    final double sf = _sizeFactors[badgeSize] ?? 1.0;

    // Approximate badge height for overlap avoidance (offer badge: padV*2 + fontSize)
    final double badgeH = (10 * sf * 2) + (30 * sf) + 16; // padV*2 + fontSize + margin

    final pos = TextPosition.parse(textPosition);

    // Canva-style caption: optional rounded-rect pill plus the text's drop
    // shadow / glow. Style preset decides font, colour, pill, and effect.
    if (hasText) {
      const double fontPx = 48;
      const double padH = fontPx * 0.75;
      const double padV = fontPx * 0.35;
      const double radius = fontPx * 0.7;

      final captionTextStyle = googleFontsStyleFor(
        captionStyle,
        fontSize: fontPx,
      );

      final painter = TextPainter(
        text: TextSpan(text: headline, style: captionTextStyle),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 2,
      )..layout(maxWidth: width - 80.0);

      final double pillW = painter.width + padH * 2;
      final double pillH = painter.height + padV * 2;

      final double cx;
      final double cy;
      if (pos.isCustom) {
        cx = (width * pos.offset.dx)
            .clamp(pillW / 2 + 24.0, width - pillW / 2 - 24.0);
        cy = (height * pos.offset.dy)
            .clamp(pillH / 2 + 40.0, height - pillH / 2 - 40.0);
      } else if (textPosition == 'top') {
        cx = width / 2.0;
        cy = hasBadgeOverlay
            ? (80 + badgeH + 12 + pillH / 2)
            : (100.0 + pillH / 2);
      } else if (textPosition == 'center') {
        cx = width / 2.0;
        cy = height / 2.0;
      } else {
        cx = width / 2.0;
        cy = height - 148.0 - pillH / 2;
      }

      // Rotation — tilt the pill+text around their shared centre.
      // Wrapped in save/restore so following overlays aren't affected.
      final bool rotated = rotationDegrees != 0;
      if (rotated) {
        canvas.save();
        canvas.translate(cx, cy);
        canvas.rotate(rotationDegrees * 3.14159265358979 / 180.0);
        canvas.translate(-cx, -cy);
      }

      if (captionStyle.pillColor != null) {
        final pillRect = Rect.fromCenter(
          center: Offset(cx, cy),
          width: pillW,
          height: pillH,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(pillRect, const Radius.circular(radius)),
          Paint()..color = captionStyle.pillColor!,
        );
      }
      painter.paint(
        canvas,
        Offset(cx - painter.width / 2, cy - painter.height / 2),
      );

      if (rotated) canvas.restore();
    }

    // Price badge — top-right
    if (hasPrice || hasMrp) {
      _drawPriceBadge(
        canvas: canvas,
        offerPrice: priceTag,
        mrpPrice: mrpTag,
        top: 80,
        right: 36,
        canvasWidth: width.toDouble(),
        sf: sf,
      );
    }

    // Offer badge — top-left, painted via the shared badge_painter so the
    // PNG matches the Flutter preview for all 6 style presets.
    if (hasBadge) {
      _drawBadge(
        canvas: canvas,
        text: offerBadge,
        style: badgeStyle,
        top: 80,
        left: 36,
        sf: sf,
      );
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw StateError('Failed to encode text overlay to PNG');
    return byteData.buffer.asUint8List();
  }

  static void _drawBadge({
    required Canvas canvas,
    required String text,
    required BadgeStyle style,
    required double top,
    required double left,
    required double sf,
  }) {
    final fontSize = 30.0 * sf;
    final size = measureBadge(style, text, fontSize);
    final rect = Rect.fromLTWH(left, top, size.width, size.height);
    paintBadgeOn(
      canvas,
      rect: rect,
      style: style,
      text: text,
      fontSize: fontSize,
    );
  }

  static void _drawPriceBadge({
    required Canvas canvas,
    required String offerPrice,
    required String mrpPrice,
    required double top,
    required double right,
    required double canvasWidth,
    required double sf,
  }) {
    final padH   = 22.0 * sf;
    final padV   = 12.0 * sf;
    final gap    = 6.0  * sf;
    final radius = (14.0 * sf).clamp(6.0, 20.0);

    final bool hasOffer = offerPrice.isNotEmpty;
    final bool hasMrp   = mrpPrice.isNotEmpty;

    TextPainter? mrpPainter;
    if (hasMrp) {
      mrpPainter = TextPainter(
        text: TextSpan(
          text: '₹$mrpPrice',
          style: TextStyle(
            color: const Color(0xFF5A3A00),
            fontSize: 26.0 * sf,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }

    TextPainter? offerPainter;
    if (hasOffer) {
      offerPainter = TextPainter(
        text: TextSpan(
          text: '₹$offerPrice',
          style: TextStyle(
            color: Colors.black,
            fontSize: 38.0 * sf,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }

    final double contentW = [
      mrpPainter?.width ?? 0,
      offerPainter?.width ?? 0,
    ].reduce((a, b) => a > b ? a : b);

    final double contentH = (mrpPainter != null && offerPainter != null)
        ? mrpPainter.height + gap + offerPainter.height
        : (mrpPainter?.height ?? offerPainter?.height ?? 0);

    final double badgeW = contentW + padH * 2;
    final double badgeH = contentH + padV * 2;
    final double x = canvasWidth - badgeW - right;

    final rrect = RRect.fromLTRBR(
        x, top, x + badgeW, top + badgeH, Radius.circular(radius));

    canvas.drawRRect(
      rrect.shift(const Offset(2, 3)),
      Paint()
        ..color = Colors.black.withOpacity(0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawRRect(rrect, Paint()..color = const Color(0xFFFFB300));

    double drawY = top + padV;

    if (mrpPainter != null) {
      mrpPainter.paint(canvas, Offset(x + padH, drawY));
      final strikeY = drawY + mrpPainter.height * 0.55;
      canvas.drawLine(
        Offset(x + padH - 2, strikeY),
        Offset(x + padH + mrpPainter.width + 2, strikeY),
        Paint()
          ..color = const Color(0xFFCC2200)
          ..strokeWidth = 3.5 * sf
          ..strokeCap = StrokeCap.round,
      );
      drawY += mrpPainter.height + gap;
    }

    if (offerPainter != null) {
      offerPainter.paint(canvas, Offset(x + padH, drawY));
    }
  }
}
