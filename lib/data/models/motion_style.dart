enum MotionStyleFamily { subtle, energetic, informational }

enum MotionStyleId {
  /// No camera motion, short neutral fade between slides. Default for new
  /// projects — users opt in to flashier looks instead of getting one by
  /// surprise. Applies to stills; videos always bypass camera motion
  /// regardless of the selected style.
  none,
  slowZoom,
  kenBurnsPan,
  softCrossfade,
  elegantSlide,
  quickCutBeatSync,
  boldSlide,
  flashReveal,
  gridPop,
  splitScreenInfo,
  bottomThirdHighlight,
  progressiveReveal,
  captionStack,

  // Expansion pack — all map to FFmpeg's built-in `xfade` transition
  // types (no new shader code required). Organised roughly from
  // "subtle" wipes up to "informational" covers / reveals.
  wipeUp,
  wipeDown,
  wipeTL,
  wipeTR,
  wipeBL,
  wipeBR,
  circleClose,
  rectCrop,
  coverLeft,
  coverRight,
  coverUp,
  coverDown,
  revealLeft,
  revealRight,
  pixelize,
  hBlur,
  fadeBlack,
  fadeGrays,
  smoothLeft,
  smoothRight,
}

class MotionStyle {
  const MotionStyle({
    required this.id,
    required this.family,
    required this.nameEn,
    required this.nameHi,
    required this.isPro,
    required this.lottieAsset,
    required this.previewThumbnail,
  });

  final MotionStyleId id;
  final MotionStyleFamily family;
  final String nameEn;
  final String nameHi;
  final bool isPro;
  final String lottieAsset;
  final String previewThumbnail;

