import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/ui/haptics.dart';
import '../../data/models/badge_style.dart';
import '../../data/models/branding_preset.dart';
import '../../data/models/caption_style.dart';
import '../../data/models/motion_style.dart';
import '../../data/models/video_project.dart';
import '../../data/services/music_library.dart';
import '../../engine/badge_painter.dart';
import '../../engine/text_renderer.dart' show googleFontsStyleFor;

/// Full-timeline WYSIWYG preview. Plays the whole project in real time —
/// slides with their motion styles, xfade transitions, caption entrances,
/// background music, per-frame voiceovers, plus the static branding /
/// countdown / QR overlays — without touching FFmpeg.
///
/// The math mirrors `MotionStyleEngine` and the renderer so what users see
/// here is what the exported MP4 will produce. Intended for use inside a
/// fullscreen Dialog; [onClose] is wired to a top-right close chip.
class TimelinePlayer extends StatefulWidget {
  const TimelinePlayer({
    super.key,
    required this.project,
    this.branding,
    this.onClose,
  });

  final VideoProject project;
  final BrandingPreset? branding;
  final VoidCallback? onClose;

  @override
  State<TimelinePlayer> createState() => _TimelinePlayerState();
}

class _TimelinePlayerState extends State<TimelinePlayer>
    with SingleTickerProviderStateMixin {
  // ── Timing ─────────────────────────────────────────────────────────────
  late AnimationController _timeline;

  /// Start time (seconds) of each slide's presence in the compiled timeline
  /// accounting for xfade overlap. Slide i is visible from `_slideStart[i]`
  /// to `_slideStart[i] + d[i]`.
  late List<double> _slideStart;

  /// Original per-slide duration in seconds (`project.frameDurations`).
  late List<double> _slideDur;

  /// Transition duration in seconds (from the active motion style's spec).
  late double _transDur;

  /// Active transition id — 'fade' / 'slideup' / 'slideleft' / 'circleopen' /
  /// 'fadewhite' / 'wipeleft' / 'dissolve' / …
  late String _transId;

  /// Per-slide camera motion (shared across all slides in this project).
  late _CameraMotion _camera;

  /// Total runtime of the compiled video.
  double _totalDur = 0.0;

  // ── Audio ──────────────────────────────────────────────────────────────
  final AudioPlayer _music = AudioPlayer();
  final AudioPlayer _voice = AudioPlayer();

  /// Voiceover currently queued for each slide index. Used so we only
  /// schedule a voiceover once per slide (re-entering the same slide on
  /// replay re-plays it).
  int? _lastVoiceSlide;

  // ── Video thumbs ───────────────────────────────────────────────────────
  final Map<String, Uint8List?> _thumbCache = {};

  @override
  void initState() {
    super.initState();
    _computeTimings();
    _timeline = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_totalDur * 1000).round()),
    )..addListener(_onTick);
    _startPlayback();
  }

  @override
  void dispose() {
    _timeline.removeListener(_onTick);
    _timeline.dispose();
    _music.dispose();
    _voice.dispose();
    super.dispose();
  }

  // ── Timeline math ──────────────────────────────────────────────────────

  void _computeTimings() {
    final p = widget.project;
    final n = p.assetPaths.length;
    _slideDur = List.generate(
      n,
      (i) => (i < p.frameDurations.length ? p.frameDurations[i] : 3).toDouble(),
    );
    final spec = _lookupStyleSpec(p.motionStyleId);
    _transId = spec.transition;
    _transDur = spec.transDurSec;
    _camera = spec.camera;

    _slideStart = List<double>.filled(n, 0);
    double acc = 0;
    for (int i = 0; i < n; i++) {
      _slideStart[i] = acc;
      acc += _slideDur[i];
      if (i < n - 1) acc -= _transDur; // xfade overlaps this much
    }
    _totalDur = math.max(0.5, acc);
  }

  /// Current time in the compiled timeline (seconds).
  double get _tSec => _timeline.value * _totalDur;

  /// Latest slide whose start ≤ t. During a transition this is the INCOMING
  /// slide (since transitions begin at `_slideStart[i+1]`).
  int _slideAt(double t) {
    for (int i = _slideStart.length - 1; i >= 0; i--) {
      if (t >= _slideStart[i]) return i;
    }
    return 0;
  }

  /// If a cross-transition is in progress AT time [t] bringing slide [i] in
  /// (outgoing = i−1), returns `(progress 0→1, outgoing, incoming)`.
  /// Otherwise null.
  _Transition? _transInfo(double t, int i) {
    if (i == 0) return null;
    final transStart = _slideStart[i];
    final transEnd = transStart + _transDur;
    if (t < transStart || t >= transEnd) return null;
    final progress = ((t - transStart) / _transDur).clamp(0.0, 1.0);
    return _Transition(
      progress: progress,
      outgoing: i - 1,
      incoming: i,
    );
  }

  // ── Audio ──────────────────────────────────────────────────────────────

  Future<void> _startPlayback() async {
    final p = widget.project;
    final trackId = p.musicTrackId;
    if (trackId != null) {
      final track = MusicLibrary.findById(trackId);
      if (track != null) {
        try {
          await _music.setReleaseMode(ReleaseMode.loop);
          await _music.play(AssetSource(
              // `audioplayers` AssetSource is relative to `assets/`.
              track.assetPath.replaceFirst('assets/', '')));
        } catch (_) {
          // Best-effort — preview continues silently if music fails to load.
        }
      }
    }
    _timeline.forward();
  }

  Future<void> _pause() async {
    if (_timeline.isAnimating) {
      _timeline.stop();
      await _music.pause();
      await _voice.pause();
    } else {
      // At end — rewind.
      if (_timeline.value >= 1.0) {
        _timeline.value = 0;
        _lastVoiceSlide = null;
        await _music.resume();
      } else {
        await _music.resume();
      }
      _timeline.forward();
    }
    setState(() {});
  }

  Future<void> _replay() async {
    _timeline.stop();
    _timeline.value = 0;
    _lastVoiceSlide = null;
    await _music.stop();
    await _voice.stop();
    await _startPlayback();
    setState(() {});
  }

  void _onTick() {
    final t = _tSec;
    final slide = _slideAt(t);
    // Fire the per-slide voiceover once on each entry into a slide.
    if (slide != _lastVoiceSlide) {
      _lastVoiceSlide = slide;
      final vo = slide < widget.project.frameVoiceovers.length
          ? widget.project.frameVoiceovers[slide]
          : null;
      if (vo != null && vo.isNotEmpty && File(vo).existsSync()) {
        _voice.stop();
        _voice.play(DeviceFileSource(vo));
      } else {
        _voice.stop();
      }
    }
    setState(() {});
  }

  // ── Render ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = _tSec;
    final i = _slideAt(t);
    final trans = _transInfo(t, i);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (trans != null) ...[
          // Outgoing slide — transition-out wrapper applied.
          _transitionWrapper(
            transId: _transId,
            progress: trans.progress,
            incoming: false,
            child: _slideContent(trans.outgoing, t),
          ),
          // Incoming slide — transition-in wrapper applied.
          _transitionWrapper(
            transId: _transId,
            progress: trans.progress,
            incoming: true,
            child: _slideContent(trans.incoming, t),
          ),
          if (_transId == 'fadewhite')
            IgnorePointer(
              child: Opacity(
                // Triangle peak at mid-transition: 0 → 1 → 0.
                opacity:
                    (1 - (trans.progress * 2 - 1).abs()).clamp(0.0, 1.0),
                child: Container(color: Colors.white),
              ),
            ),
        ] else
          _slideContent(i, t),

        // Static overlays — countdown, branding, QR. Rendered once on top
        // of whichever slide(s) are visible.
        if (widget.project.countdownEnabled &&
            (widget.project.countdownText?.isNotEmpty ?? false))
          _countdownStrip(widget.project.countdownText!),
        if (widget.project.qrEnabled &&
            (widget.project.qrData?.isNotEmpty ?? false))
          _qrOverlay(widget.project.qrData!, widget.project.qrPosition),
        if (widget.branding != null) _brandingStrip(widget.branding!),

        // Playback controls.
        _controls(t),
        if (widget.onClose != null)
          Positioned(
            top: 12,
            right: 12,
            child: GestureDetector(
              onTap: widget.onClose,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
          ),
      ],
    );
  }

  /// Render just slide [i]'s visual content — image with its motion-style
  /// transform, styled caption, and offer badge. No transition wrapping
  /// here; the caller applies that at the outer level.
  Widget _slideContent(int i, double t) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _motionWrappedBackground(i, t),
        _captionLayer(i, t),
        _badgeLayer(i, t),
      ],
    );
  }

  Widget _badgeLayer(int i, double t) {
    final p = widget.project;
    final label = i < p.frameOfferBadges.length ? p.frameOfferBadges[i] : '';
    if (label.isEmpty) return const SizedBox.shrink();
    final style = p.resolvedOfferBadgeStyleFor(i);
    final anim = p.offerBadgeAnimFor(i);
    final tLocal = (t - _slideStart[i]).clamp(0.0, double.infinity);
    final animDur = _badgeAnimDur(anim);
    final progress = animDur <= 0
        ? 1.0
        : (tLocal / animDur).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Align(
        alignment: Alignment.topLeft,
        child: _applyBadgeEntrance(
          animStyle: anim,
          progress: progress,
          child: StyledBadge(
            style: style,
            text: label.replaceAll(' 🔥', ''),
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  double _badgeAnimDur(String style) {
    switch (style) {
      case 'pop':
      case 'slide_in':
      case 'rotate_in':
        return 0.35;
      case 'pulse':
        return 0.50;
      default:
        return 0.0;
    }
  }

  Widget _applyBadgeEntrance({
    required Widget child,
    required String animStyle,
    required double progress,
  }) {
    if (progress >= 1.0) return child;
    switch (animStyle) {
      case 'pop':
        final s = (0.5 + 0.5 * progress).clamp(0.5, 1.0);
        return Transform.scale(scale: s, child: child);
      case 'slide_in':
        return Transform.translate(
          offset: Offset((1 - progress) * -120.0, 0),
          child: child,
        );
      case 'rotate_in':
        final angle = (1 - progress) * 0.7;
        final s = (0.6 + 0.4 * progress).clamp(0.6, 1.0);
        return Transform.rotate(
          angle: -angle,
          child: Transform.scale(scale: s, child: child),
        );
      case 'pulse':
        final peak = 1 - (progress * 2 - 1).abs();
        return Transform.scale(
          scale: (1.0 + 0.2 * peak).clamp(1.0, 1.2),
          child: child,
        );
      default:
        return child;
    }
  }

  /// Apply the project's motion style to the slide's image, using the
  /// slide-local progress (`tLocal / dur`). Math mirrors
  /// `MotionStyleEngine._motionFilter`.
  Widget _motionWrappedBackground(int i, double t) {
    final tLocal = (t - _slideStart[i]).clamp(0.0, _slideDur[i]);
    final p = (tLocal / _slideDur[i]).clamp(0.0, 1.0);

    double scale = 1.0;
    double dx = 0.0;
    switch (_camera) {
      case _CameraMotion.none:
        break;
      case _CameraMotion.zoomInStandard:
        scale = 1.0 + 0.15 * p;
        break;
      case _CameraMotion.zoomInSubtle:
        scale = 1.0 + 0.08 * p;
        break;
      case _CameraMotion.kenBurnsPan:
        scale = 1.15;
        // Image is scaled 1.15× of the viewport. Translating the IMAGE
        // right reveals the LEFT portion through the viewport, and vice
        // versa. Even slide pans left-to-right (viewport moves right
        // across the image) → image translate goes +travel → -travel.
        final leftToRight = i.isEven;
        const travel = 0.075;
        dx = leftToRight
            ? travel - 2 * travel * p
            : -travel + 2 * travel * p;
        break;
      case _CameraMotion.quickPulse:
        final k = (math.min(tLocal, 0.3) / 0.3).clamp(0.0, 1.0);
        scale = 1.05 - 0.05 * k;
        break;
      case _CameraMotion.popPulse:
        final k = (math.min(tLocal, 0.45) / 0.45).clamp(0.0, 1.0);
        scale = 1.12 - 0.12 * k;
        break;
    }

    return LayoutBuilder(builder: (ctx, box) {
      return Transform.translate(
        offset: Offset(dx * box.maxWidth, 0),
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.center,
          child: _rawBackground(i),
        ),
      );
    });
  }

  Widget _rawBackground(int i) {
    final paths = widget.project.assetPaths;
    if (paths.isEmpty) return Container(color: AppColors.bgSurfaceVariant);
    final path = paths[i.clamp(0, paths.length - 1)];

    if (path == kTextSlide) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E0A4A), Color(0xFF2D1B69), Color(0xFF0F0630)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );
    }
    if (isBeforeAfterPath(path)) {
      final parts = decodeBeforeAfter(path);
      Widget side(String p) => File(p).existsSync()
          ? Image.file(File(p), fit: BoxFit.cover,
              width: double.infinity, height: double.infinity)
          : Container(color: AppColors.bgSurfaceVariant);
      return Row(
        children: [
          Expanded(child: ClipRect(child: side(parts[0]))),
          Container(width: 2, color: Colors.white),
          Expanded(child: ClipRect(child: side(parts[1]))),
        ],
      );
    }
    final file = File(path);
    if (!file.existsSync()) {
      return Container(color: AppColors.bgSurfaceVariant);
    }
    if (_isVideoPath(path)) {
      return FutureBuilder<Uint8List?>(
        future: _getThumb(path),
        builder: (_, snap) {
          if (snap.hasData && snap.data != null) {
            return Image.memory(snap.data!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity);
          }
          return Container(color: AppColors.bgSurfaceVariant);
        },
      );
    }
    return Image.file(file,
        fit: BoxFit.cover, width: double.infinity, height: double.infinity);
  }

  Future<Uint8List?> _getThumb(String path) async {
    if (_thumbCache.containsKey(path)) return _thumbCache[path];
    try {
      final bytes = await VideoThumbnail.thumbnailData(
        video: path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 720,
        quality: 80,
      );
      if (mounted) setState(() => _thumbCache[path] = bytes);
      return bytes;
    } catch (_) {
      return null;
    }
  }

  // ── Caption layer ──────────────────────────────────────────────────────

  Widget _captionLayer(int i, double t) {
    final p = widget.project;
    final raw = i < p.frameCaptions.length ? p.frameCaptions[i] : '';
    if (raw.isEmpty) return const SizedBox.shrink();

    final style = p.resolvedCaptionStyleFor(i);
    final uppercase = p.captionUppercaseFor(i);
    final rotation = p.captionRotationFor(i).toDouble();
    final posId = i < p.frameTextPositions.length
        ? p.frameTextPositions[i]
        : 'bottom';
    final caption = uppercase ? raw.toUpperCase() : raw;

    // Entrance progress (0 → 1) — ramps within [slideStart, slideStart + animDur].
    final animStyle = p.textAnimStyle;
    final animDur = _captionEntranceDur(animStyle);
    final tLocal = (t - _slideStart[i]).clamp(0.0, double.infinity);
    final entranceP = animDur <= 0
        ? 1.0
        : (tLocal / animDur).clamp(0.0, 1.0);

    const double fontPx = 22;
    Widget text = _styledCaption(text: caption, style: style, fontSize: fontPx);
    if (rotation != 0) {
      text = Transform.rotate(
        angle: rotation * math.pi / 180.0,
        child: text,
      );
    }
    text = _applyCaptionEntrance(
      child: text,
      progress: entranceP,
      animStyle: animStyle,
      fontSize: fontPx,
    );

    final Alignment align = switch (posId) {
      'top' => const Alignment(0, -0.75),
      'center' => Alignment.center,
      _ => const Alignment(0, 0.78),
    };
    return Align(alignment: align, child: text);
  }

  double _captionEntranceDur(String style) {
    switch (style) {
      case 'fade':
      case 'slide_up':
      case 'wipe':
        return 0.35;
      case 'pop':
        return 0.30;
      case 'typewriter':
        return 0.80;
      default:
        return 0.0;
    }
  }

  Widget _styledCaption({
    required String text,
    required CaptionStyle style,
    required double fontSize,
  }) {
    final double padH = fontSize * 0.75;
    final double padV = fontSize * 0.35;
    final double radius = fontSize * 0.7;
    return IntrinsicWidth(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
        decoration: style.pillColor != null
            ? BoxDecoration(
                color: style.pillColor,
                borderRadius: BorderRadius.circular(radius),
              )
            : null,
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: googleFontsStyleFor(style, fontSize: fontSize),
        ),
      ),
    );
  }

  Widget _applyCaptionEntrance({
    required Widget child,
    required double progress,
    required String animStyle,
    required double fontSize,
  }) {
    if (progress >= 1.0) return child;
    switch (animStyle) {
      case 'fade':
        return Opacity(opacity: progress.clamp(0, 1), child: child);
      case 'slide_up':
        return Transform.translate(
          offset: Offset(0, (1 - progress) * fontSize * 4),
          child: child,
        );
      case 'pop':
        return Transform.scale(
          scale: (0.6 + 0.4 * progress).clamp(0.6, 1.0),
          child: child,
        );
      case 'typewriter':
      case 'wipe':
        return Transform.translate(
          offset: Offset((1 - progress) * -300.0, 0),
          child: child,
        );
      default:
        return child;
    }
  }

  // ── Slide transitions ──────────────────────────────────────────────────

  /// Wraps [child] in the visual effect that corresponds to the active
  /// transition id at the given progress. `incoming=true` means this is the
  /// slide arriving; false means it's the slide leaving.
  Widget _transitionWrapper({
    required String transId,
    required double progress,
    required bool incoming,
    required Widget child,
  }) {
    // No transition in progress → render straight.
    if (progress >= 1.0 && !incoming) return child;

    switch (transId) {
      case 'fade':
      case 'dissolve':
      case 'fadewhite':
        return Opacity(
          opacity: incoming ? progress : 1 - progress,
          child: child,
        );
      case 'slideup':
        return LayoutBuilder(builder: (ctx, box) {
          final h = box.maxHeight;
          final y = incoming ? (1 - progress) * h : -progress * h;
          return Transform.translate(offset: Offset(0, y), child: child);
        });
      case 'slidedown':
        return LayoutBuilder(builder: (ctx, box) {
          final h = box.maxHeight;
          final y = incoming ? -(1 - progress) * h : progress * h;
          return Transform.translate(offset: Offset(0, y), child: child);
        });
      case 'slideleft':
        return LayoutBuilder(builder: (ctx, box) {
          final w = box.maxWidth;
          final x = incoming ? (1 - progress) * w : -progress * w;
          return Transform.translate(offset: Offset(x, 0), child: child);
        });
      case 'slideright':
        return LayoutBuilder(builder: (ctx, box) {
          final w = box.maxWidth;
          final x = incoming ? -(1 - progress) * w : progress * w;
          return Transform.translate(offset: Offset(x, 0), child: child);
        });
      case 'circleopen':
        if (!incoming) {
          // Outgoing fades; circleopen mostly reveals via the new slide.
          return Opacity(opacity: 1 - progress, child: child);
        }
        return _CircleOpen(progress: progress, child: child);
      case 'wipeleft':
        // Wipe right-to-left → the incoming is revealed left-to-right.
        if (!incoming) {
          return Opacity(opacity: 1 - progress, child: child);
        }
        return ClipRect(
          clipper: _WipeLeftClipper(progress),
          child: child,
        );
      default:
        return Opacity(
          opacity: incoming ? progress : 1 - progress,
          child: child,
        );
    }
  }

  // ── Overlay strips ─────────────────────────────────────────────────────

  Widget _countdownStrip(String text) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.85)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.access_time_rounded,
                color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(text,
                style: AppTextStyles.labelMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                )),
          ],
        ),
      ),
    );
  }

  Widget _qrOverlay(String data, String position) {
    Alignment align;
    switch (position) {
      case 'top_left':
        align = Alignment.topLeft;
        break;
      case 'top_right':
        align = Alignment.topRight;
        break;
      case 'bottom_left':
        align = Alignment.bottomLeft;
        break;
      case 'bottom_right':
      default:
        align = Alignment.bottomRight;
        break;
    }
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Align(
        alignment: align,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
          ),
          child: QrImageView(
            data: data,
            size: 72,
            backgroundColor: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _brandingStrip(BrandingPreset b) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        color: AppColors.brandingStrip,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            if (b.businessName.isNotEmpty)
              Expanded(
                child: Text(b.businessName,
                    style: AppTextStyles.labelMedium
                        .copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            if (b.phoneNumber.isNotEmpty)
              Text(b.phoneNumber,
                  style: AppTextStyles.labelSmall
                      .copyWith(color: Colors.white.withValues(alpha: 0.85))),
          ],
        ),
      ),
    );
  }

  // ── Controls ───────────────────────────────────────────────────────────

  Widget _controls(double t) {
    final isPlaying = _timeline.isAnimating;
    final atEnd = _timeline.value >= 1.0;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _timeline.value.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.brandEmber,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _controlChip(
                icon: atEnd
                    ? Icons.replay_rounded
                    : (isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded),
                label: atEnd ? 'Replay' : (isPlaying ? 'Pause' : 'Play'),
                primary: true,
                onTap: () {
                  PrHaptics.tap();
                  if (atEnd) {
                    _replay();
                  } else {
                    _pause();
                  }
                },
              ),
              const SizedBox(width: 10),
              Text(
                '${_formatTime(t)} / ${_formatTime(_totalDur)}',
                style: AppTextStyles.labelSmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _controlChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool primary = false,
  }) {
    final bg = primary
        ? AppColors.brandEmber.withValues(alpha: 0.95)
        : Colors.black.withValues(alpha: 0.6);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(double sec) {
    final s = sec.round();
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }
}

