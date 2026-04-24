import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../core/router/safe_pop.dart';
import '../../core/theme/app_colors.dart';
import 'video_crop_screen.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/ui/haptics.dart';
import '../../core/ui/pr_button.dart';
import '../../core/ui/pr_icons.dart';
import '../../core/ui/tokens.dart';
import '../../providers/project_provider.dart';

/// Full-screen video trim editor. Reached from the Slides bottom sheet
/// on the Editor screen — only shown for slides whose asset is a video.
///
/// UI:
/// 1. Video preview at the top (9:16 window, looping preview of the
///    currently-selected trim window).
/// 2. Filmstrip scrubber with two draggable handles. Left handle is
///    start, right is end. Thumbnails sampled across the full source
///    duration via `video_thumbnail`.
/// 3. Read-out of `start · end · length`.
/// 4. Save / Cancel buttons.
///
/// Save writes trim ms into `VideoProject.frameVideoTrim{Start,End}Ms`
/// through the provider and auto-matches `frameDurations[i]` to the
/// new length (ceiling seconds, min 1s).
class VideoTrimScreen extends ConsumerStatefulWidget {
  const VideoTrimScreen({super.key, required this.slideIndex});

  final int slideIndex;

  @override
  ConsumerState<VideoTrimScreen> createState() => _VideoTrimScreenState();
}

class _VideoTrimScreenState extends ConsumerState<VideoTrimScreen> {
  VideoPlayerController? _ctrl;
  bool _ready = false;
  bool _playing = false;

  /// Full clip duration in ms — populated once the controller loads.
  int _clipDurMs = 0;

  /// Current trim window.
  int _startMs = 0;
  int _endMs = 0;

  /// Per-slide rotation in degrees (0 / 90 / 180 / 270). Tap the rotate
  /// button to cycle; persisted on Save.
  int _rotation = 0;

  /// Opt-in to mixing the source video's audio into the export.
  bool _useAudio = false;

  /// Per-slide playback speed (0.5, 1.0, 2.0).
  double _speed = 1.0;

  /// Normalized crop rect [x, y, w, h] in [0, 1]. Defaults to full frame.
  List<double> _cropRect = const [0.0, 0.0, 1.0, 1.0];

  /// Filmstrip thumbnails. Nullable while async fetches complete.
  final List<Uint8List?> _thumbs = List.filled(10, null);

  /// Cached waveform PNG bytes for the whole clip. `null` while the
  /// FFmpeg extract is in flight; stays `null` if extraction fails
  /// (silent videos, codec errors) — filmstrip just renders without it.
  Uint8List? _waveform;

  /// Filmstrip horizontal zoom factor. 1× = viewport-fit (default).
  /// Higher values expand the filmstrip and scroll horizontally so the
  /// user can hit a precise trim point on a longer clip.
  double _zoom = 1.0;
  double _zoomStartValue = 1.0;
  final ScrollController _filmstripScroll = ScrollController();

  /// Keyed handle identifier being dragged (if any) — drives the
  /// "active" border colour.
  int? _draggingHandle; // 0 = start, 1 = end

  /// Last observed playback position in ms — used to throttle setState
  /// from the controller listener so we only rebuild when the playhead
  /// actually advances.
  int _lastPosMs = -1;

  /// Minimum gap between START and END handles. Class-level so both
  /// drag and nudge paths respect the same invariant.
  static const int _minGapMs = 500;

  /// Step used by the fine (±0.1s) nudge buttons.
  static const int _nudgeMsFine = 100;

  /// Step used by the coarse (±1s) nudge buttons.
  static const int _nudgeMsCoarse = 1000;

  /// During a handle drag, haptic fires whenever the handle crosses
  /// one of these ms thresholds — creates a physical "ticking" feel.
  static const int _hapticStepMs = 500;
  int? _lastHapticMs;

