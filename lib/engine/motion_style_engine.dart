import '../data/models/motion_style.dart';

/// A single per-frame text overlay with its active time window.
class FrameTextOverlay {
  const FrameTextOverlay({
    required this.path,
    required this.startSec,
    required this.endSec,
    this.animStyle = 'none',
    this.textPosition = 'bottom',
  });
  final String path;
  final double startSec;
  final double endSec;
  final String animStyle;
  // 'none' | 'fade' | 'slide_up' | 'typewriter' | 'wipe' | 'pop'

  /// Where the caption sits on the frame — used by the `pop` animation to
  /// keep the caption anchored at its original position while the pill
  /// scales up (otherwise the whole PNG re-centres and top/bottom captions
  /// drift towards the middle).
  final String textPosition;

  /// Approximate fractional y position (0–1) of the caption centre. Used
  /// by pop's overlay y expression so the pill scales in place.
  double get centerYFraction {
    switch (textPosition) {
      case 'top':
        return 0.12;
      case 'center':
        return 0.50;
      case 'bottom':
      default:
        return 0.85;
    }
  }
}

/// Per-slide camera/scale motion applied on top of the composited 720×1280 frame.
/// Styles combine one of these with an xfade transition to produce their identity.
enum _Motion {
  none,
  zoomInStandard, // 100% → 115% linear over the full slide duration
  zoomInSubtle,   //  100% → 108% linear over the full slide duration
  kenBurnsPan,    // pan across at 115% zoom; direction alternates by slide index
  quickPulse,     // 105% → 100% in the first 0.3s (beat-sync feel)
  popPulse,       // 112% → 100% in the first 0.45s (pop-in feel)
}

class MotionStyleEngine {
  static const Map<MotionStyleId, _StyleSpec> _specs = {
    // "None" = no camera motion + short neutral fade. Default preset.
    MotionStyleId.none:                 _StyleSpec('fade',       0.25, _Motion.none),
    MotionStyleId.slowZoom:             _StyleSpec('fade',       0.60, _Motion.zoomInStandard),
    MotionStyleId.kenBurnsPan:          _StyleSpec('fade',       0.50, _Motion.kenBurnsPan),
    MotionStyleId.softCrossfade:        _StyleSpec('dissolve',   0.80, _Motion.none),
    MotionStyleId.elegantSlide:         _StyleSpec('slideup',    0.50, _Motion.none),
    MotionStyleId.quickCutBeatSync:     _StyleSpec('fade',       0.10, _Motion.quickPulse),
    MotionStyleId.boldSlide:            _StyleSpec('slideright', 0.35, _Motion.none),
    MotionStyleId.flashReveal:          _StyleSpec('fadewhite',  0.25, _Motion.none),
    MotionStyleId.gridPop:              _StyleSpec('circleopen', 0.40, _Motion.popPulse),
    MotionStyleId.splitScreenInfo:      _StyleSpec('slidedown',  0.50, _Motion.none),
    MotionStyleId.bottomThirdHighlight: _StyleSpec('fade',       0.60, _Motion.zoomInSubtle),
    MotionStyleId.progressiveReveal:    _StyleSpec('wipeleft',   0.70, _Motion.none),
    MotionStyleId.captionStack:         _StyleSpec('slideleft',  0.50, _Motion.none),

    // ── Expansion pack (20 extra xfade transitions) ─────────────────────
    // Subtle — calmer, no camera motion.
    MotionStyleId.wipeUp:               _StyleSpec('wipeup',      0.50, _Motion.none),
    MotionStyleId.wipeDown:             _StyleSpec('wipedown',    0.50, _Motion.none),
    MotionStyleId.smoothLeft:           _StyleSpec('smoothleft',  0.60, _Motion.none),
    MotionStyleId.smoothRight:          _StyleSpec('smoothright', 0.60, _Motion.none),

    // Energetic
    MotionStyleId.circleClose:          _StyleSpec('circleclose', 0.50, _Motion.none),
    MotionStyleId.fadeBlack:            _StyleSpec('fadeblack',   0.45, _Motion.none),
    MotionStyleId.fadeGrays:            _StyleSpec('fadegrays',   0.60, _Motion.none),
    MotionStyleId.pixelize:             _StyleSpec('pixelize',    0.50, _Motion.none),
    MotionStyleId.hBlur:                _StyleSpec('hblur',       0.45, _Motion.none),
    MotionStyleId.rectCrop:             _StyleSpec('rectcrop',    0.55, _Motion.none),

    // Informational — geometric / directional
    MotionStyleId.wipeTL:               _StyleSpec('wipetl',      0.50, _Motion.none),
    MotionStyleId.wipeTR:               _StyleSpec('wipetr',      0.50, _Motion.none),
    MotionStyleId.wipeBL:               _StyleSpec('wipebl',      0.50, _Motion.none),
    MotionStyleId.wipeBR:               _StyleSpec('wipebr',      0.50, _Motion.none),
    MotionStyleId.coverLeft:            _StyleSpec('coverleft',   0.50, _Motion.none),
    MotionStyleId.coverRight:           _StyleSpec('coverright',  0.50, _Motion.none),
    MotionStyleId.coverUp:              _StyleSpec('coverup',     0.50, _Motion.none),
    MotionStyleId.coverDown:            _StyleSpec('coverdown',   0.50, _Motion.none),
    MotionStyleId.revealLeft:           _StyleSpec('revealleft',  0.50, _Motion.none),
    MotionStyleId.revealRight:          _StyleSpec('revealright', 0.50, _Motion.none),
  };

