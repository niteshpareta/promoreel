import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../data/models/branding_preset.dart';

/// Renders a full-frame brand card PNG for the intro or outro segment
/// of a video. The card is composed on a solid brand-coloured canvas
/// and contains:
///
///  - Logo, centred and large (or a fallback glyph)
///  - Business name, bold, under the logo
///  - Tagline, medium weight, under the name
///  - Phone / social / website row along the bottom
///
/// The card is static — motion comes from the xfade transition that
/// carries it onto / off the content frames.
class IntroOutroCompositor {
  static const int _defaultPrimaryArgb = 0xFFF2A848;
  static const int _defaultAccentArgb = 0xFF7C4DFF;

  static Future<String> renderCard({
    required BrandingPreset preset,
    required String outputPath,
    required int outW,
    required int outH,
    required bool isOutro,
  }) async {
    final bytes = await _renderPng(
        preset: preset, outW: outW, outH: outH, isOutro: isOutro);
    await File(outputPath).writeAsBytes(bytes);
    return outputPath;
  }

  static Future<Uint8List> _renderPng({
    required BrandingPreset preset,
    required int outW,
    required int outH,
    required bool isOutro,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
    );

    final primary = Color(preset.primaryColorArgb == 0
        ? _defaultPrimaryArgb
        : preset.primaryColorArgb);
    final accent = Color(preset.accentColorArgb == 0
        ? _defaultAccentArgb
        : preset.accentColorArgb);

    // Gradient background — primary → slightly darker primary. Gives the
    // card depth without needing a second colour from the user.
    final hsl = HSLColor.fromColor(primary);
    final darker = hsl
        .withLightness((hsl.lightness - 0.18).clamp(0.0, 1.0))
        .toColor();
    final bgPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(outW.toDouble(), outH.toDouble()),
        [primary, darker],
      );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
      bgPaint,
    );

    // Thin accent ribbon across the top for visual interest.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, outW.toDouble(), outH * 0.006),
      Paint()..color = accent.withValues(alpha: 0.95),
    );

    final onPrimary = _contrastingForeground(primary);

    // Logo, centered horizontally, positioned upper-third.
    final logoSize = outW * 0.42;
    final logoX = (outW - logoSize) / 2;
    final logoY = outH * 0.22;
    final logoRect = Rect.fromLTWH(logoX, logoY, logoSize, logoSize);

    await _drawLogoCircle(canvas, preset, logoRect,
        bgColor: Colors.white.withValues(alpha: 0.95),
        accent: accent);

    // Business name — large headline just below the logo.
    double cursorY = logoY + logoSize + outH * 0.04;
    if (preset.businessName.isNotEmpty) {
      final name = _textPainter(
        text: preset.businessName,
        color: onPrimary,
        fontSize: outW * 0.075,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
        maxWidth: outW * 0.86,
      );
      name.paint(canvas, Offset((outW - name.width) / 2, cursorY));
      cursorY += name.height + outH * 0.01;
    }

    // Tagline — mid-weight line under the name.
    final taglineText = preset.tagline.isNotEmpty
        ? preset.tagline
        : (isOutro
            ? 'Thanks for watching'
            : '');
    if (taglineText.isNotEmpty) {
      final tag = _textPainter(
        text: taglineText,
        color: onPrimary.withValues(alpha: 0.9),
        fontSize: outW * 0.038,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        maxWidth: outW * 0.84,
      );
      tag.paint(canvas, Offset((outW - tag.width) / 2, cursorY));
      cursorY += tag.height + outH * 0.02;
    }

    // Footer row — phone, social, website, separated by mid-dots. Only
    // rendered for values the user actually supplied.
    final footer = <String>[];
    if (preset.phoneNumber.isNotEmpty) footer.add(preset.phoneNumber);
    if (preset.socialHandle.isNotEmpty) footer.add(preset.socialHandle);
    if (preset.website.isNotEmpty) footer.add(preset.website);
    if (footer.isNotEmpty) {
      final f = _textPainter(
        text: footer.join('   ·   '),
        color: onPrimary.withValues(alpha: 0.95),
        fontSize: outW * 0.032,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        maxWidth: outW * 0.88,
      );
      f.paint(canvas, Offset((outW - f.width) / 2, outH * 0.86));
    }

    // Address in a smaller, softer line above the footer.
    if (preset.address.isNotEmpty) {
      final addr = _textPainter(
        text: preset.address,
        color: onPrimary.withValues(alpha: 0.7),
        fontSize: outW * 0.028,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        maxWidth: outW * 0.82,
      );
      addr.paint(canvas, Offset((outW - addr.width) / 2, outH * 0.80));
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(outW, outH);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Failed to encode intro/outro card to PNG');
    }
    final bytes = byteData.buffer.asUint8List();
    image.dispose();
    return bytes;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static Future<void> _drawLogoCircle(
    Canvas canvas,
    BrandingPreset preset,
    Rect rect, {
    required Color bgColor,
    required Color accent,
  }) async {
    final radius = rect.width / 2;
    final center = rect.center;

    // Soft shadow behind the logo circle to lift it from the background.
    canvas.drawCircle(
      center.translate(0, radius * 0.06),
      radius + 6,
      Paint()..color = Colors.black.withValues(alpha: 0.22),
    );

    // White pill backing.
    canvas.drawCircle(center, radius, Paint()..color = bgColor);

    final path = preset.logoPath;
    if (path != null && File(path).existsSync()) {
      try {
        final bytes = await File(path).readAsBytes();
        final codec = await ui.instantiateImageCodec(
          bytes,
          targetWidth: rect.width.toInt(),
          targetHeight: rect.height.toInt(),
        );
        final frame = await codec.getNextFrame();
        final img = frame.image;
        canvas.save();
        canvas.clipPath(Path()..addOval(rect.deflate(radius * 0.08)));
        canvas.drawImageRect(
          img,
          Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
          rect.deflate(radius * 0.08),
          Paint()..filterQuality = FilterQuality.medium,
        );
        canvas.restore();
        img.dispose();
        return;
      } catch (_) {}
    }

    // Fallback — initials from the business name inside the circle.
    final initials = _initialsFor(preset.businessName);
    final painter = _textPainter(
      text: initials,
      color: accent,
      fontSize: radius,
      fontWeight: FontWeight.w900,
      letterSpacing: -1,
      maxWidth: rect.width,
    );
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  static String _initialsFor(String name) {
    if (name.isEmpty) return '•';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  static TextPainter _textPainter({
    required String text,
    required Color color,
    required double fontSize,
    required FontWeight fontWeight,
    required double letterSpacing,
    required double maxWidth,
  }) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: letterSpacing,
          height: 1.15,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
  }

  static Color _contrastingForeground(Color bg) {
    final lum = 0.299 * bg.r + 0.587 * bg.g + 0.114 * bg.b;
    return lum > 0.6 ? Colors.black : Colors.white;
  }
}