  static const all = [
    // Default — no camera motion, short neutral fade. Always free.
    MotionStyle(id: MotionStyleId.none, family: MotionStyleFamily.subtle, nameEn: 'None', nameHi: 'कोई नहीं', isPro: false, lottieAsset: '', previewThumbnail: ''),

    // Subtle family — free: first 2, pro: last 2
    MotionStyle(id: MotionStyleId.slowZoom, family: MotionStyleFamily.subtle, nameEn: 'Slow Zoom', nameHi: 'धीमा ज़ूम', isPro: false, lottieAsset: 'assets/motion_styles/slow_zoom.json', previewThumbnail: 'assets/motion_styles/previews/slow_zoom.webp'),
    MotionStyle(id: MotionStyleId.kenBurnsPan, family: MotionStyleFamily.subtle, nameEn: 'Ken Burns', nameHi: 'केन बर्न्स', isPro: false, lottieAsset: 'assets/motion_styles/ken_burns.json', previewThumbnail: 'assets/motion_styles/previews/ken_burns.webp'),
    MotionStyle(id: MotionStyleId.softCrossfade, family: MotionStyleFamily.subtle, nameEn: 'Soft Fade', nameHi: 'सॉफ्ट फेड', isPro: true, lottieAsset: 'assets/motion_styles/soft_crossfade.json', previewThumbnail: 'assets/motion_styles/previews/soft_crossfade.webp'),
    MotionStyle(id: MotionStyleId.elegantSlide, family: MotionStyleFamily.subtle, nameEn: 'Elegant Slide', nameHi: 'एलीगेंट स्लाइड', isPro: true, lottieAsset: 'assets/motion_styles/elegant_slide.json', previewThumbnail: 'assets/motion_styles/previews/elegant_slide.webp'),

    // Energetic family — free: first 2, pro: last 2
    MotionStyle(id: MotionStyleId.quickCutBeatSync, family: MotionStyleFamily.energetic, nameEn: 'Beat Sync', nameHi: 'बीट सिंक', isPro: false, lottieAsset: 'assets/motion_styles/beat_sync.json', previewThumbnail: 'assets/motion_styles/previews/beat_sync.webp'),
    MotionStyle(id: MotionStyleId.boldSlide, family: MotionStyleFamily.energetic, nameEn: 'Bold Slide', nameHi: 'बोल्ड स्लाइड', isPro: false, lottieAsset: 'assets/motion_styles/bold_slide.json', previewThumbnail: 'assets/motion_styles/previews/bold_slide.webp'),
    MotionStyle(id: MotionStyleId.flashReveal, family: MotionStyleFamily.energetic, nameEn: 'Flash Reveal', nameHi: 'फ्लैश रिवील', isPro: true, lottieAsset: 'assets/motion_styles/flash_reveal.json', previewThumbnail: 'assets/motion_styles/previews/flash_reveal.webp'),
    MotionStyle(id: MotionStyleId.gridPop, family: MotionStyleFamily.energetic, nameEn: 'Grid Pop', nameHi: 'ग्रिड पॉप', isPro: true, lottieAsset: 'assets/motion_styles/grid_pop.json', previewThumbnail: 'assets/motion_styles/previews/grid_pop.webp'),

    // Informational family — all pro
    MotionStyle(id: MotionStyleId.splitScreenInfo, family: MotionStyleFamily.informational, nameEn: 'Split Screen', nameHi: 'स्प्लिट स्क्रीन', isPro: true, lottieAsset: 'assets/motion_styles/split_screen.json', previewThumbnail: 'assets/motion_styles/previews/split_screen.webp'),
    MotionStyle(id: MotionStyleId.bottomThirdHighlight, family: MotionStyleFamily.informational, nameEn: 'Bottom Highlight', nameHi: 'बॉटम हाइलाइट', isPro: true, lottieAsset: 'assets/motion_styles/bottom_third.json', previewThumbnail: 'assets/motion_styles/previews/bottom_third.webp'),
    MotionStyle(id: MotionStyleId.progressiveReveal, family: MotionStyleFamily.informational, nameEn: 'Progressive', nameHi: 'प्रोग्रेसिव', isPro: true, lottieAsset: 'assets/motion_styles/progressive.json', previewThumbnail: 'assets/motion_styles/previews/progressive.webp'),
    MotionStyle(id: MotionStyleId.captionStack, family: MotionStyleFamily.informational, nameEn: 'Caption Stack', nameHi: 'कैप्शन स्टैक', isPro: true, lottieAsset: 'assets/motion_styles/caption_stack.json', previewThumbnail: 'assets/motion_styles/previews/caption_stack.webp'),

    // ── Expansion pack (20 extra xfade transitions) ──────────────────────
    // Subtle family — free, calmer wipes
    MotionStyle(id: MotionStyleId.wipeUp,       family: MotionStyleFamily.subtle, nameEn: 'Wipe Up',       nameHi: 'विपे अप',      isPro: false, lottieAsset: '', previewThumbnail: ''),
    MotionStyle(id: MotionStyleId.wipeDown,     family: MotionStyleFamily.subtle, nameEn: 'Wipe Down',     nameHi: 'विपे डाउन',    isPro: false, lottieAsset: '', previewThumbnail: ''),
    MotionStyle(id: MotionStyleId.smoothLeft,   family: MotionStyleFamily.subtle, nameEn: 'Smooth Left',   nameHi: 'स्मूद लेफ्ट',  isPro: true,  lottieAsset: '', previewThumbnail: ''),
    MotionStyle(id: MotionStyleId.smoothRight,  family: MotionStyleFamily.subtle, nameEn: 'Smooth Right',  nameHi: 'स्मूद राइट',   isPro: true,  lottieAsset: '', previewThumbnail: ''),

    // Energetic family — more dramatic effects
    MotionStyle(id: MotionStyleId.circleClose, family: MotionStyleFamily.energetic, nameEn: 'Circle In',  nameHi: 'सर्कल इन',    isPro: false, lottieAsset: '', previewThumbnail: ''),
    MotionStyle(id: MotionStyleId.fadeBlack,   family: MotionStyleFamily.energetic, nameEn: 'Fade Black', nameHi: 'ब्लैक फेड',   isPro: false, lottieAsset: '', previewThumbnail: ''),
    MotionStyle(id: MotionStyleId.fadeGrays,   family: MotionStyleFamily.energetic, nameEn: 'Grayscale',  nameHi: 'ग्रेस्केल',   isPro: true,  lottieAsset: '', previewThumbnail: ''),
    MotionStyle(id: MotionStyleId.pixelize,    family: MotionStyleFamily.energetic, nameEn: 'Pixelize',   nameHi: 'पिक्सेलाइज़', isPro: true,  lottieAsset: '', previewThumbnail: ''),
    MotionStyle(id: MotionStyleId.hBlur,       family: MotionStyleFamily.energetic, nameEn: 'Motion Blur',nameHi: 'मोशन ब्लर',   isPro: true,  lottieAsset: '', previewThumbnail: ''),
    MotionStyle(id: MotionStyleId.rectCrop,    family: MotionStyleFamily.energetic, nameEn: 'Box Reveal', nameHi: 'बॉक्स रिवील', isPro: true,  lottieAsset: '', previewThumbnail: ''),

    // Informational family — geometric / diagonal
    MotionStyle(id: MotionStyleId.wipeTL,      family: MotionStyleFamily.informational, nameEn: 'Diagonal TL', nameHi: 'तिरछा TL',   isPro: true, lottieAsset: '', previewThumbnail: ''),
    MotionStyle(id: MotionStyleId.wipeTR,      family: MotionStyleFamily.informational, nameEn: 'Diagonal TR', nameHi: 'तिरछा TR',   isPro: true, lottieAsset: '', previewThumbnail: ''),
    MotionStyle(id: MotionStyleId.wipeBL,      family: MotionStyleFamily.informational, nameEn: 'Diagonal BL', nameHi: 'तिरछा BL',   isPro: true, lottieAsset: '', previewThumbnail: ''),
    MotionStyle(id: MotionStyleId.wipeBR,      family: MotionStyleFamily.informational, nameEn: 'Diagonal BR', nameHi: 'तिरछा BR',   isPro: true, lottieAsset: '', previewThumbnail: ''),
    MotionStyle(id: MotionStyleId.coverLeft,   family: MotionStyleFamily.informational, nameEn: 'Cover Left',  nameHi: 'कवर लेफ्ट',  isPro: true, lottieAsset: '', previewThumbnail: ''),
    MotionStyle(id: MotionStyleId.coverRight,  family: MotionStyleFamily.informational, nameEn: 'Cover Right', nameHi: 'कवर राइट',   isPro: true, lottieAsset: '', previewThumbnail: ''),
    MotionStyle(id: MotionStyleId.coverUp,     family: MotionStyleFamily.informational, nameEn: 'Cover Up',    nameHi: 'कवर अप',     isPro: true, lottieAsset: '', previewThumbnail: ''),
    MotionStyle(id: MotionStyleId.coverDown,   family: MotionStyleFamily.informational, nameEn: 'Cover Down',  nameHi: 'कवर डाउन',   isPro: true, lottieAsset: '', previewThumbnail: ''),
    MotionStyle(id: MotionStyleId.revealLeft,  family: MotionStyleFamily.informational, nameEn: 'Reveal Left', nameHi: 'रिवील लेफ्ट',isPro: true, lottieAsset: '', previewThumbnail: ''),
    MotionStyle(id: MotionStyleId.revealRight, family: MotionStyleFamily.informational, nameEn: 'Reveal Right',nameHi: 'रिवील राइट', isPro: true, lottieAsset: '', previewThumbnail: ''),
  ];
}
