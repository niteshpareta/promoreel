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
