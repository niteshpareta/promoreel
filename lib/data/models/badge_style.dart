import 'dart:ui' show Color;

/// Visual shape of an offer badge. Kept distinct from style so users can
/// swap presets cleanly; the painter reads [BadgeStyle.shape] and renders
/// the right path.
enum BadgeShape {
  /// Default flat rounded rectangle. Always works; fallback for unknown shapes.
  roundedPill,

  /// 10-point star burst — high-energy "SALE!" feel.
  starburst,

  /// Ribbon banner with triangular notches cut into both ends.
  ribbon,

  /// Parallelogram slanted like a racing stripe.
  diagonalBanner,

  /// Solid circle — text fits inside; natural for short labels like "50%".
  circle,
}

/// Optional flourish drawn on top of the base fill. Kept small on purpose
/// — these are orthogonal to the shape so any preset can toggle them on
/// without new artwork.
enum BadgeDecor {
  none,

  /// Diagonal glossy highlight across the upper half — gives badges a
  /// tactile "sticker" quality.
  shine,

  /// Thin inset secondary border — the classic "award ribbon" treatment.
  doubleBorder,
}

enum BadgeAnimStyle {
  none,
  pop,
  slideIn,
  rotateIn,
  pulse,
}

/// Convert an id to the enum — mirrors `parseCaptionEffect`. Returns null
/// for empty / unknown strings so callers can fall back to preset defaults.
BadgeAnimStyle? parseBadgeAnim(String raw) {
  switch (raw) {
    case 'pop':
      return BadgeAnimStyle.pop;
    case 'slide_in':
      return BadgeAnimStyle.slideIn;
    case 'rotate_in':
      return BadgeAnimStyle.rotateIn;
    case 'pulse':
      return BadgeAnimStyle.pulse;
    case 'none':
      return BadgeAnimStyle.none;
    default:
      return null;
  }
}

String badgeAnimId(BadgeAnimStyle a) => a.name;

/// Bundle of shape + colours + decoration that together define a badge's
/// look. Picked once from the Badge Style sheet; individual colour
/// overrides can stack on top via [withOverrides].
class BadgeStyle {
  const BadgeStyle({
    required this.id,
    required this.label,
    required this.shape,
    required this.fillColor,
    required this.textColor,
    this.borderColor,
    this.decor = BadgeDecor.none,
    this.shadow = true,
    this.fontWeightIndex = 900, // w900 default
    this.fontFamily = 'Manrope',
    this.letterSpacing = 0.5,
  });

  /// Stable machine id — serialised into
  /// `VideoProject.frameOfferBadgeStyles`.
  final String id;
  final String label;
  final BadgeShape shape;
  final Color fillColor;
  final Color textColor;

  /// Null = no stroke; else draw a thin border in this colour.
  final Color? borderColor;
  final BadgeDecor decor;

  /// Drop shadow under the badge — makes it read as a sticker.
  final bool shadow;

  /// Font weight as an integer (100–900). Using the index so we can
  /// round-trip through JSON later if we decide to expose it as an
  /// override.
  final int fontWeightIndex;
  final String fontFamily;
  final double letterSpacing;

  /// Layer per-badge overrides onto the preset. Only colour overrides are
  /// exposed in v1 — font / shape are preset-locked to keep the UI sane.
  BadgeStyle withOverrides({int? fillOverride, int? textOverride}) {
    return BadgeStyle(
      id: id,
      label: label,
      shape: shape,
      fillColor:
          (fillOverride == null || fillOverride == 0) ? fillColor : Color(fillOverride),
      textColor:
          (textOverride == null || textOverride == 0) ? textColor : Color(textOverride),
      borderColor: borderColor,
      decor: decor,
      shadow: shadow,
      fontWeightIndex: fontWeightIndex,
      fontFamily: fontFamily,
      letterSpacing: letterSpacing,
    );
  }

  static BadgeStyle byId(String id) => _byId[id] ?? defaultStyle;

  static BadgeStyle get defaultStyle => _byId['flat_ember']!;
  static const String defaultStyleId = 'flat_ember';

  static final List<BadgeStyle> all = [
    const BadgeStyle(
      id: 'flat_ember',
      label: 'Flat Ember',
      shape: BadgeShape.roundedPill,
      fillColor: Color(0xFFF2A848),
      textColor: Color(0xFF3D2307),
    ),
    const BadgeStyle(
      id: 'starburst_red',
      label: 'Starburst',
      shape: BadgeShape.starburst,
      fillColor: Color(0xFFE53935),
      textColor: Color(0xFFFFFFFF),
      decor: BadgeDecor.shine,
    ),
    const BadgeStyle(
      id: 'ribbon_gold',
      label: 'Ribbon Gold',
      shape: BadgeShape.ribbon,
      fillColor: Color(0xFFD4A014),
      textColor: Color(0xFF3E2C00),
      decor: BadgeDecor.doubleBorder,
      borderColor: Color(0xFF8C6A00),
    ),
    const BadgeStyle(
      id: 'outlined_white',
      label: 'Outlined',
      shape: BadgeShape.roundedPill,
      fillColor: Color(0x00000000), // transparent
      textColor: Color(0xFFFFFFFF),
      borderColor: Color(0xFFFFFFFF),
      shadow: false,
    ),
    const BadgeStyle(
      id: 'diagonal_banner',
      label: 'Diagonal',
      shape: BadgeShape.diagonalBanner,
      fillColor: Color(0xFFFF6E40),
      textColor: Color(0xFFFFFFFF),
      letterSpacing: 1.2,
    ),
    const BadgeStyle(
      id: 'circle_mint',
      label: 'Circle',
      shape: BadgeShape.circle,
      fillColor: Color(0xFF00C853),
      textColor: Color(0xFFFFFFFF),
      decor: BadgeDecor.shine,
    ),
  ];

  static final Map<String, BadgeStyle> _byId = {
    for (final s in all) s.id: s,
  };
}
