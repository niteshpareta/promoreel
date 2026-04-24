import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../data/models/branding_preset.dart';

/// Renders the branding strip overlay (bottom or top of the video) as a
/// transparent PNG sized to the output frame. Four style presets are
/// supported — see [BrandingStyleId].
///
/// Everything is parametric: the strip inherits the preset's primary /
/// accent colours, renders the address when present, and lays out text
/// without hardcoding font sizes to a single resolution.
class BrandingCompositor {
  /// Logical strip height used by the bottom-strip presets. Sized at
  /// ~13% of a 1280p output so the business name is legible at
  /// phone-viewing distance (the old 128px height pushed text to ~10%
  /// of screen — too small for a promo video).
  static const double _bottomStripHeight = 168;

  /// Default ember primary when the preset leaves `primaryColorArgb = 0`.
  /// Matches `AppColors.brandEmber` — kept as a literal so the engine
  /// layer stays independent of the UI theme module.
  static const int _defaultPrimaryArgb = 0xFFF2A848;

  /// Default cool accent when `accentColorArgb = 0`. Muted purple that
  /// reads well against both light and dark source frames.
  static const int _defaultAccentArgb = 0xFF7C4DFF;

  static Future<String> renderToFile({
    required BrandingPreset preset,
    required String outputPath,
    int outW = 720,
    int outH = 1280,
  }) async {
    final bytes = await _renderPng(preset: preset, outW: outW, outH: outH);
    await File(outputPath).writeAsBytes(bytes);
    return outputPath;
  }