  @override
  void initState() {
    super.initState();
    final project = ref.read(projectProvider);
    final path = project?.assetPaths[widget.slideIndex];
    if (path == null) return;

    // Seed the trim window from persisted state if present.
    _startMs = project?.videoTrimStartMsFor(widget.slideIndex) ?? 0;
    _endMs = project?.videoTrimEndMsFor(widget.slideIndex) ?? 0;
    _rotation = project?.videoRotationFor(widget.slideIndex) ?? 0;
    _useAudio = project?.videoUseAudioFor(widget.slideIndex) ?? false;
    _speed = project?.videoSpeedFor(widget.slideIndex) ?? 1.0;
    _cropRect = project?.videoCropRectFor(widget.slideIndex) ??
        const [0.0, 0.0, 1.0, 1.0];

    _ctrl = VideoPlayerController.file(File(path))
      ..initialize().then((_) {
        if (!mounted) return;
        _clipDurMs = _ctrl!.value.duration.inMilliseconds;
        // If this slide has never been trimmed, default to the whole
        // clip. `endMs==0` is the "unset" sentinel.
        if (_endMs == 0 || _endMs > _clipDurMs) _endMs = _clipDurMs;
        if (_startMs >= _endMs) _startMs = 0;
        setState(() => _ready = true);
        _ctrl!.seekTo(Duration(milliseconds: _startMs));
        _ctrl!.addListener(_onTick);
        _loadThumbnails(path);
        _loadWaveform(path);
      });
  }

  /// Extract a waveform PNG for the full clip via FFmpeg's
  /// `showwavespic` filter. Cached in [_waveform] once ready; called
  /// once in `initState`. Silent on failure — a clip without audio
  /// simply has no waveform, and the filmstrip renders fine without.
  Future<void> _loadWaveform(String path) async {
    try {
      final tmp = await getTemporaryDirectory();
      final outPng = p.join(
          tmp.path, 'pr_wave_${DateTime.now().millisecondsSinceEpoch}.png');
      // 1200×60 gives us enough horizontal resolution for pinch-zoom.
      // Mono + white waveform so we can tint via ColorFilter at paint.
      final cmd = '-y -i "$path" '
          '-filter_complex "aformat=channel_layouts=mono,'
          'showwavespic=s=1200x60:colors=0xFFFFFF" '
          '-frames:v 1 "$outPng"';
      final session = await FFmpegKit.execute(cmd);
      final rc = await session.getReturnCode();
      if (!ReturnCode.isSuccess(rc)) return;
      final bytes = await File(outPng).readAsBytes();
      if (!mounted) return;
      setState(() => _waveform = bytes);
    } catch (_) {
      // Extraction failed — silently fall through, waveform stays null.
    }
  }

