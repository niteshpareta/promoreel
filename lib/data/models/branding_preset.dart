/// Identifier for one of the four strip layout presets. Drives both the
/// compositor (PNG render) and the in-editor WYSIWYG preview, so what
/// the user sees and what they export stay aligned.
///
/// - `classic`: original layout (dark bar, accent line, logo left, name + phone right)
/// - `modernMinimal`: translucent bar, hairline accent, smaller type, logo-first
/// - `boldRibbon`: full-bleed accent-coloured ribbon, large business name, light logo pill
/// - `sideBadge`: compact rounded pill anchored to one side instead of a full-width strip
class BrandingStyleId {
  static const classic = 'classic';
  static const modernMinimal = 'modernMinimal';
  static const boldRibbon = 'boldRibbon';
  static const sideBadge = 'sideBadge';

  static const all = [classic, modernMinimal, boldRibbon, sideBadge];

  static String labelOf(String id) {
    switch (id) {
      case modernMinimal:
        return 'Modern';
      case boldRibbon:
        return 'Bold';
      case sideBadge:
        return 'Side Badge';
      case classic:
      default:
        return 'Classic';
    }
  }
}

class BrandingPreset {
  const BrandingPreset({
    required this.id,
    required this.name,
    this.businessName = '',
    this.phoneNumber = '',
    this.address = '',
    this.logoPath,
    this.tagline = '',
    this.website = '',
    this.socialHandle = '',
    this.primaryColorArgb = 0,
    this.accentColorArgb = 0,
    this.styleId = BrandingStyleId.classic,
    this.stripPosition = 'bottom', // 'bottom' | 'top'
    this.showIntro = false,
    this.showOutro = false,
    this.introDuration = 1.5,
    this.outroDuration = 1.5,
  });

  final String id;
  final String name;
  final String businessName;
  final String phoneNumber;
  final String address;
  final String? logoPath;

  /// One-line tagline shown on intro / outro cards ("Since 1998" / "Book
  /// now — 20% off"). Not rendered on the strip.
  final String tagline;

  /// Website URL. Rendered on intro/outro cards when non-empty.
  final String website;

  /// Social handle (e.g. "@brandname"). Rendered on intro/outro cards.
  final String socialHandle;

  /// Primary brand colour, ARGB int. `0` = use brand ember default.
  /// Drives the strip accent, intro/outro backgrounds, and (in future
  /// passes) caption emphasis.
  final int primaryColorArgb;

  /// Accent brand colour, ARGB int. `0` = use purple default. Drives
  /// decorative elements in the modern/bold strip presets.
  final int accentColorArgb;

  /// Which strip preset to render. See [BrandingStyleId].
  final String styleId;

  /// `'bottom'` (default) or `'top'`. The compositor renders the same
  /// strip either way — position is applied in the encoder overlay.
  final String stripPosition;

  /// Prepend a full-frame brand card at the start of the video.
  final bool showIntro;

  /// Append a full-frame brand card at the end of the video.
  final bool showOutro;

  /// Intro card duration in seconds.
  final double introDuration;

  /// Outro card duration in seconds.
  final double outroDuration;

  BrandingPreset copyWith({
    String? name,
    String? businessName,
    String? phoneNumber,
    String? address,
    Object? logoPath = _sentinel,
    String? tagline,
    String? website,
    String? socialHandle,
    int? primaryColorArgb,
    int? accentColorArgb,
    String? styleId,
    String? stripPosition,
    bool? showIntro,
    bool? showOutro,
    double? introDuration,
    double? outroDuration,
  }) {
    return BrandingPreset(
      id: id,
      name: name ?? this.name,
      businessName: businessName ?? this.businessName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      logoPath:
          identical(logoPath, _sentinel) ? this.logoPath : logoPath as String?,
      tagline: tagline ?? this.tagline,
      website: website ?? this.website,
      socialHandle: socialHandle ?? this.socialHandle,
      primaryColorArgb: primaryColorArgb ?? this.primaryColorArgb,
      accentColorArgb: accentColorArgb ?? this.accentColorArgb,
      styleId: styleId ?? this.styleId,
      stripPosition: stripPosition ?? this.stripPosition,
      showIntro: showIntro ?? this.showIntro,
      showOutro: showOutro ?? this.showOutro,
      introDuration: introDuration ?? this.introDuration,
      outroDuration: outroDuration ?? this.outroDuration,
    );
  }

  static const _sentinel = Object();
}