  /// Build the motion filter chain (including leading comma) for a slide.
  /// Returns an empty string if no motion applies.
  ///
  /// `frameDur` is the slide's own duration; `t` inside the expression is the
  /// input-relative time, which restarts at 0 for each slide input.
  static String _motionFilter(
      _Motion motion, int slideIdx, double frameDur, int outW, int outH) {
    if (motion == _Motion.none) return '';
    final dur = frameDur.toStringAsFixed(3);
    switch (motion) {
      case _Motion.none:
        return '';
      // NOTE: FFmpeg 8.0's `crop` filter no longer accepts `t` in its
      // expressions (evaluation fails at filter config with "Error when
      // evaluating the expression"). The reliable replacement is `scale`
      // with `eval=frame`, which still supports time-dependent expressions.
      //
      // Trick for a "zoom-in" effect: scale the input LARGER over time,
      // then statically crop the centre back to the output size. Same
      // perceived motion as crop-in + scale-up, but uses only filters that
      // FFmpeg 8 accepts.
      //
      // For Ken Burns pan: scale statically to a slightly larger size and
      // zoompan across it, since pan-in-crop is also off-limits. We use
      // `zoompan` which is purpose-built for this.
      case _Motion.zoomInStandard:
        return _zoomInViaScale(factor: 0.15, dur: dur, outW: outW, outH: outH);
      case _Motion.zoomInSubtle:
        return _zoomInViaScale(factor: 0.08, dur: dur, outW: outW, outH: outH);
      case _Motion.kenBurnsPan:
        return _kenBurnsViaZoomPan(
            dur: dur, outW: outW, outH: outH, leftToRight: slideIdx.isEven);
      case _Motion.quickPulse:
        // Pulse: quick zoom from 1.05 to 1.00 over the first 0.3s, then hold.
        return _pulseViaScale(
            startZoom: 0.05, rampSec: 0.3, dur: dur, outW: outW, outH: outH);
      case _Motion.popPulse:
        return _pulseViaScale(
            startZoom: 0.12, rampSec: 0.45, dur: dur, outW: outW, outH: outH);
    }
  }

  /// Scale-then-center-crop zoom (replaces the old `crop` + scale pair that
  /// broke in FFmpeg 8). Grows the image by [factor] over the full slide
  /// duration, then crops the centre to out dims.
  static String _zoomInViaScale({
    required double factor,
    required String dur,
    required int outW,
    required int outH,
  }) {
    return ",scale=w='$outW*(1+$factor*t/$dur)':h='$outH*(1+$factor*t/$dur)':eval=frame"
        ",crop=$outW:$outH:(iw-$outW)/2:(ih-$outH)/2";
  }

