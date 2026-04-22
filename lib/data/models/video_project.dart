import 'badge_style.dart';
import 'caption_style.dart';
import 'motion_style.dart';
import 'export_format.dart';

/// Sentinel value for a text-only slide (no image/video asset).
const kTextSlide = '__text__';

/// Prefix for a before/after slide: '__ba__:leftPath|rightPath'
const kBeforeAfterPrefix = '__ba__:';

bool isBeforeAfterPath(String path) => path.startsWith(kBeforeAfterPrefix);

/// Decode a before/after path into [left, right].
List<String> decodeBeforeAfter(String path) {
  final raw = path.substring(kBeforeAfterPrefix.length);
  final sep = raw.indexOf('|');
  if (sep < 0) return [raw, raw];
  return [raw.substring(0, sep), raw.substring(sep + 1)];
}

class VideoProject {
  const VideoProject({
    required this.id,
    required this.assetPaths,
    this.motionStyleId       = MotionStyleId.slowZoom,
    this.frameCaptions       = const [],
    this.framePriceTags      = const [],
    this.frameMrpTags        = const [],
    this.frameOfferBadges    = const [],
    this.frameDurations      = const [],
    this.frameTextPositions  = const [],
    this.frameBadgeSizes     = const [],
    this.frameCaptionStyles      = const [],
    this.frameCaptionFonts       = const [],
    this.frameCaptionTextColors  = const [],
    this.frameCaptionPillColors  = const [],
    this.frameCaptionEffects     = const [],
    this.frameCaptionUppercase   = const [],
    this.frameCaptionRotations   = const [],
    this.frameOfferBadgeStyles     = const [],
    this.frameOfferBadgeFillColors = const [],
    this.frameOfferBadgeTextColors = const [],
    this.frameOfferBadgeAnims      = const [],
    this.musicTrackId,
    this.brandingEnabled     = false,
    this.brandingPresetId,
    this.exportFormat        = ExportFormat.vertical,
    // Phase 2 fields
    this.textAnimStyle       = 'none',
    this.qrData,
    this.qrEnabled           = false,
    this.qrPosition          = 'bottom_right',
    this.countdownText,
    this.countdownEnabled    = false,
    this.frameVoiceovers     = const [],
    this.frameBgRemoval      = const [],
    this.frameBgColor        = const [],
    required this.createdAt,
  });

  factory VideoProject.create({
    required String id,
    required List<String> assetPaths,
  }) =>
      VideoProject(
        id: id,
        assetPaths:         assetPaths,
        frameCaptions:      List.filled(assetPaths.length, ''),
        framePriceTags:     List.filled(assetPaths.length, ''),
        frameMrpTags:       List.filled(assetPaths.length, ''),
        frameOfferBadges:   List.filled(assetPaths.length, ''),
        frameDurations:     List.filled(assetPaths.length, 3),
        frameTextPositions: List.filled(assetPaths.length, 'bottom'),
        frameBadgeSizes:    List.filled(assetPaths.length, 'medium'),
        frameCaptionStyles:     List.filled(assetPaths.length, CaptionStyle.defaultStyleId),
        frameCaptionFonts:      List.filled(assetPaths.length, ''),
        frameCaptionTextColors: List.filled(assetPaths.length, 0),
        frameCaptionPillColors: List.filled(assetPaths.length, 0),
        frameCaptionEffects:    List.filled(assetPaths.length, ''),
        frameCaptionUppercase:  List.filled(assetPaths.length, false),
        frameCaptionRotations:  List.filled(assetPaths.length, 0),
        frameOfferBadgeStyles:     List.filled(assetPaths.length, BadgeStyle.defaultStyleId),
        frameOfferBadgeFillColors: List.filled(assetPaths.length, 0),
        frameOfferBadgeTextColors: List.filled(assetPaths.length, 0),
        frameOfferBadgeAnims:      List.filled(assetPaths.length, ''),
        frameVoiceovers:    List.filled(assetPaths.length, null),
        frameBgRemoval:     List.filled(assetPaths.length, false),
        frameBgColor:       List.filled(assetPaths.length, 0),
        createdAt: DateTime.now(),
      );

