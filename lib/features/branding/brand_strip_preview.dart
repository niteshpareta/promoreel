import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/models/branding_preset.dart';

/// Pure-Flutter rendering of the branding strip that mirrors the four
/// layouts in `BrandingCompositor`. Used by the editor's preview canvas
/// and the branding screen's preview card so users see exactly what
/// they're going to export.
///
/// `width` / `height` should match the live preview container. For
/// side-badge the strip doesn't span the full width — the widget
/// anchors itself to the right inside whatever box it's given.
class BrandStripPreview extends StatelessWidget {
  const BrandStripPreview({
    super.key,
    required this.preset,
    required this.width,
    this.heightFraction = 0.14,
  });

  final BrandingPreset preset;
  final double width;

  /// Strip height as a fraction of the parent's height (default ~14%
  /// matches the 168/1280 ratio of the 720×1280 compositor output —
  /// sized so the business name is legible at phone-viewing distance).
  final double heightFraction;

  static const int _defaultPrimaryArgb = 0xFFF2A848;
  static const int _defaultAccentArgb = 0xFF7C4DFF;

  Color get primary => Color(preset.primaryColorArgb == 0
      ? _defaultPrimaryArgb
      : preset.primaryColorArgb);
  Color get accent => Color(preset.accentColorArgb == 0
      ? _defaultAccentArgb
      : preset.accentColorArgb);

  Color _onPrimary() {
    final lum =
        0.299 * primary.r + 0.587 * primary.g + 0.114 * primary.b;
    return lum > 0.6 ? Colors.black : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    switch (preset.styleId) {
      case BrandingStyleId.modernMinimal:
        return _buildModernMinimal(context);
      case BrandingStyleId.boldRibbon:
        return _buildBoldRibbon(context);
      case BrandingStyleId.sideBadge:
        return _buildSideBadge(context);
      case BrandingStyleId.classic:
      default:
        return _buildClassic(context);
    }
  }