  /// Pulse: starts zoomed in by [startZoom] and settles back to 1.0 over
  /// [rampSec] seconds.
  static String _pulseViaScale({
    required double startZoom,
    required double rampSec,
    required String dur,
    required int outW,
    required int outH,
  }) {
    // Zoom factor over time: (1+startZoom) - startZoom * min(t, rampSec) / rampSec
    final zoomExpr = '(1+$startZoom)-$startZoom*min(t,$rampSec)/$rampSec';
    return ",scale=w='$outW*($zoomExpr)':h='$outH*($zoomExpr)':eval=frame"
        ",crop=$outW:$outH:(iw-$outW)/2:(ih-$outH)/2";
  }

  /// Ken Burns horizontal pan via `zoompan` — scale up 15 %, slide the
  /// window horizontally. zoompan is FFmpeg's idiomatic filter for this
  /// and handles time natively.
  static String _kenBurnsViaZoomPan({
    required String dur,
    required int outW,
    required int outH,
    required bool leftToRight,
  }) {
    final durFloat = double.tryParse(dur) ?? 3.0;
    final frames = (durFloat * 30).round();
    // Scale larger so there's room to pan. Then zoompan at constant zoom
    // with x drifting across the extra width.
    final scaledW = (outW * 1.15).round();
    final scaledH = (outH * 1.15).round();
    final xExpr = leftToRight
        ? '(iw-ow)*on/$frames'
        : '(iw-ow)*(1-on/$frames)';
    return ",scale=$scaledW:$scaledH"
        ",zoompan=z=1:x='$xExpr':y='(ih-oh)/2':d=$frames:s=${outW}x$outH:fps=30";
  }