  // ── Serialization ────────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'assetPaths':         assetPaths,
        'motionStyleId':      motionStyleId.name,
        'frameCaptions':      frameCaptions,
        'framePriceTags':     framePriceTags,
        'frameMrpTags':       frameMrpTags,
        'frameOfferBadges':   frameOfferBadges,
        'frameDurations':     frameDurations,
        'frameTextPositions': frameTextPositions,
        'frameBadgeSizes':    frameBadgeSizes,
        'frameCaptionStyles':     frameCaptionStyles,
        'frameCaptionFonts':      frameCaptionFonts,
        'frameCaptionTextColors': frameCaptionTextColors,
        'frameCaptionPillColors': frameCaptionPillColors,
        'frameCaptionEffects':    frameCaptionEffects,
        'frameCaptionUppercase':  frameCaptionUppercase,
        'frameCaptionRotations':  frameCaptionRotations,
        'frameOfferBadgeStyles':     frameOfferBadgeStyles,
        'frameOfferBadgeFillColors': frameOfferBadgeFillColors,
        'frameOfferBadgeTextColors': frameOfferBadgeTextColors,
        'frameOfferBadgeAnims':      frameOfferBadgeAnims,
        'musicTrackId':       musicTrackId,
        'brandingEnabled':    brandingEnabled,
        'brandingPresetId':   brandingPresetId,
        'exportFormat':       exportFormat.name,
        'textAnimStyle':      textAnimStyle,
        'qrData':             qrData,
        'qrEnabled':          qrEnabled,
        'qrPosition':         qrPosition,
        'countdownText':      countdownText,
        'countdownEnabled':   countdownEnabled,
        'frameVoiceovers':    frameVoiceovers,
        'frameBgRemoval':     frameBgRemoval,
        'frameBgColor':       frameBgColor,
        'createdAt':          createdAt.millisecondsSinceEpoch,
      };

  factory VideoProject.fromJson(Map<String, dynamic> j) {
    List<String> strList(String key) =>
        (j[key] as List?)?.map((e) => e as String).toList() ?? [];
    List<int> intList(String key) =>
        (j[key] as List?)?.map((e) => (e as num).toInt()).toList() ?? [];

    return VideoProject(
      id:                 j['id'] as String,
      assetPaths:         strList('assetPaths'),
      motionStyleId:      MotionStyleId.values.firstWhere(
          (e) => e.name == j['motionStyleId'],
          orElse: () => MotionStyleId.slowZoom),
      frameCaptions:      strList('frameCaptions'),
      framePriceTags:     strList('framePriceTags'),
      frameMrpTags:       strList('frameMrpTags'),
      frameOfferBadges:   strList('frameOfferBadges'),
      frameDurations:     intList('frameDurations'),
      frameTextPositions: strList('frameTextPositions'),
      frameBadgeSizes:    strList('frameBadgeSizes'),
      frameCaptionStyles:     strList('frameCaptionStyles'),
      frameCaptionFonts:      strList('frameCaptionFonts'),
      frameCaptionTextColors: intList('frameCaptionTextColors'),
      frameCaptionPillColors: intList('frameCaptionPillColors'),
      frameCaptionEffects:    strList('frameCaptionEffects'),
      frameCaptionUppercase:  (j['frameCaptionUppercase'] as List?)
          ?.map((e) => e as bool).toList() ?? [],
      frameCaptionRotations:  intList('frameCaptionRotations'),
      frameOfferBadgeStyles:     strList('frameOfferBadgeStyles'),
      frameOfferBadgeFillColors: intList('frameOfferBadgeFillColors'),
      frameOfferBadgeTextColors: intList('frameOfferBadgeTextColors'),
      frameOfferBadgeAnims:      strList('frameOfferBadgeAnims'),
      musicTrackId:       j['musicTrackId'] as String?,
      brandingEnabled:    (j['brandingEnabled'] as bool?) ?? false,
      brandingPresetId:   j['brandingPresetId'] as String?,
      exportFormat:       ExportFormat.values.firstWhere(
          (e) => e.name == j['exportFormat'],
          orElse: () => ExportFormat.vertical),
      textAnimStyle:      (j['textAnimStyle'] as String?) ?? 'none',
      qrData:             j['qrData'] as String?,
      qrEnabled:          (j['qrEnabled'] as bool?) ?? false,
      qrPosition:         (j['qrPosition'] as String?) ?? 'bottom_right',
      countdownText:      j['countdownText'] as String?,
      countdownEnabled:   (j['countdownEnabled'] as bool?) ?? false,
      frameVoiceovers:    (j['frameVoiceovers'] as List?)
          ?.map((e) => e as String?)
          .toList() ?? [],
      frameBgRemoval:     (j['frameBgRemoval'] as List?)
          ?.map((e) => e as bool)
          .toList() ?? [],
      frameBgColor:       intList('frameBgColor'),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
          (j['createdAt'] as num?)?.toInt() ?? 0),
    );
  }

  // ── Fields ───────────────────────────────────────────────────────────────────

  final String id;
  final List<String> assetPaths;
  final MotionStyleId motionStyleId;

  final List<String> frameCaptions;
  final List<String> framePriceTags;
  final List<String> frameMrpTags;
  final List<String> frameOfferBadges;
  final List<int>    frameDurations;
  final List<String> frameTextPositions;
  final List<String> frameBadgeSizes;

  /// Per-frame caption style preset id (see `CaptionStyle.all`). Old drafts
  /// without this array default to [CaptionStyle.defaultStyleId] via the
  /// accessor [captionStyleIdFor].
  final List<String> frameCaptionStyles;

  /// Per-frame font family override. `''` = use the preset's own font.
  final List<String> frameCaptionFonts;

  /// Per-frame text colour override (ARGB int). `0` = use preset default.
  final List<int> frameCaptionTextColors;

  /// Per-frame pill colour override (ARGB int). `0` = use preset default
  /// (so if the preset has no pill, the frame still has none).
  final List<int> frameCaptionPillColors;

  /// Per-frame effect override. `''` = use preset default. Otherwise one of
  /// `'shadow'` / `'glow'` / `'outline'` / `'none'`.
  final List<String> frameCaptionEffects;

  /// Per-frame uppercase toggle — transforms the caption to ALL CAPS at
  /// render time without mutating the stored text.
  final List<bool> frameCaptionUppercase;

  /// Per-frame rotation applied to the caption pill+text, in degrees.
  /// Clamped at render/preview time to a gentle sticker range (±15°) so
  /// captions don't clip off the safe area.
  final List<int> frameCaptionRotations;

  /// Per-frame offer-badge style preset id (see `BadgeStyle.all`).
  /// Existing `frameOfferBadges` holds the label/text — the style controls
  /// shape, colours, and decoration.
  final List<String> frameOfferBadgeStyles;

  /// Per-frame badge fill colour override (ARGB int). 0 = preset default.
  final List<int> frameOfferBadgeFillColors;

  /// Per-frame badge text colour override (ARGB int). 0 = preset default.
  final List<int> frameOfferBadgeTextColors;

  /// Per-frame badge entrance animation id — `'none'` / `'pop'` /
  /// `'slide_in'` / `'rotate_in'` / `'pulse'`. Empty string falls back to
  /// `'none'`.
  final List<String> frameOfferBadgeAnims;

  final String? musicTrackId;
  final bool brandingEnabled;
  final String? brandingPresetId;
  final ExportFormat exportFormat;
  // Phase 2
  final String textAnimStyle;     // 'none' | 'fade' | 'slide_up'
  final String? qrData;
  final bool qrEnabled;
  final String qrPosition;        // 'bottom_right' | 'bottom_left' | 'top_right' | 'top_left'
  final String? countdownText;
  final bool countdownEnabled;
  final List<String?> frameVoiceovers;

  /// Per-frame flag: when true, the frame's photo gets its background removed
  /// via Google ML Kit Subject Segmentation before rendering. Falls back to
  /// the original image if segmentation fails. Has no effect on `kTextSlide`
  /// or before/after composite slides.
  final List<bool> frameBgRemoval;

  /// Per-frame replacement background colour (ARGB int) used when
  /// [frameBgRemoval] is true. `0` means "use brand ember" at render time.
  final List<int> frameBgColor;

  final DateTime createdAt;

  // ── copyWith ─────────────────────────────────────────────────────────────────

  VideoProject copyWith({
    List<String>?   assetPaths,
    MotionStyleId?  motionStyleId,
    List<String>?   frameCaptions,
    List<String>?   framePriceTags,
    List<String>?   frameMrpTags,
    List<String>?   frameOfferBadges,
    List<int>?      frameDurations,
    List<String>?   frameTextPositions,
    List<String>?   frameBadgeSizes,
    List<String>?   frameCaptionStyles,
    List<String>?   frameCaptionFonts,
    List<int>?      frameCaptionTextColors,
    List<int>?      frameCaptionPillColors,
    List<String>?   frameCaptionEffects,
    List<bool>?     frameCaptionUppercase,
    List<int>?      frameCaptionRotations,
    List<String>?   frameOfferBadgeStyles,
    List<int>?      frameOfferBadgeFillColors,
    List<int>?      frameOfferBadgeTextColors,
    List<String>?   frameOfferBadgeAnims,
    bool?           brandingEnabled,
    String?         brandingPresetId,
    ExportFormat?   exportFormat,
    String?         textAnimStyle,
    Object?         qrData = _sentinel,
    bool?           qrEnabled,
    String?         qrPosition,
    Object?         countdownText = _sentinel,
    bool?           countdownEnabled,
    List<String?>?  frameVoiceovers,
    List<bool>?     frameBgRemoval,
    List<int>?      frameBgColor,
  }) =>
      VideoProject(
        id: id,
        assetPaths:         assetPaths         ?? this.assetPaths,
        motionStyleId:      motionStyleId      ?? this.motionStyleId,
        frameCaptions:      frameCaptions      ?? this.frameCaptions,
        framePriceTags:     framePriceTags     ?? this.framePriceTags,
        frameMrpTags:       frameMrpTags       ?? this.frameMrpTags,
        frameOfferBadges:   frameOfferBadges   ?? this.frameOfferBadges,
        frameDurations:     frameDurations     ?? this.frameDurations,
        frameTextPositions: frameTextPositions ?? this.frameTextPositions,
        frameBadgeSizes:    frameBadgeSizes    ?? this.frameBadgeSizes,
        frameCaptionStyles:     frameCaptionStyles     ?? this.frameCaptionStyles,
        frameCaptionFonts:      frameCaptionFonts      ?? this.frameCaptionFonts,
        frameCaptionTextColors: frameCaptionTextColors ?? this.frameCaptionTextColors,
        frameCaptionPillColors: frameCaptionPillColors ?? this.frameCaptionPillColors,
        frameCaptionEffects:    frameCaptionEffects    ?? this.frameCaptionEffects,
        frameCaptionUppercase:  frameCaptionUppercase  ?? this.frameCaptionUppercase,
        frameCaptionRotations:  frameCaptionRotations  ?? this.frameCaptionRotations,
        frameOfferBadgeStyles:     frameOfferBadgeStyles     ?? this.frameOfferBadgeStyles,
        frameOfferBadgeFillColors: frameOfferBadgeFillColors ?? this.frameOfferBadgeFillColors,
        frameOfferBadgeTextColors: frameOfferBadgeTextColors ?? this.frameOfferBadgeTextColors,
        frameOfferBadgeAnims:      frameOfferBadgeAnims      ?? this.frameOfferBadgeAnims,
        frameVoiceovers:    frameVoiceovers    ?? this.frameVoiceovers,
        frameBgRemoval:     frameBgRemoval     ?? this.frameBgRemoval,
        frameBgColor:       frameBgColor       ?? this.frameBgColor,
        musicTrackId:       musicTrackId,
        brandingEnabled:    brandingEnabled    ?? this.brandingEnabled,
        brandingPresetId:   brandingPresetId   ?? this.brandingPresetId,
        exportFormat:       exportFormat       ?? this.exportFormat,
        textAnimStyle:      textAnimStyle      ?? this.textAnimStyle,
        qrData:             identical(qrData, _sentinel) ? this.qrData : qrData as String?,
        qrEnabled:          qrEnabled          ?? this.qrEnabled,
        qrPosition:         qrPosition         ?? this.qrPosition,
        countdownText:      identical(countdownText, _sentinel) ? this.countdownText : countdownText as String?,
        countdownEnabled:   countdownEnabled   ?? this.countdownEnabled,
        createdAt: createdAt,
      );