bool _isVideoPath(String path) {
  final ext = path.split('.').last.toLowerCase();
  return ['mp4', 'mov', 'avi', 'mkv', 'webm', '3gp'].contains(ext);
}

// ─────────────────────────────────────────────────────────────────────────────
// Motion style → transition + camera mapping. Hand-copied from
// `MotionStyleEngine._specs` to avoid exporting that private table. Keep
// the two in sync if styles are added.
// ─────────────────────────────────────────────────────────────────────────────

class _StyleSpec {
  const _StyleSpec(this.transition, this.transDurSec, this.camera);
  final String transition;
  final double transDurSec;
  final _CameraMotion camera;
}

enum _CameraMotion {
  none,
  zoomInStandard,
  zoomInSubtle,
  kenBurnsPan,
  quickPulse,
  popPulse,
}

_StyleSpec _lookupStyleSpec(MotionStyleId id) {
  switch (id) {
    case MotionStyleId.slowZoom:
      return const _StyleSpec('fade', 0.60, _CameraMotion.zoomInStandard);
    case MotionStyleId.kenBurnsPan:
      return const _StyleSpec('fade', 0.50, _CameraMotion.kenBurnsPan);
    case MotionStyleId.softCrossfade:
      return const _StyleSpec('dissolve', 0.80, _CameraMotion.none);
    case MotionStyleId.elegantSlide:
      return const _StyleSpec('slideup', 0.50, _CameraMotion.none);
    case MotionStyleId.quickCutBeatSync:
      return const _StyleSpec('fade', 0.10, _CameraMotion.quickPulse);
    case MotionStyleId.boldSlide:
      return const _StyleSpec('slideright', 0.35, _CameraMotion.none);
    case MotionStyleId.flashReveal:
      return const _StyleSpec('fadewhite', 0.25, _CameraMotion.none);
    case MotionStyleId.gridPop:
      return const _StyleSpec('circleopen', 0.40, _CameraMotion.popPulse);
    case MotionStyleId.splitScreenInfo:
      return const _StyleSpec('slidedown', 0.50, _CameraMotion.none);
    case MotionStyleId.bottomThirdHighlight:
      return const _StyleSpec('fade', 0.60, _CameraMotion.zoomInSubtle);
    case MotionStyleId.progressiveReveal:
      return const _StyleSpec('wipeleft', 0.70, _CameraMotion.none);
    case MotionStyleId.captionStack:
      return const _StyleSpec('slideleft', 0.50, _CameraMotion.none);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Circle-open transition — expanding circular mask. Uses a CustomClipper
// because Flutter's built-in ClipOval takes a static Rect.
// ─────────────────────────────────────────────────────────────────────────────

class _CircleOpen extends StatelessWidget {
  const _CircleOpen({required this.progress, required this.child});
  final double progress;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _CircleClipper(progress),
      child: child,
    );
  }
}

class _CircleClipper extends CustomClipper<Path> {
  const _CircleClipper(this.progress);
  final double progress;
  @override
  Path getClip(Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    // Radius goes from 0 to the half-diagonal so the reveal fully covers
    // the frame at progress=1.
    final r = progress *
        math.sqrt(size.width * size.width + size.height * size.height) / 2;
    return Path()..addOval(Rect.fromCircle(center: centre, radius: r));
  }

  @override
  bool shouldReclip(covariant _CircleClipper old) =>
      old.progress != progress;
}

/// Left-to-right reveal clipper — the clip rect grows from width 0 to full
/// width, anchored at the left edge.
class _WipeLeftClipper extends CustomClipper<Rect> {
  const _WipeLeftClipper(this.progress);
  final double progress;
  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * progress, size.height);
  @override
  bool shouldReclip(covariant _WipeLeftClipper old) =>
      old.progress != progress;
}

/// Describes an in-flight slide-to-slide cross transition.
class _Transition {
  const _Transition({
    required this.progress,
    required this.outgoing,
    required this.incoming,
  });
  final double progress;
  final int outgoing;
  final int incoming;
}