  static String build({
    required List<String> inputPaths,
    required List<bool> isVideo,
    required String outputPath,
    required List<FrameTextOverlay> textOverlays,
    required String? brandingPath,
    required String? audioPath,
    List<String?> frameVoiceovers = const [],
    required int totalDuration,
    required MotionStyleId styleId,
    // Two-axis picker — overrides [styleId]'s bundled transition / camera
    // when non-null. New code paths pass these; legacy callers that still
    // pass `styleId` alone get the decomposed (transition, camera) via
    // the `_specs` table fallback below.
    String? transitionId,
    String? cameraMotionId,
    required List<double> frameDurations,
    // When true for an index, the image is already composited to outW×outH by Flutter.
    // FFmpeg only needs fps+format — no split/blur/scale/overlay.
    List<bool>? preComposedFlags,
    // Per-slide trim-start offset in seconds. Only meaningful when
    // `isVideo[i]` is true — FFmpeg seeks this far into the source
    // before reading. `null` or absent = start at 0.
    List<double>? videoTrimStartSec,
    // Per-slide rotation in degrees (0 / 90 / 180 / 270). Only meaningful
    // when `isVideo[i]` is true; applied as an FFmpeg `transpose` or
    // `hflip,vflip` filter before the scale-and-pad chain.
    List<int>? videoRotations,
    // Per-slide opt-in for mixing the source video's audio into the
    // output. When true for index `i`, that input's `:a` stream is
    // delayed to `starts[i]`, trimmed to `frameDurations[i]`, and mixed
    // with any voiceovers and music. No-op for non-video slides.
    List<bool>? videoUseAudio,
    // Per-slide playback speed multiplier. `1.0` default. Affects how
    // much source material is consumed (`inputLen * speed`) and the
    // `setpts`/`atempo` filters applied.
    List<double>? videoSpeed,
    // Per-slide crop rect as [x, y, w, h] in [0,1] fractions of the
    // source frame. `null` / `[0,0,1,1]` = no crop. Applied before
    // rotation so fractions map to the original orientation.
    List<List<double>>? videoCropRects,
    String? watermarkPath,
    String? countdownPath,
    String? qrOverlayPath,
    int outW = 720,
    int outH = 1280,
  }) {
    assert(inputPaths.isNotEmpty);
    assert(inputPaths.length == isVideo.length);
    assert(inputPaths.length == frameDurations.length);

    final spec = _resolveSpec(
      styleId: styleId,
      transitionId: transitionId,
      cameraMotionId: cameraMotionId,
    );
    final int n = inputPaths.length;

    final double minDur = frameDurations.reduce((a, b) => a < b ? a : b);
    final double trans  = spec.transitionDuration.clamp(0.1, minDur * 0.40);

    final List<double> starts = [];
    double cumulative = 0;
    for (int i = 0; i < n; i++) {
      starts.add(cumulative);
      cumulative += frameDurations[i];
    }

    final buf = StringBuffer();
    buf.write('-y ');

    // ── Inputs ───────────────────────────────────────────────────────────────
    for (int i = 0; i < n; i++) {
      final double inputLen = i < n - 1
          ? frameDurations[i] + trans
          : frameDurations[i];
      final bool preComposed = preComposedFlags != null &&
          i < preComposedFlags.length && preComposedFlags[i];

      if (isVideo[i]) {
        // Per-slide trim start — seek this far into the source before
        // reading, then take `inputLen * speed` seconds. `-ss` before
        // `-i` is the fast-seek form; plenty accurate for keyframe-
        // aligned clips and ~10× faster than output-side seeking.
        // Speed>1 consumes extra material so the sped-up clip still
        // fills the slide duration; speed<1 reads less and the setpts
        // filter expands it to the slide duration.
        final trimStart = videoTrimStartSec != null &&
                i < videoTrimStartSec.length
            ? videoTrimStartSec[i]
            : 0.0;
        final speed = videoSpeed != null && i < videoSpeed.length
            ? videoSpeed[i]
            : 1.0;
        final readLen = inputLen * speed;
        buf.write('-ss ${trimStart.toStringAsFixed(3)} '
            '-t ${readLen.toStringAsFixed(3)} -i "${inputPaths[i]}" ');
      } else if (preComposed) {
        buf.write('-loop 1 -framerate 1 -t ${inputLen.toStringAsFixed(3)} '
            '-i "${inputPaths[i]}" ');
      } else {
        buf.write('-loop 1 -framerate 30 -t ${inputLen.toStringAsFixed(3)} '
            '-i "${inputPaths[i]}" ');
      }
    }

    if (audioPath != null) buf.write('-i "$audioPath" ');
    // Per-frame voiceovers
    final activeVoiceovers = <({int frameIdx, int inputIdx, String path, double startSec})>[];
    {
      int idx = n + (audioPath != null ? 1 : 0);
      for (int i = 0; i < frameVoiceovers.length && i < n; i++) {
        final vp = frameVoiceovers[i];
        if (vp != null) {
          buf.write('-i "$vp" ');
          activeVoiceovers.add((frameIdx: i, inputIdx: idx, path: vp, startSec: starts[i]));
          idx++;
        }
      }
    }
    for (final ov in textOverlays) {
      buf.write('-loop 1 -framerate 30 -i "${ov.path}" ');
    }
    if (brandingPath != null) {
      buf.write('-loop 1 -framerate 30 -i "$brandingPath" ');
    }
    if (countdownPath != null) {
      buf.write('-loop 1 -framerate 1 -i "$countdownPath" ');
    }
    if (qrOverlayPath != null) {
      buf.write('-loop 1 -framerate 1 -i "$qrOverlayPath" ');
    }
    if (watermarkPath != null) {
      buf.write('-loop 1 -framerate 1 -i "$watermarkPath" ');
    }

    // ── Filter complex ────────────────────────────────────────────────────────
    buf.write('-filter_complex "');

    for (int i = 0; i < n; i++) {
      final bool preComposed = preComposedFlags != null &&
          i < preComposedFlags.length && preComposedFlags[i];
      // Camera motion (zoom / pan / pulse) is designed for stills — it
      // adds life to a photo. Layering it on video content creates a
      // disorienting "double motion" effect, so videos always bypass the
      // motion filter and play as-is. Transitions between slides still
      // apply normally.
      final String motion = isVideo[i]
          ? ''
          : _motionFilter(spec.motion, i, frameDurations[i], outW, outH);

      if (preComposed) {
        buf.write('[$i:v]fps=30$motion,format=yuv420p[v$i]; ');
      } else if (isVideo[i]) {
        // Per-slide rotation. Applied before scale/crop so the subsequent
        // cover-pad chain sees the oriented frame.
        final rot = videoRotations != null && i < videoRotations.length
            ? videoRotations[i] % 360
            : 0;
        final String rotFilter = switch (rot) {
          90 => 'transpose=1,',
          180 => 'hflip,vflip,',
          270 => 'transpose=2,',
          _ => '',
        };
        // Per-slide crop — in/out are fractions of the source frame.
        // Applied BEFORE rotation so fractions map to the original
        // orientation (what the user drew the crop against in the UI).
        String cropFilter = '';
        if (videoCropRects != null &&
            i < videoCropRects.length &&
            videoCropRects[i].length == 4) {
          final r = videoCropRects[i];
          final cx = r[0].clamp(0.0, 1.0);
          final cy = r[1].clamp(0.0, 1.0);
          final cw = r[2].clamp(0.01, 1.0);
          final ch = r[3].clamp(0.01, 1.0);
          if (cx > 0.0001 || cy > 0.0001 || cw < 0.9999 || ch < 0.9999) {
            cropFilter = 'crop=iw*${cw.toStringAsFixed(4)}:'
                'ih*${ch.toStringAsFixed(4)}:'
                'iw*${cx.toStringAsFixed(4)}:'
                'ih*${cy.toStringAsFixed(4)},';
          }
        }
        // Per-slide speed. `setpts=PTS/S` retimes the stream so the
        // clip plays faster/slower; combined with the extended `-t`
        // input read above, the output slide length remains equal to
        // `frameDurations[i]` regardless of speed.
        final speed = videoSpeed != null && i < videoSpeed.length
            ? videoSpeed[i]
            : 1.0;
        final String speedFilter = speed == 1.0
            ? ''
            : 'setpts=PTS/${speed.toStringAsFixed(3)},';
        buf.write('[$i:v]$cropFilter$rotFilter${speedFilter}split[raw${i}a][raw${i}b]; ');
        buf.write('[raw${i}a]scale=$outW:$outH:'
            'force_original_aspect_ratio=increase,'
            'crop=$outW:$outH,boxblur=3:1[bg$i]; ');
        buf.write('[raw${i}b]scale=$outW:$outH:'
            'force_original_aspect_ratio=decrease,'
            'setsar=1[fg$i]; ');
        buf.write('[bg$i][fg$i]overlay=(W-w)/2:(H-h)/2,'
            'fps=30$motion,format=yuv420p[v$i]; ');
      } else {
        buf.write('[$i:v]split[raw${i}a][raw${i}b]; ');
        buf.write('[raw${i}a]scale=$outW:$outH:'
            'force_original_aspect_ratio=increase,'
            'crop=$outW:$outH,boxblur=3:1[bg$i]; ');
        buf.write('[raw${i}b]scale=$outW:$outH:'
            'force_original_aspect_ratio=decrease,'
            'setsar=1[fg$i]; ');
        buf.write('[bg$i][fg$i]overlay=(W-w)/2:(H-h)/2,'
            'fps=30$motion,format=yuv420p[v$i]; ');
      }
    }

    // Xfade chain
    if (n == 1) {
      buf.write('[v0]null[vx]; ');
    } else {
      String prev = 'v0';
      for (int i = 1; i < n; i++) {
        final double offset = (starts[i] - trans).clamp(0.0, double.infinity);
        final String outLabel = i == n - 1 ? 'vx' : 'x$i';
        buf.write('[$prev][v$i]xfade=transition=${spec.transitionName}:'
            'duration=${trans.toStringAsFixed(3)}:'
            'offset=${offset.toStringAsFixed(3)}[$outLabel]; ');
        prev = outLabel;
      }
    }

    // Text overlays (with optional animation)
    int nextIdx = n + (audioPath != null ? 1 : 0) + activeVoiceovers.length;
    String lastLabel = 'vx';

    for (int i = 0; i < textOverlays.length; i++) {
      final ov = textOverlays[i];
      final outLabel = 'vtx$i';
      final start = ov.startSec.toStringAsFixed(3);
      final end   = ov.endSec.toStringAsFixed(3);

      if (ov.animStyle == 'fade') {
        // Shift PNG stream so its t=0 aligns with START in the output, then fade-in.
        buf.write('[${nextIdx}:v]setpts=PTS+$start/TB,'
            'fade=type=in:start_time=${ov.startSec.toStringAsFixed(3)}:'
            'duration=0.35:alpha=1[afade$i]; ');
        buf.write("[$lastLabel][afade$i]overlay=0:0:"
            "enable='between(t,$start,$end)':"
            "format=auto:eof_action=repeat[$outLabel]; ");
      } else if (ov.animStyle == 'slide_up') {
        // Slides up from 80px below over 0.35s.
        buf.write("[$lastLabel][${nextIdx}:v]overlay="
            "x=0:"
            "y='if(lt(t-$start,0.35),((0.35-(t-$start))/0.35)*80,0)':"
            "enable='between(t,$start,$end)':"
            "format=auto:eof_action=repeat[$outLabel]; ");
      } else if (ov.animStyle == 'typewriter' || ov.animStyle == 'wipe') {
        // FFmpeg 8's `crop` filter rejects the `eval` option entirely, so
        // we can't do a time-varying left-to-right mask with crop. Instead
        // we slide the overlay in from the left using overlay-x expression
        // (which DOES accept `t`). Caption appears to glide in — reads as
        // an entrance. Typewriter is just the slower version.
        final revealDur = ov.animStyle == 'typewriter' ? 0.8 : 0.35;
        buf.write("[$lastLabel][${nextIdx}:v]overlay="
            "x='if(lt(t-$start,$revealDur),"
            "-w*(1-(t-$start)/$revealDur),0)':"
            "y=0:"
            "enable='between(t,$start,$end)':"
            "format=auto:eof_action=repeat[$outLabel]; ");
      } else if (ov.animStyle == 'pop') {
        // Scale 0.6 → 1.0 over 0.3s. Overlay y is anchored to the caption's
        // original vertical centre so top/bottom captions don't drift
        // toward screen middle as the overlay shrinks.
        const double popDur = 0.30;
        final startStr = ov.startSec.toStringAsFixed(3);
        final scaleExpr =
            "if(lt(t-$startStr,$popDur),"
            "min(1,0.6+0.4*(t-$startStr)/$popDur),"
            "1)";
        final cyFrac = ov.centerYFraction.toStringAsFixed(3);
        buf.write('[${nextIdx}:v]setpts=PTS+$start/TB,'
            "scale=w='iw*($scaleExpr)':h='ih*($scaleExpr)':eval=frame[pop$i]; ");
        buf.write("[$lastLabel][pop$i]overlay="
            "x='(W-w)/2':y='$cyFrac*(H-h)':"
            "enable='between(t,$start,$end)':"
            "format=auto:eof_action=repeat[$outLabel]; ");
      } else {
        buf.write("[$lastLabel][${nextIdx}:v]overlay=0:0:"
            "enable='between(t,$start,$end)':"
            "format=auto:eof_action=repeat[$outLabel]; ");
      }
      lastLabel = outLabel;
      nextIdx++;
    }

    // Branding strip — the compositor now emits a full-frame
    // transparent PNG with the strip positioned internally (top /
    // bottom / side badge), so we overlay at 0,0 instead of anchoring
    // to the bottom.
    if (brandingPath != null) {
      buf.write('[$lastLabel][${nextIdx}:v]overlay=0:0:eof_action=repeat[vb]; ');
      lastLabel = 'vb';
      nextIdx++;
    }

    // Countdown banner (top strip — full duration)
    if (countdownPath != null) {
      buf.write('[$lastLabel][${nextIdx}:v]overlay=0:0:eof_action=repeat[vcd]; ');
      lastLabel = 'vcd';
      nextIdx++;
    }

    // QR code overlay (corner — full duration)
    if (qrOverlayPath != null) {
      buf.write('[$lastLabel][${nextIdx}:v]overlay=0:0:eof_action=repeat[vqr]; ');
      lastLabel = 'vqr';
      nextIdx++;
    }

    // Watermark (free tier)
    if (watermarkPath != null) {
      buf.write('[$lastLabel][${nextIdx}:v]overlay=0:0:eof_action=repeat[vw]; ');
      lastLabel = 'vw';
    }

    buf.write('[$lastLabel]null[vout]');
    buf.write('" ');

    // ── Output ────────────────────────────────────────────────────────────────
    buf.write('-map "[vout]" ');

    // Collect every per-slide source-video audio stream that the user
    // opted into. We reuse the same adelay+afade pattern as voiceovers
    // so the mix path below doesn't need to distinguish — they're all
    // just clips placed at `starts[i]` with a slide-duration window.
    final sourceAudios = <({
      int frameIdx,
      int inputIdx,
      double startSec,
      double speed,
    })>[];
    if (videoUseAudio != null) {
      for (int i = 0; i < n && i < videoUseAudio.length; i++) {
        if (!isVideo[i] || !videoUseAudio[i]) continue;
        final speed = videoSpeed != null && i < videoSpeed.length
            ? videoSpeed[i]
            : 1.0;
        sourceAudios.add((
          frameIdx: i,
          inputIdx: i,
          startSec: starts[i],
          speed: speed,
        ));
      }
    }

    String clipFilter({
      required int inputIdx,
      required int frameIdx,
      required double startSec,
      required double speed,
      required String label,
    }) {
      // Only one xfade shifts the final output timeline — the
      // intermediate slides contribute `dur[i] + trans` of material
      // and the xfade eats `trans` of it, so the net compression is
      // a constant `trans` (not `frameIdx * trans`). Slide 0 starts
      // at t=0, slides 1..n-1 appear at `starts[i] - trans`.
      final correction = frameIdx > 0 ? trans : 0.0;
      final delayMs =
          ((startSec - correction) * 1000).round().clamp(0, 999999);
      final fadeSt = (frameDurations[frameIdx] - 0.15)
          .clamp(0.0, double.infinity);
      // atempo (speed) must run before adelay so the delay is measured
      // in output-time milliseconds, not source-time.
      final atempo =
          speed == 1.0 ? '' : 'atempo=${speed.toStringAsFixed(3)},';
      return '[$inputIdx:a]$atempo'
          'adelay=$delayMs|$delayMs,'
          'afade=t=out:st=${fadeSt.toStringAsFixed(3)}:d=0.15'
          '[$label];';
    }

    final hasVoiceovers = activeVoiceovers.isNotEmpty;
    final hasSourceAudio = sourceAudios.isNotEmpty;
    final hasClips = hasVoiceovers || hasSourceAudio;

    if (hasClips) {
      final musicIdx = n;
      final filters = StringBuffer();
      final labels = <String>[];

      for (final vo in activeVoiceovers) {
        // Voiceover frameIdx semantics predate source audio and were
        // historically off-by-one: `frameIdx > 1` and `(frameIdx - 1)`
        // — preserve that so existing voiceover timings stay identical.
        final correction = vo.frameIdx > 1 ? (vo.frameIdx - 1) * trans : 0.0;
        final delayMs = ((vo.startSec - correction) * 1000)
            .round()
            .clamp(0, 999999);
        final fadeSt = (frameDurations[vo.frameIdx] - 0.15)
            .clamp(0.0, double.infinity);
        filters.write('[${vo.inputIdx}:a]'
            'adelay=$delayMs|$delayMs,'
            'afade=t=out:st=${fadeSt.toStringAsFixed(3)}:d=0.15'
            '[vod${vo.frameIdx}];');
        labels.add('[vod${vo.frameIdx}]');
      }
      for (final sa in sourceAudios) {
        final lbl = 'src${sa.frameIdx}';
        filters.write(clipFilter(
          inputIdx: sa.inputIdx,
          frameIdx: sa.frameIdx,
          startSec: sa.startSec,
          speed: sa.speed,
          label: lbl,
        ));
        labels.add('[$lbl]');
      }

      if (audioPath != null) {
        if (labels.length == 1) {
          filters.write('${labels.first}anull[clipmix];');
        } else {
          filters.write(
              '${labels.join()}amix=inputs=${labels.length}:duration=longest[clipmix];');
        }
        filters.write('[$musicIdx:a]volume=0.35[music];');
        filters.write(
            '[clipmix][music]amix=inputs=2:duration=longest:weights=2 1[aout]');
      } else {
        if (labels.length == 1) {
          filters.write('${labels.first}anull[aout]');
        } else {
          filters.write(
              '${labels.join()}amix=inputs=${labels.length}:duration=longest[aout]');
        }
      }
      buf.write(
          '-filter_complex "${filters.toString()}" -map "[aout]" -c:a aac -b:a 128k ');
    } else if (audioPath != null) {
      buf.write('-map ${n}:a ');
      buf.write('-c:a aac -b:a 128k '
          '-af "afade=t=in:d=0.5,afade=t=out:st=${totalDuration - 1}:d=1" ');
    }

    buf.write('-c:v libx264 -preset ultrafast -crf 23 -threads 0 -r 30 -pix_fmt yuv420p ');
    buf.write('-t $totalDuration ');
    buf.write('"$outputPath"');

    return buf.toString();
  }