// Sentinel for distinguishing "not passed" from explicit null in copyWith
static const _sentinel = Object();

  VideoProject copyWithMusic(String? trackId) => VideoProject(
        id: id,
        assetPaths:         assetPaths,
        motionStyleId:      motionStyleId,
        frameCaptions:      frameCaptions,
        framePriceTags:     framePriceTags,
        frameMrpTags:       frameMrpTags,
        frameOfferBadges:   frameOfferBadges,
        frameDurations:     frameDurations,
        frameTextPositions: frameTextPositions,
        frameBadgeSizes:    frameBadgeSizes,
        frameCaptionStyles:     frameCaptionStyles,
        frameCaptionFonts:      frameCaptionFonts,
        frameCaptionTextColors: frameCaptionTextColors,
        frameCaptionPillColors: frameCaptionPillColors,
        frameCaptionEffects:    frameCaptionEffects,
        frameCaptionUppercase:  frameCaptionUppercase,
        frameCaptionRotations:  frameCaptionRotations,
        frameOfferBadgeStyles:     frameOfferBadgeStyles,
        frameOfferBadgeFillColors: frameOfferBadgeFillColors,
        frameOfferBadgeTextColors: frameOfferBadgeTextColors,
        frameOfferBadgeAnims:      frameOfferBadgeAnims,
        musicTrackId:       trackId,
        brandingEnabled:    brandingEnabled,
        brandingPresetId:   brandingPresetId,
        exportFormat:       exportFormat,
        textAnimStyle:      textAnimStyle,
        qrData:             qrData,
        qrEnabled:          qrEnabled,
        qrPosition:         qrPosition,
        countdownText:      countdownText,
        countdownEnabled:   countdownEnabled,
        frameVoiceovers:    frameVoiceovers,
        frameBgRemoval:     frameBgRemoval,
        frameBgColor:       frameBgColor,
        createdAt: createdAt,
      );

  // ── Per-frame mutations ───────────────────────────────────────────────────────

  VideoProject withFrameVoiceover(int i, String? path) {
    final list = List<String?>.from(
        frameVoiceovers.length >= assetPaths.length
            ? frameVoiceovers
            : [...frameVoiceovers, ...List.filled(assetPaths.length - frameVoiceovers.length, null)]);
    if (i >= 0 && i < list.length) list[i] = path;
    return copyWith(frameVoiceovers: list);
  }

  bool get hasAnyVoiceover => frameVoiceovers.any((v) => v != null);

  VideoProject withFrameCaption(int i, String v)      => _updateStr(frameCaptions,      i, v, (l) => copyWith(frameCaptions: l));
  VideoProject withFramePriceTag(int i, String v)     => _updateStr(framePriceTags,     i, v, (l) => copyWith(framePriceTags: l));
  VideoProject withFrameMrpTag(int i, String v)       => _updateStr(frameMrpTags,       i, v, (l) => copyWith(frameMrpTags: l));
  VideoProject withFrameOfferBadge(int i, String v)   => _updateStr(frameOfferBadges,   i, v, (l) => copyWith(frameOfferBadges: l));
  VideoProject withFrameTextPosition(int i, String v) => _updateStr(frameTextPositions, i, v, (l) => copyWith(frameTextPositions: l));
  VideoProject withFrameBadgeSize(int i, String v)    => _updateStr(frameBadgeSizes,    i, v, (l) => copyWith(frameBadgeSizes: l));
  VideoProject withFrameCaptionStyle(int i, String v) {
    final list = List<String>.from(_padCaptionStyles(assetPaths.length));
    if (i >= 0 && i < list.length) list[i] = v;
    return copyWith(frameCaptionStyles: list);
  }

  /// Safe accessor — returns the configured style id for frame [i], or the
  /// default for frames past the end of the array (older drafts).
  String captionStyleIdFor(int i) => i >= 0 && i < frameCaptionStyles.length
      ? frameCaptionStyles[i]
      : CaptionStyle.defaultStyleId;

  String captionFontOverrideFor(int i) =>
      i >= 0 && i < frameCaptionFonts.length ? frameCaptionFonts[i] : '';
  int captionTextColorOverrideFor(int i) => i >= 0 &&
          i < frameCaptionTextColors.length
      ? frameCaptionTextColors[i]
      : 0;
  int captionPillColorOverrideFor(int i) => i >= 0 &&
          i < frameCaptionPillColors.length
      ? frameCaptionPillColors[i]
      : 0;
  String captionEffectOverrideFor(int i) =>
      i >= 0 && i < frameCaptionEffects.length
          ? frameCaptionEffects[i]
          : '';
  bool captionUppercaseFor(int i) =>
      i >= 0 && i < frameCaptionUppercase.length && frameCaptionUppercase[i];

  int captionRotationFor(int i) {
    final raw = i >= 0 && i < frameCaptionRotations.length
        ? frameCaptionRotations[i]
        : 0;
    return raw.clamp(-15, 15);
  }

  String offerBadgeStyleIdFor(int i) =>
      i >= 0 && i < frameOfferBadgeStyles.length
          ? frameOfferBadgeStyles[i]
          : BadgeStyle.defaultStyleId;
  int offerBadgeFillColorOverrideFor(int i) =>
      i >= 0 && i < frameOfferBadgeFillColors.length
          ? frameOfferBadgeFillColors[i]
          : 0;
  int offerBadgeTextColorOverrideFor(int i) =>
      i >= 0 && i < frameOfferBadgeTextColors.length
          ? frameOfferBadgeTextColors[i]
          : 0;
  String offerBadgeAnimFor(int i) =>
      i >= 0 && i < frameOfferBadgeAnims.length
          ? frameOfferBadgeAnims[i]
          : '';

  /// The effective [BadgeStyle] for frame [i] — preset + per-frame
  /// fill/text colour overrides merged in. Used by both the preview and
  /// the PNG renderer.
  BadgeStyle resolvedOfferBadgeStyleFor(int i) {
    return BadgeStyle.byId(offerBadgeStyleIdFor(i)).withOverrides(
      fillOverride: offerBadgeFillColorOverrideFor(i),
      textOverride: offerBadgeTextColorOverrideFor(i),
    );
  }

  /// The effective [CaptionStyle] for frame [i]: the preset with any
  /// per-frame font / colour / effect overrides layered on top. Used by
  /// both the live preview and the PNG renderer so they stay aligned.
  CaptionStyle resolvedCaptionStyleFor(int i) {
    final preset = CaptionStyle.byId(captionStyleIdFor(i));
    final fontOverride = captionFontOverrideFor(i);
    final effectOverride = parseCaptionEffect(captionEffectOverrideFor(i));
    return preset.withOverrides(
      fontFamilyOverride: fontOverride.isEmpty ? null : fontOverride,
      textColorOverride: captionTextColorOverrideFor(i),
      pillColorOverride: captionPillColorOverrideFor(i),
      effectOverride: effectOverride,
    );
  }

  VideoProject withFrameCaptionFont(int i, String family) {
    final list = List<String>.from(_padFrameList(
        frameCaptionFonts, assetPaths.length, ''));
    if (i >= 0 && i < list.length) list[i] = family;
    return copyWith(frameCaptionFonts: list);
  }

  VideoProject withFrameCaptionTextColor(int i, int argb) {
    final list = List<int>.from(_padFrameList(
        frameCaptionTextColors, assetPaths.length, 0));
    if (i >= 0 && i < list.length) list[i] = argb;
    return copyWith(frameCaptionTextColors: list);
  }

  VideoProject withFrameCaptionPillColor(int i, int argb) {
    final list = List<int>.from(_padFrameList(
        frameCaptionPillColors, assetPaths.length, 0));
    if (i >= 0 && i < list.length) list[i] = argb;
    return copyWith(frameCaptionPillColors: list);
  }

  VideoProject withFrameCaptionEffect(int i, String effect) {
    final list = List<String>.from(_padFrameList(
        frameCaptionEffects, assetPaths.length, ''));
    if (i >= 0 && i < list.length) list[i] = effect;
    return copyWith(frameCaptionEffects: list);
  }

  VideoProject withFrameCaptionUppercase(int i, bool value) {
    final list = List<bool>.from(_padFrameList(
        frameCaptionUppercase, assetPaths.length, false));
    if (i >= 0 && i < list.length) list[i] = value;
    return copyWith(frameCaptionUppercase: list);
  }

  VideoProject withFrameCaptionRotation(int i, int degrees) {
    final list = List<int>.from(_padFrameList(
        frameCaptionRotations, assetPaths.length, 0));
    if (i >= 0 && i < list.length) list[i] = degrees.clamp(-15, 15);
    return copyWith(frameCaptionRotations: list);
  }

  VideoProject withFrameOfferBadgeStyle(int i, String styleId) {
    final list = List<String>.from(_padFrameList(
        frameOfferBadgeStyles, assetPaths.length, BadgeStyle.defaultStyleId));
    if (i >= 0 && i < list.length) list[i] = styleId;
    return copyWith(frameOfferBadgeStyles: list);
  }

  VideoProject withFrameOfferBadgeFillColor(int i, int argb) {
    final list = List<int>.from(_padFrameList(
        frameOfferBadgeFillColors, assetPaths.length, 0));
    if (i >= 0 && i < list.length) list[i] = argb;
    return copyWith(frameOfferBadgeFillColors: list);
  }

  VideoProject withFrameOfferBadgeTextColor(int i, int argb) {
    final list = List<int>.from(_padFrameList(
        frameOfferBadgeTextColors, assetPaths.length, 0));
    if (i >= 0 && i < list.length) list[i] = argb;
    return copyWith(frameOfferBadgeTextColors: list);
  }

  VideoProject withFrameOfferBadgeAnim(int i, String anim) {
    final list = List<String>.from(_padFrameList(
        frameOfferBadgeAnims, assetPaths.length, ''));
    if (i >= 0 && i < list.length) list[i] = anim;
    return copyWith(frameOfferBadgeAnims: list);
  }

  /// Pad any per-frame list out to [targetLen], back-filling with [fallback].
  /// Used by the new override arrays so old drafts don't need a migration
  /// step — accessors + setters both transparently extend the list.
  static List<T> _padFrameList<T>(List<T> src, int targetLen, T fallback) {
    if (src.length >= targetLen) return src;
    return [...src, ...List.filled(targetLen - src.length, fallback)];
  }

  VideoProject withFrameDuration(int i, int v) {
    final list = List<int>.from(frameDurations);
    if (i >= 0 && i < list.length) list[i] = v;
    return copyWith(frameDurations: list);
  }

  VideoProject withFrameBgRemoval(int i, bool v) {
    final list = List<bool>.from(_padBgRemoval(assetPaths.length));
    if (i >= 0 && i < list.length) list[i] = v;
    return copyWith(frameBgRemoval: list);
  }

  VideoProject withFrameBgColor(int i, int argb) {
    final list = List<int>.from(_padBgColor(assetPaths.length));
    if (i >= 0 && i < list.length) list[i] = argb;
    return copyWith(frameBgColor: list);
  }

  bool bgRemovalFor(int i) =>
      i >= 0 && i < frameBgRemoval.length && frameBgRemoval[i];

  int bgColorFor(int i) =>
      i >= 0 && i < frameBgColor.length ? frameBgColor[i] : 0;

  VideoProject _updateStr(List<String> src, int i, String v,
      VideoProject Function(List<String>) apply) {
    final list = List<String>.from(src);
    if (i >= 0 && i < list.length) list[i] = v;
    return apply(list);
  }

  // ── Internal helper — carries all scalar fields through structural mutations ──

  VideoProject _rebuild({
    required List<String>  assetPaths,
    required List<String>  frameCaptions,
    required List<String>  framePriceTags,
    required List<String>  frameMrpTags,
    required List<String>  frameOfferBadges,
    required List<int>     frameDurations,
    required List<String>  frameTextPositions,
    required List<String>  frameBadgeSizes,
    required List<String>  frameCaptionStyles,
    required List<String>  frameCaptionFonts,
    required List<int>     frameCaptionTextColors,
    required List<int>     frameCaptionPillColors,
    required List<String>  frameCaptionEffects,
    required List<bool>    frameCaptionUppercase,
    required List<int>     frameCaptionRotations,
    required List<String>  frameOfferBadgeStyles,
    required List<int>     frameOfferBadgeFillColors,
    required List<int>     frameOfferBadgeTextColors,
    required List<String>  frameOfferBadgeAnims,
    required List<String?> frameVoiceovers,
    required List<bool>    frameBgRemoval,
    required List<int>     frameBgColor,
  }) => VideoProject(
    id: id,
    assetPaths:         assetPaths,
    motionStyleId:      motionStyleId,
    frameCaptions:      frameCaptions,
    framePriceTags:     framePriceTags,
    frameMrpTags:       frameMrpTags,
    frameOfferBadges:   frameOfferBadges,
    frameDurations:     frameDurations,
    frameTextPositions: frameTextPositions,
    frameBadgeSizes:    frameBadgeSizes,
    frameCaptionStyles:     frameCaptionStyles,
    frameCaptionFonts:      frameCaptionFonts,
    frameCaptionTextColors: frameCaptionTextColors,
    frameCaptionPillColors: frameCaptionPillColors,
    frameCaptionEffects:    frameCaptionEffects,
    frameCaptionUppercase:  frameCaptionUppercase,
    frameCaptionRotations:  frameCaptionRotations,
    frameOfferBadgeStyles:     frameOfferBadgeStyles,
    frameOfferBadgeFillColors: frameOfferBadgeFillColors,
    frameOfferBadgeTextColors: frameOfferBadgeTextColors,
    frameOfferBadgeAnims:      frameOfferBadgeAnims,
    frameVoiceovers:    frameVoiceovers,
    frameBgRemoval:     frameBgRemoval,
    frameBgColor:       frameBgColor,
    musicTrackId:       musicTrackId,
    brandingEnabled:    brandingEnabled,
    brandingPresetId:   brandingPresetId,
    exportFormat:       exportFormat,
    textAnimStyle:      textAnimStyle,
    qrData:             qrData,
    qrEnabled:          qrEnabled,
    qrPosition:         qrPosition,
    countdownText:      countdownText,
    countdownEnabled:   countdownEnabled,
    createdAt:          createdAt,
  );

  // ── Structural mutations ──────────────────────────────────────────────────────

  List<String?> _padVoiceovers(int targetLen) {
    if (frameVoiceovers.length >= targetLen) return frameVoiceovers;
    return [...frameVoiceovers, ...List.filled(targetLen - frameVoiceovers.length, null)];
  }

  List<bool> _padBgRemoval(int targetLen) {
    if (frameBgRemoval.length >= targetLen) return frameBgRemoval;
    return [...frameBgRemoval, ...List.filled(targetLen - frameBgRemoval.length, false)];
  }

  List<int> _padBgColor(int targetLen) {
    if (frameBgColor.length >= targetLen) return frameBgColor;
    return [...frameBgColor, ...List.filled(targetLen - frameBgColor.length, 0)];
  }

  List<String> _padCaptionStyles(int targetLen) {
    if (frameCaptionStyles.length >= targetLen) return frameCaptionStyles;
    return [
      ...frameCaptionStyles,
      ...List.filled(
          targetLen - frameCaptionStyles.length, CaptionStyle.defaultStyleId),
    ];
  }

  VideoProject removeFrame(int index) {
    List<T> without<T>(List<T> src) {
      final list = List<T>.from(src);
      if (index >= 0 && index < list.length) list.removeAt(index);
      return list;
    }
    return _rebuild(
      assetPaths:         without(assetPaths),
      frameCaptions:      without(frameCaptions),
      framePriceTags:     without(framePriceTags),
      frameMrpTags:       without(frameMrpTags),
      frameOfferBadges:   without(frameOfferBadges),
      frameDurations:     without(frameDurations),
      frameTextPositions: without(frameTextPositions),
      frameBadgeSizes:    without(frameBadgeSizes),
      frameCaptionStyles:     without(_padCaptionStyles(assetPaths.length)),
      frameCaptionFonts:      without(_padFrameList(frameCaptionFonts, assetPaths.length, '')),
      frameCaptionTextColors: without(_padFrameList(frameCaptionTextColors, assetPaths.length, 0)),
      frameCaptionPillColors: without(_padFrameList(frameCaptionPillColors, assetPaths.length, 0)),
      frameCaptionEffects:    without(_padFrameList(frameCaptionEffects, assetPaths.length, '')),
      frameCaptionUppercase:  without(_padFrameList(frameCaptionUppercase, assetPaths.length, false)),
      frameCaptionRotations:  without(_padFrameList(frameCaptionRotations, assetPaths.length, 0)),
      frameOfferBadgeStyles:     without(_padFrameList(frameOfferBadgeStyles, assetPaths.length, BadgeStyle.defaultStyleId)),
      frameOfferBadgeFillColors: without(_padFrameList(frameOfferBadgeFillColors, assetPaths.length, 0)),
      frameOfferBadgeTextColors: without(_padFrameList(frameOfferBadgeTextColors, assetPaths.length, 0)),
      frameOfferBadgeAnims:      without(_padFrameList(frameOfferBadgeAnims, assetPaths.length, '')),
      frameVoiceovers:    without(_padVoiceovers(assetPaths.length)),
      frameBgRemoval:     without(_padBgRemoval(assetPaths.length)),
      frameBgColor:       without(_padBgColor(assetPaths.length)),
    );
  }

  VideoProject duplicateFrame(int index) {
    List<T> dup<T>(List<T> src, T fallback) {
      final list = List<T>.from(src);
      final item = index >= 0 && index < list.length ? list[index] : fallback;
      list.insert(index + 1, item);
      return list;
    }
    return _rebuild(
      assetPaths:         dup(assetPaths,                   ''),
      frameCaptions:      dup(frameCaptions,                ''),
      framePriceTags:     dup(framePriceTags,               ''),
      frameMrpTags:       dup(frameMrpTags,                 ''),
      frameOfferBadges:   dup(frameOfferBadges,             ''),
      frameDurations:     dup(frameDurations,                3),
      frameTextPositions: dup(frameTextPositions,       'bottom'),
      frameBadgeSizes:    dup(frameBadgeSizes,          'medium'),
      frameCaptionStyles:     dup(_padCaptionStyles(assetPaths.length),
          CaptionStyle.defaultStyleId),
      frameCaptionFonts:      dup(_padFrameList(frameCaptionFonts, assetPaths.length, ''), ''),
      frameCaptionTextColors: dup(_padFrameList(frameCaptionTextColors, assetPaths.length, 0), 0),
      frameCaptionPillColors: dup(_padFrameList(frameCaptionPillColors, assetPaths.length, 0), 0),
      frameCaptionEffects:    dup(_padFrameList(frameCaptionEffects, assetPaths.length, ''), ''),
      frameCaptionUppercase:  dup(_padFrameList(frameCaptionUppercase, assetPaths.length, false), false),
      frameCaptionRotations:  dup(_padFrameList(frameCaptionRotations, assetPaths.length, 0), 0),
      frameOfferBadgeStyles:     dup(_padFrameList(frameOfferBadgeStyles, assetPaths.length, BadgeStyle.defaultStyleId), BadgeStyle.defaultStyleId),
      frameOfferBadgeFillColors: dup(_padFrameList(frameOfferBadgeFillColors, assetPaths.length, 0), 0),
      frameOfferBadgeTextColors: dup(_padFrameList(frameOfferBadgeTextColors, assetPaths.length, 0), 0),
      frameOfferBadgeAnims:      dup(_padFrameList(frameOfferBadgeAnims, assetPaths.length, ''), ''),
      frameVoiceovers:    dup(_padVoiceovers(assetPaths.length), null),
      frameBgRemoval:     dup(_padBgRemoval(assetPaths.length), false),
      frameBgColor:       dup(_padBgColor(assetPaths.length), 0),
    );
  }

  VideoProject _insertSlide(String path, {int? afterIndex,
      String textPosition = 'bottom'}) {
    final idx = afterIndex != null ? afterIndex + 1 : assetPaths.length;
    List<T> ins<T>(List<T> src, T value) {
      final list = List<T>.from(src);
      list.insert(idx.clamp(0, list.length), value);
      return list;
    }
    final padded = _padVoiceovers(assetPaths.length);
    return _rebuild(
      assetPaths:         ins(assetPaths,         path),
      frameCaptions:      ins(frameCaptions,      ''),
      framePriceTags:     ins(framePriceTags,     ''),
      frameMrpTags:       ins(frameMrpTags,       ''),
      frameOfferBadges:   ins(frameOfferBadges,   ''),
      frameDurations:     ins(frameDurations,      3),
      frameTextPositions: ins(frameTextPositions, textPosition),
      frameBadgeSizes:    ins(frameBadgeSizes,    'medium'),
      frameCaptionStyles:     ins(_padCaptionStyles(assetPaths.length),
          CaptionStyle.defaultStyleId),
      frameCaptionFonts:      ins(_padFrameList(frameCaptionFonts, assetPaths.length, ''), ''),
      frameCaptionTextColors: ins(_padFrameList(frameCaptionTextColors, assetPaths.length, 0), 0),
      frameCaptionPillColors: ins(_padFrameList(frameCaptionPillColors, assetPaths.length, 0), 0),
      frameCaptionEffects:    ins(_padFrameList(frameCaptionEffects, assetPaths.length, ''), ''),
      frameCaptionUppercase:  ins(_padFrameList(frameCaptionUppercase, assetPaths.length, false), false),
      frameCaptionRotations:  ins(_padFrameList(frameCaptionRotations, assetPaths.length, 0), 0),
      frameOfferBadgeStyles:     ins(_padFrameList(frameOfferBadgeStyles, assetPaths.length, BadgeStyle.defaultStyleId), BadgeStyle.defaultStyleId),
      frameOfferBadgeFillColors: ins(_padFrameList(frameOfferBadgeFillColors, assetPaths.length, 0), 0),
      frameOfferBadgeTextColors: ins(_padFrameList(frameOfferBadgeTextColors, assetPaths.length, 0), 0),
      frameOfferBadgeAnims:      ins(_padFrameList(frameOfferBadgeAnims, assetPaths.length, ''), ''),
      frameVoiceovers:    ins(padded,              null),
      frameBgRemoval:     ins(_padBgRemoval(assetPaths.length), false),
      frameBgColor:       ins(_padBgColor(assetPaths.length), 0),
    );
  }

  VideoProject insertTextSlide({int? afterIndex}) =>
      _insertSlide(kTextSlide, afterIndex: afterIndex, textPosition: 'center');

  VideoProject insertBeforeAfterSlide(String leftPath, String rightPath,
          {int? afterIndex}) =>
      _insertSlide('$kBeforeAfterPrefix$leftPath|$rightPath',
          afterIndex: afterIndex);

  VideoProject reorderFrames(int oldIndex, int newIndex) {
    List<T> moved<T>(List<T> src) {
      final list = List<T>.from(src);
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);
      return list;
    }
    return _rebuild(
      assetPaths:         moved(assetPaths),
      frameCaptions:      moved(frameCaptions),
      framePriceTags:     moved(framePriceTags),
      frameMrpTags:       moved(frameMrpTags),
      frameOfferBadges:   moved(frameOfferBadges),
      frameDurations:     moved(frameDurations),
      frameTextPositions: moved(frameTextPositions),
      frameBadgeSizes:    moved(frameBadgeSizes),
      frameCaptionStyles:     moved(_padCaptionStyles(assetPaths.length)),
      frameCaptionFonts:      moved(_padFrameList(frameCaptionFonts, assetPaths.length, '')),
      frameCaptionTextColors: moved(_padFrameList(frameCaptionTextColors, assetPaths.length, 0)),
      frameCaptionPillColors: moved(_padFrameList(frameCaptionPillColors, assetPaths.length, 0)),
      frameCaptionEffects:    moved(_padFrameList(frameCaptionEffects, assetPaths.length, '')),
      frameCaptionUppercase:  moved(_padFrameList(frameCaptionUppercase, assetPaths.length, false)),
      frameCaptionRotations:  moved(_padFrameList(frameCaptionRotations, assetPaths.length, 0)),
      frameOfferBadgeStyles:     moved(_padFrameList(frameOfferBadgeStyles, assetPaths.length, BadgeStyle.defaultStyleId)),
      frameOfferBadgeFillColors: moved(_padFrameList(frameOfferBadgeFillColors, assetPaths.length, 0)),
      frameOfferBadgeTextColors: moved(_padFrameList(frameOfferBadgeTextColors, assetPaths.length, 0)),
      frameOfferBadgeAnims:      moved(_padFrameList(frameOfferBadgeAnims, assetPaths.length, '')),
      frameVoiceovers:    moved(_padVoiceovers(assetPaths.length)),
      frameBgRemoval:     moved(_padBgRemoval(assetPaths.length)),
      frameBgColor:       moved(_padBgColor(assetPaths.length)),
    );
  }

  VideoProject applyTemplate({required String badge, required int duration}) =>
      copyWith(
        frameOfferBadges: List.filled(assetPaths.length, badge),
        frameDurations:   List.filled(assetPaths.length, duration),
      );
}
