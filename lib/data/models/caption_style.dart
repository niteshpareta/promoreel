import 'dart:ui' show Color, FontWeight;

/// A preset bundle of visual decisions for a frame's caption — font family
/// + weight + text colour + optional pill colour + text effect. The user
/// picks one from the Style sheet in the caption editor; the renderer and
/// preview consume the same CaptionStyle object so they stay in lockstep.
///
/// Keep this list small (6 presets for v1). Per-axis tweaks (colour, font,
/// effect) will come later as overrides stacked on top of a chosen preset.
class CaptionStyle {
  const CaptionStyle({
    required this.id,
    required this.label,
    required this.fontFamily,
    required this.fontWeight,
    required this.textColor,
    required this.pillColor,
    this.effect = CaptionEffect.shadow,
    this.glowColor,
  });

  /// Stable machine id — serialised into `VideoProject.frameCaptionStyles`.
  final String id;

  /// Human label — shown on the preset tile.
  final String label;

  /// Google-Fonts family name. Resolved via `google_fonts` at render time;
  /// first load caches to disk so re-exports are offline.
  final String fontFamily;

  final FontWeight fontWeight;
  final Color textColor;

  /// `null` means "no pill" — just text on the photo.
  final Color? pillColor;

  final CaptionEffect effect;

  /// Only used when [effect] is [CaptionEffect.glow]. Colour of the outer
  /// glow halo; multiple blurred shadows stack into a neon feel.
  final Color? glowColor;

  /// Look up a preset by id. Falls back to [defaultStyle] for unknown ids so
  /// old drafts / JSON with a retired preset id still render.
  static CaptionStyle byId(String id) => _byId[id] ?? defaultStyle;

  /// The preset applied to new frames and to anything missing/legacy.
  static CaptionStyle get defaultStyle => _byId['clean']!;

  static const String defaultStyleId = 'clean';

  static final List<CaptionStyle> all = [
    const CaptionStyle(
      id: 'clean',
      label: 'Clean',
      fontFamily: 'Manrope',
      fontWeight: FontWeight.w800,
      textColor: Color(0xFFFFFFFF),
      pillColor: Color(0x8C000000),
    ),
    const CaptionStyle(
      id: 'bold_sale',
      label: 'Bold Sale',
      fontFamily: 'Manrope',
      fontWeight: FontWeight.w900,
      textColor: Color(0xFFFFFFFF),
      pillColor: Color(0xFFF2A848),
    ),
    const CaptionStyle(
      id: 'editorial',
      label: 'Editorial',
      fontFamily: 'Fraunces',
      fontWeight: FontWeight.w700,
      textColor: Color(0xFFFFFFFF),
      pillColor: null,
    ),
    const CaptionStyle(
      id: 'retro',
      label: 'Retro',
      fontFamily: 'Manrope',
      fontWeight: FontWeight.w900,
      textColor: Color(0xFFE8B84D),
      pillColor: Color(0xFF121212),
    ),
    const CaptionStyle(
      id: 'neon',
      label: 'Neon',
      fontFamily: 'Manrope',
      fontWeight: FontWeight.w900,
      textColor: Color(0xFFFFFFFF),
      pillColor: null,
      effect: CaptionEffect.glow,
      glowColor: Color(0xFF4DE1FF),
    ),
    const CaptionStyle(
      id: 'maroon',
      label: 'Maroon',
      fontFamily: 'Fraunces',
      fontWeight: FontWeight.w600,
      textColor: Color(0xFFF5E6D3),
      pillColor: Color(0xFF7A1F14),
    ),
  ];

  static final Map<String, CaptionStyle> _byId = {
    for (final s in all) s.id: s,
  };

  /// Return a new [CaptionStyle] that layers per-axis overrides on top of
  /// this preset. Passing null / 0 / empty for any axis keeps the preset's
  /// value for that axis — so presets remain the baseline until the user
  /// explicitly tweaks a specific control.
  CaptionStyle withOverrides({
    String? fontFamilyOverride,
    int? textColorOverride,
    int? pillColorOverride,
    CaptionEffect? effectOverride,
  }) {
    return CaptionStyle(
      id: id,
      label: label,
      fontFamily: fontFamilyOverride ?? fontFamily,
      fontWeight: fontWeight,
      textColor: textColorOverride == null || textColorOverride == 0
          ? textColor
          : Color(textColorOverride),
      pillColor: pillColorOverride == null || pillColorOverride == 0
          ? pillColor
          : Color(pillColorOverride),
      effect: effectOverride ?? effect,
      glowColor: glowColor,
    );
  }
}

/// Text effect variants. Kept tiny on purpose — adding effects is where UIs
/// get cluttered. Extend only when a preset / override actually needs it.
enum CaptionEffect {
  /// Soft single drop shadow under the text.
  shadow,

  /// Stack of blurred coloured shadows → neon halo.
  glow,

  /// Crisp dark stroke around each glyph (paintingStyle.stroke foreground).
  outline,

  /// No shadow or stroke — raw text only. Use when the pill alone carries
  /// legibility, or the user wants a minimal look.
  none,
}

/// Parse an effect id ('shadow' / 'glow' / 'outline' / 'none') back to the
/// enum. Returns null for empty / unknown strings so callers can fall back
/// to the preset default.
CaptionEffect? parseCaptionEffect(String raw) {
  switch (raw) {
    case 'shadow':
      return CaptionEffect.shadow;
    case 'glow':
      return CaptionEffect.glow;
    case 'outline':
      return CaptionEffect.outline;
    case 'none':
      return CaptionEffect.none;
    default:
      return null;
  }
}

/// String id of a [CaptionEffect] — what we serialise in the per-frame
/// override array.
String effectId(CaptionEffect e) => e.name;

/// Catalog of Google Font families the Font sheet exposes. Keeping this
/// short on purpose; adding a family runs a runtime network fetch the
/// first time it's rendered. Each entry picks a weight/feel that reads
/// well at caption size.
class CaptionFontOption {
  const CaptionFontOption(this.family, this.label);
  final String family;
  final String label;
}

const List<CaptionFontOption> kCaptionFontOptions = [
  CaptionFontOption('Manrope', 'Manrope'),
  CaptionFontOption('Fraunces', 'Fraunces'),
  CaptionFontOption('Bebas Neue', 'Bebas'),
  CaptionFontOption('Playfair Display', 'Playfair'),
  CaptionFontOption('Oswald', 'Oswald'),
  CaptionFontOption('Caveat', 'Caveat'),
];
