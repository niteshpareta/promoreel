import 'package:flutter/material.dart';

import 'motion_style.dart';

/// A slide-to-slide transition option — one of FFmpeg's built-in `xfade`
/// filters. Independent of per-slide camera motion.
class TransitionOption {
  const TransitionOption({
    required this.id,
    required this.label,
    required this.durationSec,
    required this.icon,
    this.isPro = false,
  });

  /// FFmpeg xfade filter name. Used verbatim in `motion_style_engine.dart`.
  final String id;
  final String label;
  final double durationSec;
  final IconData icon;
  final bool isPro;

  /// Relative path to the preview WebP (without leading `assets/`).
  String get previewAsset => 'assets/motion_previews/transition/$id.webp';
}

/// A per-slide camera-motion option — zoom, pan, pulse, pop, or none.
/// Independent of slide transitions.
class CameraMotionOption {
  const CameraMotionOption({
    required this.id,
    required this.label,
    required this.icon,
    this.isPro = false,
  });

  /// Stable machine id — `'none'`, `'slowZoom'`, `'kenBurnsPan'`, etc.
  /// Used directly by the engine's `_motionFilter` switch.
  final String id;
  final String label;
  final IconData icon;
  final bool isPro;

  String get previewAsset => 'assets/motion_previews/camera/$id.webp';
}

/// The 30 transitions exposed in the picker. Order matters — it's the
/// strip order the user scrolls through.
const List<TransitionOption> kTransitions = [
  // Essentials — free
  TransitionOption(id: 'fade',        label: 'Fade',        durationSec: 0.50, icon: Icons.blur_on_rounded),
  TransitionOption(id: 'dissolve',    label: 'Dissolve',    durationSec: 0.60, icon: Icons.gradient_rounded),
  TransitionOption(id: 'fadeblack',   label: 'Black Fade',  durationSec: 0.45, icon: Icons.brightness_2_rounded),
  TransitionOption(id: 'fadewhite',   label: 'Flash',       durationSec: 0.30, icon: Icons.flash_on_rounded),

  // Slides
  TransitionOption(id: 'slideup',     label: 'Slide Up',    durationSec: 0.50, icon: Icons.north_rounded),
  TransitionOption(id: 'slidedown',   label: 'Slide Down',  durationSec: 0.50, icon: Icons.south_rounded),
  TransitionOption(id: 'slideleft',   label: 'Slide Left',  durationSec: 0.50, icon: Icons.west_rounded),
  TransitionOption(id: 'slideright',  label: 'Slide Right', durationSec: 0.50, icon: Icons.east_rounded),

  // Wipes
  TransitionOption(id: 'wipeup',      label: 'Wipe Up',     durationSec: 0.50, icon: Icons.vertical_align_top_rounded),
  TransitionOption(id: 'wipedown',    label: 'Wipe Down',   durationSec: 0.50, icon: Icons.vertical_align_bottom_rounded),
  TransitionOption(id: 'wipeleft',    label: 'Wipe Left',   durationSec: 0.50, icon: Icons.keyboard_double_arrow_left_rounded, isPro: true),

  // Diagonal wipes — pro
  TransitionOption(id: 'wipetl',      label: 'Wipe TL',     durationSec: 0.50, icon: Icons.north_west_rounded, isPro: true),
  TransitionOption(id: 'wipetr',      label: 'Wipe TR',     durationSec: 0.50, icon: Icons.north_east_rounded, isPro: true),
  TransitionOption(id: 'wipebl',      label: 'Wipe BL',     durationSec: 0.50, icon: Icons.south_west_rounded, isPro: true),
  TransitionOption(id: 'wipebr',      label: 'Wipe BR',     durationSec: 0.50, icon: Icons.south_east_rounded, isPro: true),

  // Geometric
  TransitionOption(id: 'circleopen',  label: 'Circle Open', durationSec: 0.50, icon: Icons.adjust_rounded),
  TransitionOption(id: 'circleclose', label: 'Circle In',   durationSec: 0.50, icon: Icons.radio_button_checked_rounded, isPro: true),
  TransitionOption(id: 'rectcrop',    label: 'Box Reveal',  durationSec: 0.55, icon: Icons.crop_din_rounded, isPro: true),

  // Covers & reveals — pro
  TransitionOption(id: 'coverleft',   label: 'Cover L',     durationSec: 0.50, icon: Icons.arrow_back_rounded, isPro: true),
  TransitionOption(id: 'coverright',  label: 'Cover R',     durationSec: 0.50, icon: Icons.arrow_forward_rounded, isPro: true),
  TransitionOption(id: 'coverup',     label: 'Cover U',     durationSec: 0.50, icon: Icons.arrow_upward_rounded, isPro: true),
  TransitionOption(id: 'coverdown',   label: 'Cover D',     durationSec: 0.50, icon: Icons.arrow_downward_rounded, isPro: true),
  TransitionOption(id: 'revealleft',  label: 'Reveal L',    durationSec: 0.50, icon: Icons.chevron_left_rounded, isPro: true),
  TransitionOption(id: 'revealright', label: 'Reveal R',    durationSec: 0.50, icon: Icons.chevron_right_rounded, isPro: true),

  // Stylised — pro
  TransitionOption(id: 'fadegrays',   label: 'Grayscale',   durationSec: 0.60, icon: Icons.gradient_rounded, isPro: true),
  TransitionOption(id: 'pixelize',    label: 'Pixelize',    durationSec: 0.50, icon: Icons.grid_view_rounded, isPro: true),
  TransitionOption(id: 'hblur',       label: 'Motion Blur', durationSec: 0.45, icon: Icons.blur_linear_rounded, isPro: true),
  TransitionOption(id: 'smoothleft',  label: 'Smooth L',    durationSec: 0.60, icon: Icons.keyboard_arrow_left_rounded, isPro: true),
  TransitionOption(id: 'smoothright', label: 'Smooth R',    durationSec: 0.60, icon: Icons.keyboard_arrow_right_rounded, isPro: true),
];

