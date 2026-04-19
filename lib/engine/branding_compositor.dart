import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../data/models/branding_preset.dart';

class BrandingCompositor {
  static const int stripHeight = 128;

  static Future<String> renderToFile({
    required BrandingPreset preset,
    required String outputPath,
    int width = 720,
  }) async {
    final bytes = await _renderPng(preset: preset, width: width);
    await File(outputPath).writeAsBytes(bytes);
    return outputPath;
  }

  static Future<Uint8List> _renderPng({
    required BrandingPreset preset,
    required int width,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, width.toDouble(), stripHeight.toDouble()),
    );

    // Semi-transparent dark background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), stripHeight.toDouble()),
      Paint()..color = const Color(0xCC0D0D1A),
    );

    // Left accent bar
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 4, 128),
      Paint()..color = const Color(0xFF7C4DFF),
    );

    const double logoSize = 68;
    const double logoX    = 16;
    final double logoY    = (stripHeight - logoSize) / 2;
    const double textStartX = 96;

    // Logo area
    final logoRect = Rect.fromLTWH(logoX, logoY, logoSize, logoSize);
    final logoRRect = RRect.fromRectAndRadius(logoRect, const Radius.circular(10));

    final logoPath = preset.logoPath;
    bool drewLogo = false;

    if (logoPath != null && File(logoPath).existsSync()) {
      try {
        final imgBytes = await File(logoPath).readAsBytes();
        final codec = await ui.instantiateImageCodec(
          imgBytes,
          targetWidth: logoSize.toInt(),
          targetHeight: logoSize.toInt(),
        );
        final frame = await codec.getNextFrame();
        final img   = frame.image;

        canvas.save();
        canvas.clipRRect(logoRRect);
        canvas.drawImageRect(
          img,
          Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
          logoRect,
          Paint()..filterQuality = FilterQuality.medium,
        );
        canvas.restore();
        img.dispose();
        drewLogo = true;
      } catch (_) {}
    }

    if (!drewLogo) {
      // Placeholder box
      canvas.drawRRect(logoRRect, Paint()..color = const Color(0xFF252540));
      // Store icon outline
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(logoX + 16, logoY + 18, 36, 28),
          const Radius.circular(4),
        ),
        Paint()
          ..color = const Color(0xFF7C4DFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    final double centerY = stripHeight / 2.0;

    if (preset.businessName.isNotEmpty) {
      final painter = TextPainter(
        text: TextSpan(
          text: preset.businessName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: width - textStartX - 20.0);
      painter.paint(canvas, Offset(textStartX, centerY - painter.height - 2));
    }

    if (preset.phoneNumber.isNotEmpty) {
      final painter = TextPainter(
        text: TextSpan(
          text: preset.phoneNumber,
          style: const TextStyle(
            color: Color(0xFFB0AFCC),
            fontSize: 22,
            fontWeight: FontWeight.w400,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: width - textStartX - 20.0);
      painter.paint(canvas, Offset(textStartX, centerY + 4));
    }

    final picture  = recorder.endRecording();
    final image    = await picture.toImage(width, stripHeight);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw StateError('Failed to encode branding strip to PNG');
    return byteData.buffer.asUint8List();
  }
}