  Widget _logo({required double size, double radius = 8}) {
    final path = preset.logoPath;
    final hasLogo = path != null && File(path).existsSync();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF252540),
        borderRadius: BorderRadius.circular(radius),
        image: hasLogo
            ? DecorationImage(image: FileImage(File(path)), fit: BoxFit.cover)
            : null,
      ),
      child: hasLogo
          ? null
          : Center(
              child: Icon(Icons.store_rounded,
                  color: primary, size: size * 0.5),
            ),
    );
  }

  Widget _buildClassic(BuildContext context) {
    final h = width * (heightFraction / (9 / 16));
    return Container(
      width: width,
      height: h,
      color: const Color(0xCC0D0D1A),
      child: Row(
        children: [
          Container(width: 4, color: primary),
          const SizedBox(width: 14),
          _logo(size: h * 0.66, radius: 8),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (preset.businessName.isNotEmpty)
                  Text(
                    preset.businessName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: h * 0.34,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (preset.phoneNumber.isNotEmpty ||
                    preset.address.isNotEmpty)
                  Text(
                    [
                      if (preset.phoneNumber.isNotEmpty) preset.phoneNumber,
                      if (preset.address.isNotEmpty) preset.address,
                    ].join('  ·  '),
                    style: TextStyle(
                      color: const Color(0xFFCCCBE3),
                      fontSize: h * 0.22,
                      fontWeight: FontWeight.w500,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
        ],
      ),
    );
  }

  Widget _buildModernMinimal(BuildContext context) {
    final h = width * (heightFraction / (9 / 16));
    final tail = <String>[
      if (preset.phoneNumber.isNotEmpty) preset.phoneNumber,
      if (preset.socialHandle.isNotEmpty) preset.socialHandle,
      if (preset.website.isNotEmpty) preset.website,
      if (preset.address.isNotEmpty) preset.address,
    ];
    return Container(
      width: width,
      height: h,
      color: const Color(0x9A0B0B12),
      child: Column(
        children: [
          Container(height: 2, color: primary.withValues(alpha: 0.9)),
          Expanded(
            child: Row(
              children: [
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _logo(size: h * 0.58, radius: 10),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (preset.businessName.isNotEmpty)
                        Text(
                          preset.businessName.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: h * 0.28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.6,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (tail.isNotEmpty)
                        Text(
                          tail.join('  ·  '),
                          style: TextStyle(
                            color: primary.withValues(alpha: 0.95),
                            fontSize: h * 0.20,
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoldRibbon(BuildContext context) {
    final h = width * (heightFraction / (9 / 16));
    final onPrimary = _onPrimary();
    final tail = <String>[
      if (preset.tagline.isNotEmpty) preset.tagline,
      if (preset.phoneNumber.isNotEmpty) preset.phoneNumber,
      if (preset.address.isNotEmpty) preset.address,
    ];
    return Container(
      width: width,
      height: h,
      color: primary,
      child: Stack(
        children: [
          Row(
            children: [
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: _logo(size: h * 0.74, radius: 12),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (preset.businessName.isNotEmpty)
                      Text(
                        preset.businessName,
                        style: TextStyle(
                          color: onPrimary,
                          fontSize: h * 0.38,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                          height: 1.05,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (tail.isNotEmpty)
                      Text(
                        tail.join('  ·  '),
                        style: TextStyle(
                          color: onPrimary.withValues(alpha: 0.9),
                          fontSize: h * 0.22,
                          fontWeight: FontWeight.w600,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 4,
            child: Container(color: Colors.black.withValues(alpha: 0.22)),
          ),
        ],
      ),
    );
  }

  Widget _buildSideBadge(BuildContext context) {
    final path = preset.logoPath;
    final hasLogo = path != null && File(path).existsSync();
    final tail = <String>[
      if (preset.phoneNumber.isNotEmpty) preset.phoneNumber,
      if (preset.socialHandle.isNotEmpty) preset.socialHandle,
    ];
    // Scale badge sizing with strip width so it stays proportionate
    // whether the preview is a full video frame or a 140px thumbnail.
    final nameSize = (width * 0.055).clamp(13.0, 22.0);
    final tailSize = (width * 0.035).clamp(9.0, 14.0);
    final logoPx = (width * 0.13).clamp(24.0, 50.0);
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xDD0E0E18),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: primary.withValues(alpha: 0.9),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasLogo)
                ClipOval(
                  child: Image.file(File(path),
                      width: logoPx, height: logoPx, fit: BoxFit.cover),
                ),
              if (hasLogo) const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (preset.businessName.isNotEmpty)
                    Text(
                      preset.businessName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: nameSize,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                      maxLines: 1,
                    ),
                  if (tail.isNotEmpty)
                    Text(
                      tail.join(' · '),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: tailSize,
                        fontWeight: FontWeight.w500,
                        height: 1.1,
                      ),
                      maxLines: 1,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Miniature full-frame brand card preview used on the branding screen
/// to show what the intro / outro will look like. Mirrors
/// [IntroOutroCompositor] at a glance — colours, logo, tagline.
class BrandCardPreview extends StatelessWidget {
  const BrandCardPreview({super.key, required this.preset, this.isOutro = false});

  final BrandingPreset preset;
  final bool isOutro;

  @override
  Widget build(BuildContext context) {
    final primary = Color(preset.primaryColorArgb == 0
        ? 0xFFF2A848
        : preset.primaryColorArgb);
    final hsl = HSLColor.fromColor(primary);
    final darker = hsl
        .withLightness((hsl.lightness - 0.18).clamp(0.0, 1.0))
        .toColor();

    final path = preset.logoPath;
    final hasLogo = path != null && File(path).existsSync();

    final lum =
        0.299 * primary.r + 0.587 * primary.g + 0.114 * primary.b;
    final onPrimary = lum > 0.6 ? Colors.black : Colors.white;

    final tagline = preset.tagline.isNotEmpty
        ? preset.tagline
        : (isOutro ? 'Thanks for watching' : '');

    return AspectRatio(
      aspectRatio: 9 / 16,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [primary, darker],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: hasLogo
                  ? ClipOval(
                      child: Image.file(File(path), fit: BoxFit.cover))
                  : Center(
                      child: Text(
                        _initials(preset.businessName),
                        style: TextStyle(
                          color: primary,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 14),
            if (preset.businessName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  preset.businessName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: onPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 2,
                ),
              ),
            if (tagline.isNotEmpty) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Text(
                  tagline,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: onPrimary.withValues(alpha: 0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                ),
              ),
            ],
            const Spacer(flex: 3),
            if (preset.phoneNumber.isNotEmpty ||
                preset.socialHandle.isNotEmpty ||
                preset.website.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  [
                    if (preset.phoneNumber.isNotEmpty) preset.phoneNumber,
                    if (preset.socialHandle.isNotEmpty) preset.socialHandle,
                    if (preset.website.isNotEmpty) preset.website,
                  ].join('  ·  '),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: onPrimary,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    if (name.isEmpty) return '•';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }
}