/// Fast lookup by id. Unknown ids fall back to the first entry (`fade`).
TransitionOption transitionById(String id) =>
    kTransitions.firstWhere((t) => t.id == id, orElse: () => kTransitions.first);

/// The 6 camera-motion options exposed in the picker.
const List<CameraMotionOption> kCameras = [
  CameraMotionOption(id: 'none',           label: 'None',        icon: Icons.do_disturb_on_rounded),
  CameraMotionOption(id: 'slowZoom',       label: 'Slow Zoom',   icon: Icons.zoom_in_rounded),
  CameraMotionOption(id: 'zoomInSubtle',   label: 'Subtle Zoom', icon: Icons.zoom_in_map_rounded),
  CameraMotionOption(id: 'kenBurnsPan',    label: 'Ken Burns',   icon: Icons.swap_horiz_rounded),
  CameraMotionOption(id: 'quickPulse',     label: 'Beat Pulse',  icon: Icons.graphic_eq_rounded),
  CameraMotionOption(id: 'popPulse',       label: 'Pop In',      icon: Icons.auto_graph_rounded),
];

CameraMotionOption cameraById(String id) =>
    kCameras.firstWhere((c) => c.id == id, orElse: () => kCameras.first);

/// Defaults for a brand-new project — the least surprising combination.
const String kDefaultTransitionId = 'fade';
const String kDefaultCameraMotionId = 'none';

/// Decomposes a legacy `MotionStyleId` (saved in older drafts) into the
/// two-axis `(transitionId, cameraMotionId)` pair. Called once on draft
/// load when the new fields are missing.
(String transition, String camera) decomposeMotionStyleId(MotionStyleId id) {
  switch (id) {
    case MotionStyleId.none:                 return ('fade',       'none');
    case MotionStyleId.slowZoom:             return ('fade',       'slowZoom');
    case MotionStyleId.kenBurnsPan:          return ('fade',       'kenBurnsPan');
    case MotionStyleId.softCrossfade:        return ('dissolve',   'none');
    case MotionStyleId.elegantSlide:         return ('slideup',    'none');
    case MotionStyleId.quickCutBeatSync:     return ('fade',       'quickPulse');
    case MotionStyleId.boldSlide:            return ('slideright', 'none');
    case MotionStyleId.flashReveal:          return ('fadewhite',  'none');
    case MotionStyleId.gridPop:              return ('circleopen', 'popPulse');
    case MotionStyleId.splitScreenInfo:      return ('slidedown',  'none');
    case MotionStyleId.bottomThirdHighlight: return ('fade',       'zoomInSubtle');
    case MotionStyleId.progressiveReveal:    return ('wipeleft',   'none');
    case MotionStyleId.captionStack:         return ('slideleft',  'none');
    case MotionStyleId.wipeUp:               return ('wipeup',     'none');
    case MotionStyleId.wipeDown:             return ('wipedown',   'none');
    case MotionStyleId.wipeTL:               return ('wipetl',     'none');
    case MotionStyleId.wipeTR:               return ('wipetr',     'none');
    case MotionStyleId.wipeBL:               return ('wipebl',     'none');
    case MotionStyleId.wipeBR:               return ('wipebr',     'none');
    case MotionStyleId.circleClose:          return ('circleclose','none');
    case MotionStyleId.rectCrop:             return ('rectcrop',   'none');
    case MotionStyleId.coverLeft:            return ('coverleft',  'none');
    case MotionStyleId.coverRight:           return ('coverright', 'none');
    case MotionStyleId.coverUp:              return ('coverup',    'none');
    case MotionStyleId.coverDown:            return ('coverdown',  'none');
    case MotionStyleId.revealLeft:           return ('revealleft', 'none');
    case MotionStyleId.revealRight:          return ('revealright','none');
    case MotionStyleId.pixelize:             return ('pixelize',   'none');
    case MotionStyleId.hBlur:                return ('hblur',      'none');
    case MotionStyleId.fadeBlack:            return ('fadeblack',  'none');
    case MotionStyleId.fadeGrays:            return ('fadegrays',  'none');
    case MotionStyleId.smoothLeft:           return ('smoothleft', 'none');
    case MotionStyleId.smoothRight:          return ('smoothright','none');
  }
}
