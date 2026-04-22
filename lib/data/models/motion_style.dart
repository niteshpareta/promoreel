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
  ];
}
