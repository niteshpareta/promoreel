import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../core/utils/text_position.dart';

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
    int width = 720,
    int height = 1280,
  }) async {
    final bytes = await _renderPng(
      headline: headline,
      priceTag: priceTag,
      mrpTag: mrpTag,
      offerBadge: offerBadge,
      textPosition: textPosition,
      badgeSize: badgeSize,
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

    // Gradient scrim for text legibility — only for legacy presets. Custom
    // drag positions get no scrim; the text's own drop-shadows handle
    // legibility without locking a huge dark band to the frame.
    if (hasText && !pos.isCustom) {
      final Paint scrimPaint = Paint();
      if (textPosition == 'top') {
        scrimPaint.shader = const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.transparent, Color(0xCC000000)],
          stops: [0.3, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, width.toDouble(), height * 0.45));
        canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height * 0.45), scrimPaint);
      } else if (textPosition == 'center') {
        scrimPaint.color = const Color(0x99000000);
        canvas.drawRect(
          Rect.fromLTWH(0, height * 0.35, width.toDouble(), height * 0.30),
          scrimPaint,
        );
      } else {
        scrimPaint.shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Color(0xCC000000)],
          stops: [0.0, 1.0],
        ).createShader(Rect.fromLTWH(0, height * 0.55, width.toDouble(), height * 0.45));
        canvas.drawRect(
          Rect.fromLTWH(0, height * 0.55, width.toDouble(), height * 0.45),
          scrimPaint,
        );
      }
    }

    // Caption text
    if (hasText) {
      final painter = TextPainter(
        text: TextSpan(
          text: headline,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 48,
            fontWeight: FontWeight.w800,
            height: 1.2,
            shadows: [
              Shadow(color: Colors.black, blurRadius: 12, offset: Offset(2, 2)),
              Shadow(color: Colors.black, blurRadius: 6),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 2,
      )..layout(maxWidth: width - 60.0);

      final double x;
      final double y;
      if (pos.isCustom) {
        // Centre the caption block on the fractional offset, clamped so the
        // text never overflows the frame.
        x = (width * pos.offset.dx - painter.width / 2)
            .clamp(24.0, width - painter.width - 24.0);
        y = (height * pos.offset.dy - painter.height / 2)
            .clamp(40.0, height - painter.height - 40.0);
      } else if (textPosition == 'top') {
        // Push caption below badge row when badges exist to avoid overlap
        x = 30;
        y = hasBadgeOverlay ? (80 + badgeH + 12) : 100.0;
      } else if (textPosition == 'center') {
        x = 30;
        y = (height - painter.height) / 2.0;
      } else {
        x = 30;
        y = height - 148.0 - painter.height;
      }
      painter.paint(canvas, Offset(x, y));
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

    // Offer badge — top-left
    if (hasBadge) {
      final color = _badgeColors[offerBadge] ?? const Color(0xFFFF6E40);
      _drawBadge(
        canvas: canvas,
        text: offerBadge,
        bgColor: color,
        textColor: Colors.white,
        top: 80,
        left: 36,
        canvasWidth: width.toDouble(),
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
    required Color bgColor,
    required Color textColor,
    required double top,
    required double canvasWidth,
    required double sf,
    double? left,
    double? right,
  }) {
    final fontSize = 30.0 * sf;
    final padH = 22.0 * sf;
    final padV = 10.0 * sf;
    final radius = (14.0 * sf).clamp(6.0, 20.0);

    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final badgeW = painter.width + padH * 2;
    final badgeH = painter.height + padV * 2;
    final double x = left ?? (canvasWidth - badgeW - right!);

    final rrect = RRect.fromLTRBR(x, top, x + badgeW, top + badgeH,
        Radius.circular(radius));

    canvas.drawRRect(
      rrect.shift(const Offset(2, 3)),
      Paint()
        ..color = Colors.black.withOpacity(0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawRRect(rrect, Paint()..color = bgColor);
    painter.paint(canvas, Offset(x + padH, top + padV));
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
