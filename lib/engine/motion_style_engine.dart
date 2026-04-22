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
    required List<double> frameDurations,
    // When true for an index, the image is already composited to outW×outH by Flutter.
    // FFmpeg only needs fps+format — no split/blur/scale/overlay.
    List<bool>? preComposedFlags,
    String? watermarkPath,
    String? countdownPath,
    String? qrOverlayPath,
    int outW = 720,
    int outH = 1280,
  }) {
    assert(inputPaths.isNotEmpty);
    assert(inputPaths.length == isVideo.length);
    assert(inputPaths.length == frameDurations.length);

    final spec = _specs[styleId] ?? const _StyleSpec('fade', 0.5, _Motion.none);
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
        buf.write('-ss 0 -t ${inputLen.toStringAsFixed(3)} -i "${inputPaths[i]}" ');
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
      final String motion =
          _motionFilter(spec.motion, i, frameDurations[i], outW, outH);

      if (preComposed) {
        buf.write('[$i:v]fps=30$motion,format=yuv420p[v$i]; ');
      } else if (isVideo[i]) {
        buf.write('[$i:v]split[raw${i}a][raw${i}b]; ');
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

    // Branding strip
    if (brandingPath != null) {
      buf.write('[$lastLabel][${nextIdx}:v]overlay=0:H-h:eof_action=repeat[vb]; ');
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

    final hasVoiceovers = activeVoiceovers.isNotEmpty;
    if (audioPath != null && hasVoiceovers) {
      final musicIdx = n;
      final voiceFilters = StringBuffer();
      for (final vo in activeVoiceovers) {
        // Correct for xfade overlap: each transition after the first shaves
        // `trans` seconds off the absolute timeline position.
        final correction = vo.frameIdx > 1 ? (vo.frameIdx - 1) * trans : 0.0;
        final delayMs = ((vo.startSec - correction) * 1000).round().clamp(0, 999999);
        final fadeSt = (frameDurations[vo.frameIdx] - 0.15).clamp(0.0, double.infinity);
        voiceFilters.write('[${vo.inputIdx}:a]'
            'adelay=$delayMs|$delayMs,'
            'afade=t=out:st=${fadeSt.toStringAsFixed(3)}:d=0.15'
            '[vod${vo.frameIdx}];');
      }
      final vLabels = activeVoiceovers.map((v) => '[vod${v.frameIdx}]').join();
      voiceFilters.write('${vLabels}amix=inputs=${activeVoiceovers.length}:duration=longest[vomix];');
      voiceFilters.write('[${musicIdx}:a]volume=0.35[music];');
      voiceFilters.write('[vomix][music]amix=inputs=2:duration=longest:weights=2 1[aout]');
      buf.write('-filter_complex "${voiceFilters.toString()}" -map "[aout]" -c:a aac -b:a 128k ');
    } else if (hasVoiceovers) {
      final voiceFilters = StringBuffer();
      for (final vo in activeVoiceovers) {
        final correction = vo.frameIdx > 1 ? (vo.frameIdx - 1) * trans : 0.0;
        final delayMs = ((vo.startSec - correction) * 1000).round().clamp(0, 999999);
        final fadeSt = (frameDurations[vo.frameIdx] - 0.15).clamp(0.0, double.infinity);
        voiceFilters.write('[${vo.inputIdx}:a]'
            'adelay=$delayMs|$delayMs,'
            'afade=t=out:st=${fadeSt.toStringAsFixed(3)}:d=0.15'
            '[vod${vo.frameIdx}];');
      }
      final vLabels = activeVoiceovers.map((v) => '[vod${v.frameIdx}]').join();
      if (activeVoiceovers.length == 1) {
        voiceFilters.write('${vLabels}anull[aout]');
      } else {
        voiceFilters.write('${vLabels}amix=inputs=${activeVoiceovers.length}:duration=longest[aout]');
      }
      buf.write('-filter_complex "${voiceFilters.toString()}" -map "[aout]" -c:a aac -b:a 128k ');
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
}

class _StyleSpec {
  const _StyleSpec(this.transitionName, this.transitionDuration, this.motion);
  final String transitionName;
  final double transitionDuration;
  final _Motion motion;
}
