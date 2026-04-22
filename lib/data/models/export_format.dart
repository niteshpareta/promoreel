import 'package:flutter/material.dart';

enum ExportFormat { vertical, square, landscape }

/// Export resolution tier. Users pick this on the Review screen before
/// hitting Export; each tier maps the same aspect ratio (vertical /
/// square / landscape) to a different pixel count.
///
///   • `hd` — 720p, ~8 MB, faster to render. Plenty for WhatsApp Status.
///   • `fullHd` — 1080p, ~18 MB, slower to render. Best for Reels /
///     YouTube Shorts / feed posts where users expect sharp 1080p.
enum ExportQuality { hd, fullHd }

extension ExportQualityX on ExportQuality {
  /// Short-edge pixel count — used to scale the format's dimensions.
  /// 720 for HD, 1080 for Full HD. Long edge derives from aspect ratio.
  int get shortEdge => this == ExportQuality.fullHd ? 1080 : 720;

  /// Target video bitrate (bits/sec). Full HD gets ~2× the bits of HD so
  /// the per-pixel quality stays similar.
  int get bitrate =>
      this == ExportQuality.fullHd ? 4500000 /* 4.5 Mbps */ : 2000000 /* 2 */;

  String get label =>
      this == ExportQuality.fullHd ? 'Full HD' : 'HD';

  String get resolutionLabel =>
      this == ExportQuality.fullHd ? '1080p' : '720p';

  /// Rough file-size hint shown in the chooser. Real size varies with
  /// duration / motion / caption count; this is what users will see for a
  /// ~15-20 s promo.
  String get sizeHint => this == ExportQuality.fullHd ? '~18 MB' : '~8 MB';

  /// One-line tradeoff tagline under the chooser tile.
  String get tagline => this == ExportQuality.fullHd
      ? 'Sharper, bigger file — best for Reels / Shorts'
      : 'Smaller, faster — fine for WhatsApp Status';
}

extension ExportFormatX on ExportFormat {
  /// Output width at the given [quality]. Defaults to HD if the caller
  /// doesn't pass a quality (legacy callers).
  double outWidthFor(ExportQuality q) {
    final s = q.shortEdge.toDouble();
    switch (this) {
      case ExportFormat.vertical:
        return s; // 9:16 short edge is width
      case ExportFormat.square:
        return s;
      case ExportFormat.landscape:
        return (s * 16 / 9).roundToDouble(); // e.g. 720→1280, 1080→1920
    }
  }

  double outHeightFor(ExportQuality q) {
    final s = q.shortEdge.toDouble();
    switch (this) {
      case ExportFormat.vertical:
        return (s * 16 / 9).roundToDouble(); // 720→1280, 1080→1920
      case ExportFormat.square:
        return s;
      case ExportFormat.landscape:
        return s;
    }
  }

  /// Back-compat accessors — assume HD (720p) when a quality isn't
  /// threaded through. The media encoder always passes an explicit
  /// quality now, so these are only hit by legacy code paths.
  double get outWidth => outWidthFor(ExportQuality.hd);
  double get outHeight => outHeightFor(ExportQuality.hd);
  double get aspectRatio => outWidth / outHeight;

  String get label => switch (this) {
        ExportFormat.vertical  => '9:16',
        ExportFormat.square    => '1:1',
        ExportFormat.landscape => '16:9',
      };

  IconData get icon => switch (this) {
        ExportFormat.vertical  => Icons.stay_current_portrait_rounded,
        ExportFormat.square    => Icons.crop_square_rounded,
        ExportFormat.landscape => Icons.stay_current_landscape_rounded,
      };
}