  void _onTick() {
    if (!mounted) return;
    final c = _ctrl;
    if (c == null) return;
    final posMs = c.value.position.inMilliseconds;
    if (posMs != _lastPosMs) {
      _lastPosMs = posMs;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _ctrl?.removeListener(_onTick);
    _ctrl?.dispose();
    _filmstripScroll.dispose();
    super.dispose();
  }

  void _setZoom(double next) {
    final clamped = next.clamp(1.0, 4.0);
    if (clamped == _zoom) return;
    PrHaptics.tap();
    setState(() => _zoom = clamped);
    // Re-centre the viewport on the current playhead so the zoom feels
    // anchored to where the user was looking.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_filmstripScroll.hasClients) return;
      final max = _filmstripScroll.position.maxScrollExtent;
      if (max <= 0) return;
      final posMs = (_ctrl?.value.position.inMilliseconds ?? _startMs)
          .clamp(0, _clipDurMs);
      final viewportW = _filmstripScroll.position.viewportDimension;
      final contentW = viewportW * _zoom;
      final playX = contentW * posMs / (_clipDurMs == 0 ? 1 : _clipDurMs);
      final target = (playX - viewportW / 2).clamp(0.0, max);
      _filmstripScroll.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _nudge(int which, int deltaMs) {
    PrHaptics.tap();
    setState(() {
      if (which == 0) {
        _startMs = (_startMs + deltaMs).clamp(0, _endMs - _minGapMs);
        _ctrl?.seekTo(Duration(milliseconds: _startMs));
      } else {
        _endMs = (_endMs + deltaMs).clamp(_startMs + _minGapMs, _clipDurMs);
        _ctrl?.seekTo(Duration(milliseconds: _endMs));
      }
    });
  }

  void _resetTrim() {
    PrHaptics.tap();
    setState(() {
      _startMs = 0;
      _endMs = _clipDurMs;
      _ctrl?.seekTo(Duration.zero);
    });
  }

  void _rotate() {
    PrHaptics.tap();
    setState(() => _rotation = (_rotation + 90) % 360);
  }

  Future<void> _loadThumbnails(String path) async {
    final duration = _clipDurMs;
    if (duration <= 0) return;
    for (int i = 0; i < _thumbs.length; i++) {
      final atMs = (duration * i / (_thumbs.length - 1)).round();
      try {
        final data = await VideoThumbnail.thumbnailData(
          video: path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 96,
          quality: 55,
          timeMs: atMs,
        );
        if (!mounted) return;
        if (data != null) setState(() => _thumbs[i] = data);
      } catch (_) {}
    }
  }

  void _togglePlay() {
    final c = _ctrl;
    if (c == null) return;
    if (c.value.isPlaying) {
      c.pause();
      setState(() => _playing = false);
    } else {
      // If we're past the trim end, loop back to start.
      final pos = c.value.position.inMilliseconds;
      if (pos >= _endMs - 50 || pos < _startMs) {
        c.seekTo(Duration(milliseconds: _startMs));
      }
      c.play();
      setState(() => _playing = true);
      // Poll — pause automatically when we cross the trim end. Cheap
      // heartbeat via periodic callbacks; nothing fancy.
      Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 120));
        if (!mounted || _ctrl == null) return false;
        final p = _ctrl!.value.position.inMilliseconds;
        if (!_ctrl!.value.isPlaying) return false;
        if (p >= _endMs) {
          _ctrl!.pause();
          _ctrl!.seekTo(Duration(milliseconds: _startMs));
          if (mounted) setState(() => _playing = false);
          return false;
        }
        return true;
      });
    }
  }

  void _onSave() {
    PrHaptics.commit();
    final notifier = ref.read(projectProvider.notifier);
    notifier.setFrameVideoTrim(widget.slideIndex, _startMs, _endMs);
    notifier.setFrameVideoRotation(widget.slideIndex, _rotation);
    notifier.setFrameVideoUseAudio(widget.slideIndex, _useAudio);
    notifier.setFrameVideoSpeed(widget.slideIndex, _speed);
    notifier.setFrameVideoCropRect(widget.slideIndex,
        x: _cropRect[0],
        y: _cropRect[1],
        w: _cropRect[2],
        h: _cropRect[3]);
    safePop(context);
  }

  String _fmt(int ms) {
    final s = (ms / 1000).floor();
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    final frac = ((ms % 1000) / 100).floor();
    return '$mm:$ss.$frac';
  }

  @override
  Widget build(BuildContext context) {
    final lengthMs = (_endMs - _startMs).clamp(0, _clipDurMs);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) safePop(context);
      },
      child: Scaffold(
        backgroundColor: AppColors.bgDark,
        body: SafeArea(
          child: Column(
            children: [
              _header(),
              Expanded(child: _preview()),
              if (_ready) _effectsRow(),
              if (_ready) _zoomPills(),
              if (_ready) _filmstripAndHandles(),
              if (_ready) _readout(lengthMs),
              const SizedBox(height: PrSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: PrSpacing.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: PrButton(
                        label: 'Cancel',
                        variant: PrButtonVariant.secondary,
                        onPressed: () => safePop(context),
                      ),
                    ),
                    const SizedBox(width: PrSpacing.sm),
                    Expanded(
                      flex: 2,
                      child: PrButton(
                        label: 'Save',
                        icon: PrIcons.check,
                        onPressed: _ready ? _onSave : () {},
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: PrSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final sourceSec = (_clipDurMs / 1000).toStringAsFixed(1);
    final selectionSec =
        ((_endMs - _startMs).clamp(0, _clipDurMs) / 1000).toStringAsFixed(1);
    final isTrimmed = _ready &&
        _clipDurMs > 0 &&
        (_startMs > 0 || _endMs < _clipDurMs);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          PrSpacing.xs, PrSpacing.xs, PrSpacing.sm, PrSpacing.xs),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(PrIcons.back),
            onPressed: () => safePop(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TRIM VIDEO', style: AppTextStyles.kicker),
                Text('Slide ${widget.slideIndex + 1}',
                    style: AppTextStyles.titleLarge),
                if (_ready && _clipDurMs > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      isTrimmed
                          ? '${sourceSec}s source  ·  trimmed to ${selectionSec}s'
                          : '${sourceSec}s source',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: isTrimmed
                            ? AppColors.brandEmber
                            : AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight:
                            isTrimmed ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isTrimmed)
            TextButton.icon(
              onPressed: _resetTrim,
              icon: const Icon(Icons.restart_alt_rounded, size: 16),
              label: const Text('Reset'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                textStyle: AppTextStyles.labelSmall
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  Widget _preview() {
    final c = _ctrl;
    if (c == null || !_ready) {
      return const Center(child: CircularProgressIndicator());
    }
    // When rotated 90/270 the displayed aspect ratio is the reciprocal
    // of the source's. We use the rotated aspect for the outer box so
    // the video never bleeds off the preview area.
    final srcAspect = c.value.aspectRatio;
    final sideways = _rotation == 90 || _rotation == 270;
    final displayAspect = sideways && srcAspect != 0
        ? 1.0 / srcAspect
        : srcAspect;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: PrSpacing.lg, vertical: PrSpacing.sm),
      child: Stack(
        alignment: Alignment.center,
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: AspectRatio(
              aspectRatio: displayAspect,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: c.value.size.width,
                    height: c.value.size.height,
                    child: Transform.rotate(
                      angle: _rotation * math.pi / 180.0,
                      child: VideoPlayer(c),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (!_playing)
            IgnorePointer(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 32),
              ),
            ),
          // Rotate button — top-right floating action. Each tap cycles
          // rotation by 90°. Persisted on Save alongside the trim.
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: _rotate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _rotation == 0
                        ? Colors.black.withValues(alpha: 0.55)
                        : AppColors.brandEmber.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.rotate_90_degrees_cw_rounded,
                          color: Colors.white, size: 16),
                      if (_rotation != 0) ...[
                        const SizedBox(width: 4),
                        Text('$_rotation°',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _effectsRow() {
    final hasCustomCrop = _cropRect[0] > 0.0001 || _cropRect[1] > 0.0001 ||
        _cropRect[2] < 0.9999 || _cropRect[3] < 0.9999;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          PrSpacing.lg, 2, PrSpacing.lg, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Source audio toggle
            _EffectPill(
              label: _useAudio ? 'Audio ON' : 'Audio OFF',
              icon: _useAudio
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
              active: _useAudio,
              onTap: () {
                PrHaptics.tap();
                setState(() => _useAudio = !_useAudio);
              },
            ),
            const SizedBox(width: 8),
            // Speed pills — 0.5× / 1× / 2×
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.divider, width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.speed_rounded,
                        size: 14, color: AppColors.textSecondary),
                  ),
                  for (final s in const [0.5, 1.0, 2.0])
                    _SpeedChip(
                      speed: s,
                      active: _speed == s,
                      onTap: () {
                        PrHaptics.tap();
                        setState(() => _speed = s);
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Crop
            _EffectPill(
              label: hasCustomCrop ? 'Cropped' : 'Crop',
              icon: Icons.crop_rounded,
              active: hasCustomCrop,
              onTap: _openCropEditor,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCropEditor() async {
    final c = _ctrl;
    if (c == null) return;
    PrHaptics.tap();
    final result = await Navigator.of(context).push<List<double>>(
      MaterialPageRoute(
        builder: (_) => VideoCropScreen(
          sourceAspect: c.value.aspectRatio,
          thumb: _thumbs.firstWhere((t) => t != null, orElse: () => null),
          initialRect: _cropRect,
        ),
        fullscreenDialog: true,
      ),
    );
    if (result != null && mounted) {
      setState(() => _cropRect = result);
    }
  }

  Widget _zoomPills() {
    const zooms = [1.0, 2.0, 4.0];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          PrSpacing.lg, 0, PrSpacing.lg, 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('ZOOM',
              style: AppTextStyles.kicker.copyWith(
                fontSize: 9,
                color: AppColors.textDisabled,
              )),
          const SizedBox(width: 8),
          for (final z in zooms) ...[
            _ZoomPill(
              label: '${z.toStringAsFixed(z == z.roundToDouble() ? 0 : 1)}×',
              active: _zoom == z,
              onTap: () => _setZoom(z),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  Widget _filmstripAndHandles() {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: PrSpacing.lg, vertical: PrSpacing.xs),
      child: LayoutBuilder(builder: (ctx, box) {
        const handleW = 18.0;
        // Content width scales with _zoom; viewport stays fixed so the
        // zoomed content becomes horizontally scrollable.
        final viewportW = box.maxWidth;
        final w = viewportW * _zoom;
        final trackW = w - handleW * 2; // handles own the margins
        final startX = handleW +
            (trackW * _startMs / (_clipDurMs == 0 ? 1 : _clipDurMs));
        final endX = handleW +
            (trackW * _endMs / (_clipDurMs == 0 ? 1 : _clipDurMs));
        // Playhead position — clamped so it never overshoots the track
        // even if the controller momentarily reports a position beyond
        // the trim window.
        final posMs =
            (_ctrl?.value.position.inMilliseconds ?? _startMs)
                .clamp(0, _clipDurMs);
        final playheadX = handleW +
            (trackW * posMs / (_clipDurMs == 0 ? 1 : _clipDurMs));

        void updateHandle(int which, double x) {
          final clamped = x.clamp(handleW, w - handleW);
          final frac =
              ((clamped - handleW) / (trackW == 0 ? 1 : trackW)).clamp(0.0, 1.0);
          final ms = (frac * _clipDurMs).round();
          setState(() {
            if (which == 0) {
              _startMs = ms.clamp(0, _endMs - _minGapMs);
            } else {
              _endMs = ms.clamp(_startMs + _minGapMs, _clipDurMs);
            }
            final curMs = which == 0 ? _startMs : _endMs;
            // Fire a subtle haptic each time the handle crosses a
            // half-second boundary. Makes the drag feel like it has
            // detents even though the underlying value is continuous.
            final lastBucket = _lastHapticMs == null
                ? null
                : (_lastHapticMs! ~/ _hapticStepMs);
            final curBucket = curMs ~/ _hapticStepMs;
            if (lastBucket == null || curBucket != lastBucket) {
              PrHaptics.tap();
              _lastHapticMs = curMs;
            }
            // Scrub the preview to the handle's position on move.
            _ctrl?.seekTo(Duration(milliseconds: curMs));
          });
        }

        return SizedBox(
          height: 56,
          // Two-finger pinch re-zooms the filmstrip. Single-finger
          // gestures pass through to the inner handles / tap-to-seek /
          // horizontal scroll — scale gestures need 2 pointers so they
          // don't steal handle drags.
          child: RawGestureDetector(
            gestures: {
              ScaleGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<ScaleGestureRecognizer>(
                () => ScaleGestureRecognizer(),
                (recognizer) {
                  recognizer.onStart = (d) {
                    if (d.pointerCount >= 2) _zoomStartValue = _zoom;
                  };
                  recognizer.onUpdate = (d) {
                    if (d.pointerCount < 2) return;
                    _setZoom(_zoomStartValue * d.horizontalScale);
                  };
                },
              ),
            },
            behavior: HitTestBehavior.deferToChild,
            child: SingleChildScrollView(
              controller: _filmstripScroll,
              scrollDirection: Axis.horizontal,
              physics: _zoom <= 1.0
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
              child: SizedBox(
                width: w,
                height: 56,
                child: Stack(
            children: [
              // Filmstrip thumbs
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: handleW),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Row(
                      children: [
                        for (final t in _thumbs)
                          Expanded(
                            child: t != null
                                ? Image.memory(t, fit: BoxFit.cover,
                                    gaplessPlayback: true)
                                : Container(color: AppColors.bgSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              // Waveform overlay — sits on top of the thumbs so users
              // can see volume envelope alongside visual content. Low
              // opacity + brand ember tint so it doesn't fight the
              // thumbs or the dim-out mask.
              if (_waveform != null)
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: handleW),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: 0.45,
                          child: ColorFiltered(
                            colorFilter: ColorFilter.mode(
                              AppColors.brandEmber,
                              BlendMode.srcIn,
                            ),
                            child: Image.memory(
                              _waveform!,
                              fit: BoxFit.fill,
                              gaplessPlayback: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              // Tap-to-seek — fires when the user taps the filmstrip
              // anywhere except on top of the handles (which have
              // their own GestureDetectors rendered above). Sits below
              // handles in z-order so handle taps still win in their
              // hit area.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapDown: (d) {
                    if (_clipDurMs <= 0) return;
                    final x = d.localPosition.dx;
                    final frac = ((x - handleW) /
                            (trackW == 0 ? 1 : trackW))
                        .clamp(0.0, 1.0);
                    final ms = (frac * _clipDurMs).round();
                    // Clamp inside the trim window so taps don't fling
                    // the playhead outside the region being previewed.
                    final seekMs = ms.clamp(_startMs, _endMs);
                    PrHaptics.tap();
                    _ctrl?.seekTo(Duration(milliseconds: seekMs));
                    // Nudge a rebuild so the playhead redraws even
                    // when paused (the controller listener only runs
                    // while position changes are applied).
                    setState(() {});
                  },
                ),
              ),
              // Dim-out regions outside the trim window.
              Positioned(
                left: handleW,
                top: 0,
                bottom: 0,
                width: startX - handleW,
                child: IgnorePointer(
                  child: Container(color: Colors.black.withValues(alpha: 0.55)),
                ),
              ),
              Positioned(
                left: endX,
                top: 0,
                bottom: 0,
                right: handleW,
                child: IgnorePointer(
                  child: Container(color: Colors.black.withValues(alpha: 0.55)),
                ),
              ),
              // Ember border on the trim window
              Positioned(
                left: startX,
                top: 0,
                bottom: 0,
                width: endX - startX,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.symmetric(
                        horizontal: BorderSide(
                            color: AppColors.brandEmber, width: 2),
                      ),
                    ),
                  ),
                ),
              ),
              // Playhead — thin white line that tracks playback.
              // Rendered whenever the position is inside the selected
              // window (paused or playing) so tap-to-seek has visible
              // feedback.
              if (posMs >= _startMs && posMs <= _endMs)
                Positioned(
                  left: playheadX - 1,
                  top: -2,
                  bottom: -2,
                  width: 2,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              // START handle
              Positioned(
                left: startX - handleW,
                top: 0,
                bottom: 0,
                width: handleW * 2,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (_) {
                    _lastHapticMs = null;
                    setState(() => _draggingHandle = 0);
                  },
                  onHorizontalDragUpdate: (d) =>
                      updateHandle(0, startX + d.delta.dx),
                  onHorizontalDragEnd: (_) =>
                      setState(() => _draggingHandle = null),
                  child: Center(
                    child: Container(
                      width: handleW,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.brandEmber,
                        borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(4)),
                        border: Border.all(
                          color: _draggingHandle == 0
                              ? Colors.white
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: const Center(
                        child: Icon(Icons.drag_handle_rounded,
                            color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ),
              ),
              // END handle
              Positioned(
                left: endX - handleW,
                top: 0,
                bottom: 0,
                width: handleW * 2,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (_) {
                    _lastHapticMs = null;
                    setState(() => _draggingHandle = 1);
                  },
                  onHorizontalDragUpdate: (d) =>
                      updateHandle(1, endX + d.delta.dx),
                  onHorizontalDragEnd: (_) =>
                      setState(() => _draggingHandle = null),
                  child: Center(
                    child: Container(
                      width: handleW,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.brandEmber,
                        borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(4)),
                        border: Border.all(
                          color: _draggingHandle == 1
                              ? Colors.white
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: const Center(
                        child: Icon(Icons.drag_handle_rounded,
                            color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _readout(int lengthMs) {
    final startAtMin = _startMs <= 0;
    final startAtMax = _startMs >= _endMs - _minGapMs;
    final endAtMin = _endMs <= _startMs + _minGapMs;
    final endAtMax = _endMs >= _clipDurMs;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: PrSpacing.lg, vertical: PrSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _nudgeableStat(
              label: 'START',
              value: _fmt(_startMs),
              atMin: startAtMin,
              atMax: startAtMax,
              onMinusFine: () => _nudge(0, -_nudgeMsFine),
              onPlusFine: () => _nudge(0, _nudgeMsFine),
              onMinusCoarse: () => _nudge(0, -_nudgeMsCoarse),
              onPlusCoarse: () => _nudge(0, _nudgeMsCoarse),
            ),
          ),
          Expanded(
            child: _stat(
                label: 'LENGTH', value: _fmt(lengthMs), emphasised: true),
          ),
          Expanded(
            child: _nudgeableStat(
              label: 'END',
              value: _fmt(_endMs),
              atMin: endAtMin,
              atMax: endAtMax,
              onMinusFine: () => _nudge(1, -_nudgeMsFine),
              onPlusFine: () => _nudge(1, _nudgeMsFine),
              onMinusCoarse: () => _nudge(1, -_nudgeMsCoarse),
              onPlusCoarse: () => _nudge(1, _nudgeMsCoarse),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat({
    required String label,
    required String value,
    bool emphasised = false,
  }) {
    return Column(
      children: [
        Text(label,
            style: AppTextStyles.kicker.copyWith(
              fontSize: 9,
              color: AppColors.textDisabled,
            )),
        const SizedBox(height: 2),
        Text(value,
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
              color: emphasised
                  ? AppColors.brandEmber
                  : Theme.of(context).colorScheme.onSurface,
            )),
      ],
    );
  }

  /// Stat with two nudge rows: coarse (±1s, double chevron) and fine
  /// (±0.1s, single chevron). Each side auto-disables at clip bounds
  /// so the user can't nudge past what the drag path would reject.
  Widget _nudgeableStat({
    required String label,
    required String value,
    required bool atMin,
    required bool atMax,
    required VoidCallback onMinusFine,
    required VoidCallback onPlusFine,
    required VoidCallback onMinusCoarse,
    required VoidCallback onPlusCoarse,
  }) {
    return Column(
      children: [
        Text(label,
            style: AppTextStyles.kicker.copyWith(
              fontSize: 9,
              color: AppColors.textDisabled,
            )),
        const SizedBox(height: 2),
        Text(value,
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
            )),
        const SizedBox(height: 4),
        // ±1s row (double chevron)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _NudgeBtn(
              icon: Icons.keyboard_double_arrow_left_rounded,
              onTap: atMin ? null : onMinusCoarse,
            ),
            const SizedBox(width: 6),
            _NudgeLabel(text: '1s'),
            const SizedBox(width: 6),
            _NudgeBtn(
              icon: Icons.keyboard_double_arrow_right_rounded,
              onTap: atMax ? null : onPlusCoarse,
            ),
          ],
        ),
        const SizedBox(height: 4),
        // ±0.1s row (single chevron)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _NudgeBtn(
              icon: Icons.chevron_left_rounded,
              onTap: atMin ? null : onMinusFine,
            ),
            const SizedBox(width: 6),
            _NudgeLabel(text: '0.1s'),
            const SizedBox(width: 6),
            _NudgeBtn(
              icon: Icons.chevron_right_rounded,
              onTap: atMax ? null : onPlusFine,
            ),
          ],
        ),
      ],
    );
  }
}

class _NudgeLabel extends StatelessWidget {
  const _NudgeLabel({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 28,
        child: Text(text,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSmall.copyWith(
              fontSize: 9,
              color: AppColors.textDisabled,
              fontWeight: FontWeight.w700,
            )),
      );
}

class _EffectPill extends StatelessWidget {
  const _EffectPill({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.brandEmber.withValues(alpha: 0.15)
                  : AppColors.bgElevated,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: active ? AppColors.brandEmber : AppColors.divider,
                width: active ? 1.2 : 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 14,
                    color: active
                        ? AppColors.brandEmber
                        : AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(label,
                    style: AppTextStyles.labelSmall.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: active
                          ? AppColors.brandEmber
                          : AppColors.textSecondary,
                    )),
              ],
            ),
          ),
        ),
      );
}

class _SpeedChip extends StatelessWidget {
  const _SpeedChip(
      {required this.speed, required this.active, required this.onTap});
  final double speed;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final label = speed == speed.roundToDouble()
        ? '${speed.toInt()}×'
        : '${speed.toStringAsFixed(1).replaceFirst(RegExp(r"0$"), "")}×';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: active
              ? AppColors.brandEmber.withValues(alpha: 0.85)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: active ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ZoomPill extends StatelessWidget {
  const _ZoomPill(
      {required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: active
                ? AppColors.brandEmber.withValues(alpha: 0.2)
                : AppColors.bgElevated,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active ? AppColors.brandEmber : AppColors.divider,
              width: active ? 1.2 : 0.8,
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: active ? AppColors.brandEmber : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _NudgeBtn extends StatelessWidget {
  const _NudgeBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: enabled
                ? AppColors.brandEmber.withValues(alpha: 0.15)
                : AppColors.bgSurfaceVariant.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: enabled
                  ? AppColors.brandEmber.withValues(alpha: 0.5)
                  : AppColors.divider,
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: enabled ? AppColors.brandEmber : AppColors.textDisabled,
          ),
        ),
      ),
    );
  }
}