  static Future<Uint8List> _renderPng({
    required BrandingPreset preset,
    required int outW,
    required int outH,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
    );

    // Load the logo upfront so all presets can use it without duplicating
    // the async / error-handling dance.
    final logoImage = await _loadLogo(preset);

    final primary = Color(preset.primaryColorArgb == 0
        ? _defaultPrimaryArgb
        : preset.primaryColorArgb);
    final accent = Color(preset.accentColorArgb == 0
        ? _defaultAccentArgb
        : preset.accentColorArgb);

    final topAnchored = preset.stripPosition == 'top';
    final bandY = topAnchored ? 0.0 : outH - _bottomStripHeight;

    switch (preset.styleId) {
      case BrandingStyleId.modernMinimal:
        _paintModernMinimal(
          canvas, preset, logoImage, primary, accent,
          outW: outW, bandY: bandY,
        );
        break;
      case BrandingStyleId.boldRibbon:
        _paintBoldRibbon(
          canvas, preset, logoImage, primary, accent,
          outW: outW, bandY: bandY,
        );
        break;
      case BrandingStyleId.sideBadge:
        _paintSideBadge(
          canvas, preset, logoImage, primary, accent,
          outW: outW, outH: outH, topAnchored: topAnchored,
        );
        break;
      case BrandingStyleId.classic:
      default:
        _paintClassic(
          canvas, preset, logoImage, primary, accent,
          outW: outW, bandY: bandY,
        );
    }

    logoImage?.dispose();

    final picture = recorder.endRecording();
    final image = await picture.toImage(outW, outH);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Failed to encode branding strip to PNG');
    }
    final bytes = byteData.buffer.asUint8List();
    image.dispose();
    return bytes;
  }

  // ── Style presets ──────────────────────────────────────────────────────────

  /// Classic: dark bar along the bottom (or top), left accent line, logo
  /// square, business name + phone stacked. Address appears if provided.
  static void _paintClassic(
    Canvas canvas,
    BrandingPreset preset,
    ui.Image? logo,
    Color primary,
    Color accent, {
    required int outW,
    required double bandY,
  }) {
    final bandRect = Rect.fromLTWH(
        0, bandY, outW.toDouble(), _bottomStripHeight);
    canvas.drawRect(
      bandRect,
      Paint()..color = const Color(0xCC0D0D1A),
    );
    // Left accent line — takes on the preset's primary colour.
    canvas.drawRect(
      Rect.fromLTWH(0, bandY, 4, _bottomStripHeight),
      Paint()..color = primary,
    );

    const logoSize = 100.0;
    const logoX = 20.0;
    final logoY = bandY + (_bottomStripHeight - logoSize) / 2;
    _drawLogoOrPlaceholder(
      canvas, logo, primary, Rect.fromLTWH(logoX, logoY, logoSize, logoSize));

    const textStartX = 140.0;
    final maxTextW = outW - textStartX - 20.0;
    final centerY = bandY + _bottomStripHeight / 2;

    final lines = <_LineSpec>[];
    if (preset.businessName.isNotEmpty) {
      lines.add(_LineSpec(
        preset.businessName,
        color: Colors.white,
        fontSize: 44,
        fontWeight: FontWeight.w800,
      ));
    }
    final secondary = <String>[];
    if (preset.phoneNumber.isNotEmpty) secondary.add(preset.phoneNumber);
    if (preset.address.isNotEmpty) secondary.add(preset.address);
    if (secondary.isNotEmpty) {
      lines.add(_LineSpec(
        secondary.join('  ·  '),
        color: const Color(0xFFCCCBE3),
        fontSize: 28,
        fontWeight: FontWeight.w500,
      ));
    }
    _paintStackedLines(canvas, lines,
        leftX: textStartX, centerY: centerY, maxWidth: maxTextW);
  }

  /// Modern Minimal: semi-transparent bar, hairline primary rule on top,
  /// logo in a rounded white pill, small caps type.
  static void _paintModernMinimal(
    Canvas canvas,
    BrandingPreset preset,
    ui.Image? logo,
    Color primary,
    Color accent, {
    required int outW,
    required double bandY,
  }) {
    final bandRect =
        Rect.fromLTWH(0, bandY, outW.toDouble(), _bottomStripHeight);
    canvas.drawRect(
      bandRect,
      Paint()..color = const Color(0x9A0B0B12),
    );
    // Hairline top rule in primary.
    canvas.drawRect(
      Rect.fromLTWH(0, bandY, outW.toDouble(), 2),
      Paint()..color = primary.withValues(alpha: 0.9),
    );

    const logoSize = 86.0;
    const logoX = 22.0;
    final logoY = bandY + (_bottomStripHeight - logoSize) / 2;
    // White pill behind the logo so brand marks with transparency read.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(logoX - 5, logoY - 5, logoSize + 10, logoSize + 10),
        const Radius.circular(16),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.95),
    );
    _drawLogoOrPlaceholder(
      canvas, logo, primary,
      Rect.fromLTWH(logoX, logoY, logoSize, logoSize),
      rounded: true,
      placeholderBg: Colors.transparent,
    );

    const textStartX = 130.0;
    final maxTextW = outW - textStartX - 20.0;
    final centerY = bandY + _bottomStripHeight / 2;

    final lines = <_LineSpec>[];
    if (preset.businessName.isNotEmpty) {
      lines.add(_LineSpec(
        preset.businessName.toUpperCase(),
        color: Colors.white,
        fontSize: 36,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.8,
      ));
    }
    final tail = <String>[];
    if (preset.phoneNumber.isNotEmpty) tail.add(preset.phoneNumber);
    if (preset.socialHandle.isNotEmpty) tail.add(preset.socialHandle);
    if (preset.website.isNotEmpty) tail.add(preset.website);
    if (preset.address.isNotEmpty) tail.add(preset.address);
    if (tail.isNotEmpty) {
      lines.add(_LineSpec(
        tail.join('  ·  '),
        color: primary.withValues(alpha: 0.95),
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ));
    }
    _paintStackedLines(canvas, lines,
        leftX: textStartX, centerY: centerY, maxWidth: maxTextW);
  }

  /// Bold Ribbon: full-width primary-coloured bar, very large business
  /// name. High-contrast "on-brand" option for loud promos.
  static void _paintBoldRibbon(
    Canvas canvas,
    BrandingPreset preset,
    ui.Image? logo,
    Color primary,
    Color accent, {
    required int outW,
    required double bandY,
  }) {
    final bandRect =
        Rect.fromLTWH(0, bandY, outW.toDouble(), _bottomStripHeight);
    canvas.drawRect(
      bandRect,
      Paint()..color = primary,
    );
    // Slight darker band at the bottom edge for grounding.
    canvas.drawRect(
      Rect.fromLTWH(0, bandY + _bottomStripHeight - 6, outW.toDouble(), 6),
      Paint()..color = Colors.black.withValues(alpha: 0.22),
    );

    const logoSize = 120.0;
    const logoX = 20.0;
    final logoY = bandY + (_bottomStripHeight - logoSize) / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(logoX, logoY, logoSize, logoSize),
        const Radius.circular(22),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.95),
    );
    _drawLogoOrPlaceholder(
      canvas, logo, accent,
      Rect.fromLTWH(logoX + 6, logoY + 6, logoSize - 12, logoSize - 12),
      rounded: true,
      placeholderBg: Colors.transparent,
    );

    const textStartX = 156.0;
    final maxTextW = outW - textStartX - 18.0;
    final centerY = bandY + _bottomStripHeight / 2;

    final lines = <_LineSpec>[];
    final onPrimary = _contrastingForeground(primary);
    if (preset.businessName.isNotEmpty) {
      lines.add(_LineSpec(
        preset.businessName,
        color: onPrimary,
        fontSize: 50,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.3,
      ));
    }
    final tail = <String>[];
    if (preset.tagline.isNotEmpty) tail.add(preset.tagline);
    if (preset.phoneNumber.isNotEmpty) tail.add(preset.phoneNumber);
    if (preset.address.isNotEmpty) tail.add(preset.address);
    if (tail.isNotEmpty) {
      lines.add(_LineSpec(
        tail.join('  ·  '),
        color: onPrimary.withValues(alpha: 0.9),
        fontSize: 26,
        fontWeight: FontWeight.w600,
      ));
    }
    _paintStackedLines(canvas, lines,
        leftX: textStartX, centerY: centerY, maxWidth: maxTextW);
  }

  /// Side Badge: not a full-width strip — a rounded pill anchored to the
  /// right edge of the frame. Less screen real-estate, more "brand logo"
  /// feel. Leaves the bottom of the frame clear.
  static void _paintSideBadge(
    Canvas canvas,
    BrandingPreset preset,
    ui.Image? logo,
    Color primary,
    Color accent, {
    required int outW,
    required int outH,
    required bool topAnchored,
  }) {
    const double badgeH = 104;
    const double padX = 18;
    const double rightMargin = 20;

    // Measure the text width so the pill auto-sizes.
    final labelLines = <_LineSpec>[];
    if (preset.businessName.isNotEmpty) {
      labelLines.add(_LineSpec(
        preset.businessName,
        color: Colors.white,
        fontSize: 32,
        fontWeight: FontWeight.w800,
      ));
    }
    final tail = <String>[];
    if (preset.phoneNumber.isNotEmpty) tail.add(preset.phoneNumber);
    if (preset.socialHandle.isNotEmpty) tail.add(preset.socialHandle);
    if (tail.isNotEmpty) {
      labelLines.add(_LineSpec(
        tail.join(' · '),
        color: Colors.white.withValues(alpha: 0.86),
        fontSize: 20,
        fontWeight: FontWeight.w500,
      ));
    }

    // Precompute painted widths.
    double textWidth = 0;
    for (final l in labelLines) {
      final tp = _textPainter(l, maxWidth: outW.toDouble());
      if (tp.width > textWidth) textWidth = tp.width;
    }

    const double logoSize = 72;
    final hasLogo = logo != null;
    final double badgeW =
        (hasLogo ? logoSize + 10 : 0) + textWidth + padX * 2 + 4;
    final double badgeX =
        (outW - badgeW - rightMargin).clamp(rightMargin, outW - rightMargin);
    final double badgeY =
        topAnchored ? rightMargin.toDouble() : outH - badgeH - rightMargin;

    // Pill with soft shadow.
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(badgeX, badgeY, badgeW, badgeH),
      Radius.circular(badgeH / 2),
    );
    canvas.drawRRect(
      rrect.shift(const Offset(0, 3)),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );
    canvas.drawRRect(
      rrect,
      Paint()..color = const Color(0xDD0E0E18),
    );
    // Thin primary-coloured ring.
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = primary.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Logo circle.
    if (hasLogo) {
      final logoRect = Rect.fromLTWH(
          badgeX + padX, badgeY + (badgeH - logoSize) / 2, logoSize, logoSize);
      _drawLogoOrPlaceholder(
        canvas, logo, primary, logoRect,
        rounded: true,
        radius: logoSize / 2,
        placeholderBg: Colors.white.withValues(alpha: 0.1),
      );
    }

    final textLeftX =
        badgeX + padX + (hasLogo ? logoSize + 10 : 0);
    final centerY = badgeY + badgeH / 2;
    _paintStackedLines(canvas, labelLines,
        leftX: textLeftX,
        centerY: centerY,
        maxWidth: badgeW - (textLeftX - badgeX) - padX);
  }

  // ── Drawing helpers ────────────────────────────────────────────────────────

  static Future<ui.Image?> _loadLogo(BrandingPreset preset) async {
    final path = preset.logoPath;
    if (path == null || !File(path).existsSync()) return null;
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(
        bytes,
        // 2× the largest logo slot we draw (80) so all presets get a
        // crisp render.
        targetWidth: 160,
        targetHeight: 160,
      );
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  static void _drawLogoOrPlaceholder(
    Canvas canvas,
    ui.Image? logo,
    Color primary,
    Rect target, {
    bool rounded = false,
    double? radius,
    Color placeholderBg = const Color(0xFF252540),
  }) {
    final r = radius ?? 10.0;
    final rrect = RRect.fromRectAndRadius(target, Radius.circular(r));

    if (logo != null) {
      canvas.save();
      canvas.clipRRect(rrect);
      canvas.drawImageRect(
        logo,
        Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
        target,
        Paint()..filterQuality = FilterQuality.medium,
      );
      canvas.restore();
      return;
    }
    canvas.drawRRect(rrect, Paint()..color = placeholderBg);
    // Simple outlined storefront glyph.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          target.left + target.width * 0.22,
          target.top + target.height * 0.28,
          target.width * 0.56,
          target.height * 0.44,
        ),
        const Radius.circular(4),
      ),
      Paint()
        ..color = primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  static TextPainter _textPainter(_LineSpec line, {required double maxWidth}) {
    return TextPainter(
      text: TextSpan(
        text: line.text,
        style: TextStyle(
          color: line.color,
          fontSize: line.fontSize,
          fontWeight: line.fontWeight,
          letterSpacing: line.letterSpacing,
          height: 1.15,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
  }

  /// Paints a vertical stack of 1-2 lines centred on [centerY]. Each
  /// line is ellipsised at [maxWidth].
  static void _paintStackedLines(
    Canvas canvas,
    List<_LineSpec> lines, {
    required double leftX,
    required double centerY,
    required double maxWidth,
  }) {
    if (lines.isEmpty) return;
    final painters =
        lines.map((l) => _textPainter(l, maxWidth: maxWidth)).toList();
    final totalHeight =
        painters.fold<double>(0, (a, p) => a + p.height) + (lines.length - 1) * 2;
    double y = centerY - totalHeight / 2;
    for (final p in painters) {
      p.paint(canvas, Offset(leftX, y));
      y += p.height + 2;
    }
  }

  /// Returns white or black depending on which contrasts better with
  /// [bg], so body text on the bold-ribbon stays readable regardless of
  /// the user's primary brand colour.
  static Color _contrastingForeground(Color bg) {
    // Use the approximate luminance formula from WCAG; enough for a
    // black-vs-white pick.
    final r = bg.r;
    final g = bg.g;
    final b = bg.b;
    final lum = 0.299 * r + 0.587 * g + 0.114 * b;
    return lum > 0.6 ? Colors.black : Colors.white;
  }
}

class _LineSpec {
  const _LineSpec(
    this.text, {
    required this.color,
    required this.fontSize,
    required this.fontWeight,
    this.letterSpacing = 0,
  });
  final String text;
  final Color color;
  final double fontSize;
  final FontWeight fontWeight;
  final double letterSpacing;
}
