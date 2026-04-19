import '../data/models/motion_style.dart';

/// A single per-frame text overlay with its active time window.
class FrameTextOverlay {
  const FrameTextOverlay({
    required this.path,
    required this.startSec,
    required this.endSec,
    this.animStyle = 'none',
  });
  final String path;
  final double startSec;
  final double endSec;
  final String animStyle; // 'none' | 'fade' | 'slide_up'
}

class MotionStyleEngine {
  static const Map<MotionStyleId, _StyleSpec> _specs = {
    MotionStyleId.slowZoom:             _StyleSpec('fade',       0.6),
    MotionStyleId.kenBurnsPan:          _StyleSpec('slideleft',  0.5),
    MotionStyleId.softCrossfade:        _StyleSpec('dissolve',   0.8),
    MotionStyleId.elegantSlide:         _StyleSpec('slideup',    0.5),
    MotionStyleId.quickCutBeatSync:     _StyleSpec('fade',       0.1),
    MotionStyleId.boldSlide:            _StyleSpec('slideright', 0.4),
    MotionStyleId.flashReveal:          _StyleSpec('fade',       0.3),
    MotionStyleId.gridPop:              _StyleSpec('fade',       0.4),
    MotionStyleId.splitScreenInfo:      _StyleSpec('slidedown',  0.5),
    MotionStyleId.bottomThirdHighlight: _StyleSpec('fade',       0.6),
    MotionStyleId.progressiveReveal:    _StyleSpec('fade',       0.7),
    MotionStyleId.captionStack:         _StyleSpec('slideleft',  0.5),
  };

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

    final spec = _specs[styleId] ?? const _StyleSpec('fade', 0.5);
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

      if (preComposed) {
        buf.write('[$i:v]fps=30,format=yuv420p[v$i]; ');
      } else if (isVideo[i]) {
        buf.write('[$i:v]split[raw${i}a][raw${i}b]; ');
        buf.write('[raw${i}a]scale=$outW:$outH:'
            'force_original_aspect_ratio=increase,'
            'crop=$outW:$outH,boxblur=3:1[bg$i]; ');
        buf.write('[raw${i}b]scale=$outW:$outH:'
            'force_original_aspect_ratio=decrease,'
            'setsar=1[fg$i]; ');
        buf.write('[bg$i][fg$i]overlay=(W-w)/2:(H-h)/2,'
            'fps=30,format=yuv420p[v$i]; ');
      } else {
        buf.write('[$i:v]split[raw${i}a][raw${i}b]; ');
        buf.write('[raw${i}a]scale=$outW:$outH:'
            'force_original_aspect_ratio=increase,'
            'crop=$outW:$outH,boxblur=3:1[bg$i]; ');
        buf.write('[raw${i}b]scale=$outW:$outH:'
            'force_original_aspect_ratio=decrease,'
            'setsar=1[fg$i]; ');
        buf.write('[bg$i][fg$i]overlay=(W-w)/2:(H-h)/2,'
            'fps=30,format=yuv420p[v$i]; ');
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
  const _StyleSpec(this.transitionName, this.transitionDuration);
  final String transitionName;
  final double transitionDuration;
}