  /// Build a `_StyleSpec` from whichever inputs the caller provided. If
  /// the new two-axis fields (`transitionId` + `cameraMotionId`) are
  /// present they take precedence; otherwise we decompose the legacy
  /// [styleId] via the `_specs` table. Duration is picked per-transition
  /// so e.g. `dissolve` gets its longer default while `fadewhite` stays
  /// short.
  static _StyleSpec _resolveSpec({
    required MotionStyleId styleId,
    String? transitionId,
    String? cameraMotionId,
  }) {
    // Both new-axis fields present → construct directly, no _specs lookup.
    if (transitionId != null && cameraMotionId != null) {
      return _StyleSpec(
        transitionId,
        _defaultTransitionDuration(transitionId),
        _cameraFromId(cameraMotionId),
      );
    }
    return _specs[styleId] ?? const _StyleSpec('fade', 0.5, _Motion.none);
  }

  /// Sensible default `xfade duration` for each transition. Chosen to
  /// match the old `_specs` table entries where they existed.
  static double _defaultTransitionDuration(String id) {
    switch (id) {
      case 'fade':
      case 'fadefast':
        return 0.50;
      case 'dissolve':
        return 0.60;
      case 'fadewhite':
        return 0.30;
      case 'fadeblack':
        return 0.45;
      case 'smoothleft':
      case 'smoothright':
        return 0.60;
      case 'hblur':
        return 0.45;
      case 'rectcrop':
        return 0.55;
      case 'fadegrays':
        return 0.60;
      default:
        return 0.50;
    }
  }

  static _Motion _cameraFromId(String id) {
    switch (id) {
      case 'slowZoom':
        return _Motion.zoomInStandard;
      case 'zoomInSubtle':
        return _Motion.zoomInSubtle;
      case 'kenBurnsPan':
        return _Motion.kenBurnsPan;
      case 'quickPulse':
        return _Motion.quickPulse;
      case 'popPulse':
        return _Motion.popPulse;
      case 'none':
      default:
        return _Motion.none;
    }
  }
}

class _StyleSpec {
  const _StyleSpec(this.transitionName, this.transitionDuration, this.motion);
  final String transitionName;
  final double transitionDuration;
  final _Motion motion;
}
