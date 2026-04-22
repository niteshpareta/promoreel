import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/ui/aurora_backdrop.dart';
import '../../core/ui/haptics.dart';
import '../../core/ui/pr_button.dart';
import '../../core/ui/pr_icons.dart';
import '../../core/ui/reel_mark.dart';
import '../../core/ui/tokens.dart';
import '../../core/utils/whatsapp_share.dart';
import '../../data/models/export_format.dart';
import '../../data/services/draft_service.dart';
import '../../engine/media_encoder.dart';
import '../../features/shared/widgets/platform_share_sheet.dart';
import '../../providers/branding_provider.dart';
import '../../providers/drafts_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/project_provider.dart';

enum _ExportState { chooseQuality, rendering, done, error }

/// Export screen — the moment the reel is born.
///
/// Three phases, each with its own visual language:
///
///   1. **Rendering** — an aurora-lit stage, a rotating ReelMark, and a
///      filmstrip scrubber that advances frame-by-frame with progress.
///      This is the "projector running" feel.
///
///   2. **Done** — confetti burst, double-haptic, a display-serif headline
///      ("Ready for its audience"), WhatsApp as primary CTA. The payoff.
///
///   3. **Error** — crimson ring, honest copy, retry as primary action.
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key, this.projectId = ''});
  final String projectId;

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen>
    with TickerProviderStateMixin {
  _ExportState _state = _ExportState.chooseQuality;
  double _progress = 0;
  String? _errorMessage;
  String? _doneOutputPath;
  bool _exportStarted = false;

  /// User's pick from the quality chooser. Default to Full HD since the
  /// trust-chip row now says "HD" (without the 720p qualifier) and the
  /// user's expectation is 1080p.
  ExportQuality _quality = ExportQuality.fullHd;

  /// Ambient "the engine is working" pulse — used by the aurora & reel mark.
  late final AnimationController _pulseCtrl;

  /// One-shot celebratory burst on completion (0→1 over 900ms).
  late final AnimationController _celebrateCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _celebrateCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    // Export no longer auto-starts — the user picks HD or Full HD on the
    // chooser screen first, then taps "Export" to kick things off.
  }

  Future<void> _startExport() async {
    if (_exportStarted) return;
    _exportStarted = true;
    setState(() => _state = _ExportState.rendering);

    final project = ref.read(projectProvider);
    if (project == null) {
      setState(() {
        _state = _ExportState.error;
        _errorMessage = 'Project not found.';
      });
      return;
    }

    final draftService = DraftService();
    await draftService.markRendering(project);

    await ref.read(brandingProvider.notifier).ensureLoaded();
    final branding = ref.read(brandingProvider);
    final result = await MediaEncoder.export(
      project: project,
      branding: branding.businessName.isNotEmpty ? branding : null,
      addWatermark: false,
      quality: _quality,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );

    if (!mounted) return;
    _pulseCtrl.stop();

    if (result.success) {
      // Two-stage haptic (heavy then medium) + confetti controller ignition.
      PrHaptics.success();
      _celebrateCtrl.forward(from: 0);
      await draftService.deleteDraft(project.id);
      ref.invalidate(draftsProvider);
      ref.invalidate(videoHistoryProvider);
      setState(() {
        _state = _ExportState.done;
        _doneOutputPath = result.outputPath;
      });
    } else {
      PrHaptics.warn();
      await draftService.clearRenderingFlag(project.id);
      ref.invalidate(draftsProvider);
      setState(() {
        _state = _ExportState.error;
        _errorMessage = result.error;
      });
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _celebrateCtrl.dispose();
    super.dispose();
  }

  void _reExport() {
    setState(() {
      _state = _ExportState.rendering;
      _progress = 0;
      _exportStarted = false;
    });
    _pulseCtrl.repeat(reverse: true);
    _startExport();
  }

  Future<void> _shareVideo(String path, {required bool whatsAppOnly}) async {
    if (whatsAppOnly) {
      await WhatsAppShare.shareVideo(path);
    } else {
      await showPlatformShareSheet(context, videoPath: path);
    }
  }

  /// Jump to the caption wizard or style picker, then re-render ONLY if the
  /// user actually changed something. Snapshot the project JSON before
  /// navigating; on return, diff against the current state. If identical,
  /// stay on the success screen with the existing reel rather than burning
  /// another render cycle for nothing.
  Future<void> _openEnhancement(String route) async {
    final beforeSnapshot =
        jsonEncode(ref.read(projectProvider)?.toJson() ?? {});
    await context.push(route);
    if (!mounted) return;
    final afterSnapshot =
        jsonEncode(ref.read(projectProvider)?.toJson() ?? {});
    if (beforeSnapshot == afterSnapshot) return; // no change → no re-render
    _reExport();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Ambient aurora — intensified during rendering, dialed down on done.
          Positioned.fill(
            child: AnimatedOpacity(
              duration: PrDuration.slow,
              opacity: _state == _ExportState.rendering ? 0.9 : 0.35,
              child: AuroraBackdrop(
                intensity: _state == _ExportState.rendering ? 1.2 : 0.6,
                warmHue: _state != _ExportState.error,
              ),
            ),
          ),
          SafeArea(
            child: _Phase(
              state: _state,
              progress: _progress,
              errorMessage: _errorMessage,
              outputPath: _doneOutputPath,
              pulseCtrl: _pulseCtrl,
              celebrateCtrl: _celebrateCtrl,
              quality: _quality,
              onQualityChanged: (q) {
                PrHaptics.select();
                setState(() => _quality = q);
              },
              onStartExport: () {
                PrHaptics.commit();
                setState(() => _state = _ExportState.rendering);
                _pulseCtrl.repeat(reverse: true);
                _startExport();
              },
              onRetry: _reExport,
              onViewVideo: () => context.push(
                '${AppRoutes.player}?path=${Uri.encodeComponent(_doneOutputPath!)}',
              ),
              onShareWhatsApp: () =>
                  _shareVideo(_doneOutputPath!, whatsAppOnly: true),
              onShareOther: () =>
                  _shareVideo(_doneOutputPath!, whatsAppOnly: false),
              onAddCaptions: () => _openEnhancement(AppRoutes.captionWizard),
              onChangeStyle: () => _openEnhancement(AppRoutes.stylePicker),
              onNewVideo: () {
                ref.read(projectProvider.notifier).reset();
                context.go(AppRoutes.home);
              },
            ),
          ),
          // Confetti overlay on top of everything — doesn't intercept taps.
          if (_state == _ExportState.done)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _celebrateCtrl,
                  builder: (_, __) =>
                      CustomPaint(painter: _ConfettiPainter(_celebrateCtrl.value)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Phase shell — composes status, visual, and actions
// ════════════════════════════════════════════════════════════════════════════

class _Phase extends StatelessWidget {
  const _Phase({
    required this.state,
    required this.progress,
    required this.errorMessage,
    required this.outputPath,
    required this.pulseCtrl,
    required this.celebrateCtrl,
    required this.quality,
    required this.onQualityChanged,
    required this.onStartExport,
    required this.onRetry,
    required this.onViewVideo,
    required this.onShareWhatsApp,
    required this.onShareOther,
    required this.onAddCaptions,
    required this.onChangeStyle,
    required this.onNewVideo,
  });

  final _ExportState state;
  final double progress;
  final String? errorMessage;
  final String? outputPath;
  final AnimationController pulseCtrl;
  final AnimationController celebrateCtrl;
  final ExportQuality quality;
  final ValueChanged<ExportQuality> onQualityChanged;
  final VoidCallback onStartExport;
  final VoidCallback onRetry;
  final VoidCallback onViewVideo;
  final VoidCallback onShareWhatsApp;
  final VoidCallback onShareOther;
  final VoidCallback onAddCaptions;
  final VoidCallback onChangeStyle;
  final VoidCallback onNewVideo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cancel only while rendering
        SizedBox(
          height: 56,
          child: state == _ExportState.rendering
              ? Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: PrSpacing.sm),
                    child: TextButton(
                      onPressed: onNewVideo,
                      child: const Text('Cancel'),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: PrSpacing.xxl),
            child: Column(
              children: [
                const Spacer(flex: 2),
                if (state == _ExportState.chooseQuality)
                  _QualityChooser(
                    selected: quality,
                    onChanged: onQualityChanged,
                  )
                else ...[
                  _ProgressVisual(
                    state: state,
                    progress: progress,
                    pulseCtrl: pulseCtrl,
                    celebrateCtrl: celebrateCtrl,
                    outputPath: outputPath,
                    onPlay: onViewVideo,
                  ),
                  const SizedBox(height: PrSpacing.xl),
                  _StatusText(state: state, progress: progress, error: errorMessage),
                  if (state == _ExportState.rendering)
                    Padding(
                      padding: const EdgeInsets.only(top: PrSpacing.md),
                      child: _FilmstripScrubber(progress: progress),
                    ),
                ],
                const Spacer(flex: 2),
                if (state == _ExportState.chooseQuality) ...[
                  PrButton(
                    label: 'Export · ${quality.label}',
                    icon: PrIcons.download,
                    onPressed: onStartExport,
                  ),
                  const SizedBox(height: PrSpacing.sm),
                  PrButton(
                    label: 'Back',
                    variant: PrButtonVariant.ghost,
                    onPressed: onNewVideo,
                    expand: false,
                  ),
                ],
                if (state == _ExportState.done) ...[
                  // Primary share — WhatsApp (India default destination)
                  _WhatsAppPrimaryCta(onTap: onShareWhatsApp),
                  const SizedBox(height: PrSpacing.sm),
                  // Quick-share row — Instagram / Facebook / YouTube / More.
                  // All route through the system share sheet via onShareOther
                  // today; wire platform-specific intents in a follow-up.
                  _QuickShareRow(
                    onInstagram: onShareOther,
                    onFacebook: onShareOther,
                    onYouTube: onShareOther,
                    onMore: onShareOther,
                  ),
                  const SizedBox(height: PrSpacing.md),
                  // Utility row: play, tweak, start fresh.
                  _UtilityRow(
                    onPlay: onViewVideo,
                    onTweak: onAddCaptions,
                    onTweakStyle: onChangeStyle,
                    onNew: onNewVideo,
                  ),
                ],
                if (state == _ExportState.error) ...[
                  PrButton(
                    label: 'Retry',
                    icon: PrIcons.refresh,
                    onPressed: onRetry,
                  ),
                  const SizedBox(height: PrSpacing.sm),
                  PrButton(
                    label: 'Go home',
                    variant: PrButtonVariant.ghost,
                    onPressed: onNewVideo,
                    expand: false,
                  ),
                ],
                const SizedBox(height: PrSpacing.xl),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Progress visual — rotates reel + shows big tabular percent
// ════════════════════════════════════════════════════════════════════════════

class _ProgressVisual extends StatelessWidget {
  const _ProgressVisual({
    required this.state,
    required this.progress,
    required this.pulseCtrl,
    required this.celebrateCtrl,
    this.outputPath,
    this.onPlay,
  });
  final _ExportState state;
  final double progress;
  final AnimationController pulseCtrl;
  final AnimationController celebrateCtrl;

  /// Path to the finished reel — shown as a 9:16 thumbnail in the done phase.
  final String? outputPath;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _ExportState.chooseQuality:
        // Unreached — `_Phase` branches on chooseQuality before building
        // this widget. Kept so the switch stays exhaustive.
        return const SizedBox.shrink();
      case _ExportState.done:
        return AnimatedBuilder(
          animation: celebrateCtrl,
          builder: (_, __) {
            // Scale-and-settle: 0.92 → 1.02 → 1.0 so the thumbnail lands
            // with a small bounce rather than popping in flat.
            final t = celebrateCtrl.value;
            final scale = 0.92 +
                (t < 0.7
                    ? Curves.elasticOut.transform(t / 0.7) * 0.10
                    : 0.10 - (t - 0.7) / 0.3 * 0.02);
            return Transform.scale(
              scale: scale,
              child: _ReelThumbnailHero(
                outputPath: outputPath,
                onTap: onPlay,
              ),
            );
          },
        );

      case _ExportState.error:
        return Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.signalCrimson.withValues(alpha: 0.14),
            border: Border.all(color: AppColors.signalCrimson, width: 2),
          ),
          child: Icon(PrIcons.error,
              color: AppColors.signalCrimson, size: 56),
        );

      case _ExportState.rendering:
        return AnimatedBuilder(
          animation: pulseCtrl,
          builder: (_, __) => Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppColors.brandEmber
                    .withValues(alpha: 0.10 + 0.12 * pulseCtrl.value),
                Colors.transparent,
              ]),
            ),
            child: Center(
              child: SizedBox(
                width: 196,
                height: 196,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // The progress ring — subtle, the reel is the hero
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 3,
                        backgroundColor: Theme.of(context).colorScheme.outlineVariant,
                        valueColor: AlwaysStoppedAnimation(
                          AppColors.brandEmber,
                        ),
                      ),
                    ),
                    // Rotating reel signature
                    const ReelMark(size: 128),
                    // Giant tabular percent
                    Positioned(
                      bottom: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: PrSpacing.sm,
                            vertical: PrSpacing.xxs + 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(PrRadius.pill),
                          border: Border.all(
                            color: AppColors.brandEmber
                                .withValues(alpha: 0.4),
                            width: 0.7,
                          ),
                        ),
                        child: Text(
                          '${(progress * 100).toInt()}%',
                          style: AppTextStyles.numeric.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
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
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Filmstrip scrubber — 8 sprocketed frames, amber-fills left-to-right
// ════════════════════════════════════════════════════════════════════════════

class _FilmstripScrubber extends StatelessWidget {
  const _FilmstripScrubber({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    const frameCount = 8;
    final filled = (progress * frameCount).clamp(0, frameCount.toDouble());

    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: PrSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.canvasDark,
        borderRadius: BorderRadius.circular(PrRadius.sm),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: FilmPerforation(holes: 14, height: 8),
          ),
          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: PrSpacing.xs, vertical: 2),
              child: Row(
                children: List.generate(frameCount, (i) {
                  final frameProgress = (filled - i).clamp(0, 1).toDouble();
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: frameProgress,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.brandEmberDeep,
                                AppColors.brandEmber,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: FilmPerforation(holes: 14, height: 8),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Status text — editorial serif for display, body for context
// ════════════════════════════════════════════════════════════════════════════

class _StatusText extends StatelessWidget {
  const _StatusText(
      {required this.state, required this.progress, this.error});
  final _ExportState state;
  final double progress;
  final String? error;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _ExportState.chooseQuality:
        // Unreached — handled by `_QualityChooser` in `_Phase` before this
        // widget is built.
        return const SizedBox.shrink();
      case _ExportState.rendering:
        return Column(
          children: [
            Text('NOW SHOWING', style: AppTextStyles.kicker),
            const SizedBox(height: PrSpacing.xxs + 2),
            Text('Assembling your reel',
                style: AppTextStyles.displaySmall,
                textAlign: TextAlign.center),
            const SizedBox(height: PrSpacing.xs),
            Text(
              _phaseLabel(progress),
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );
      case _ExportState.done:
        return Column(
          children: [
            Text(
              'Your reel is ready.',
              style: AppTextStyles.displaySmall.copyWith(fontSize: 24),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: PrSpacing.xs + 2),
            // Trust-chip row — reassures at the share moment: no watermark,
            // it's in the gallery, HD quality. Three quick tokens beats a
            // single "Saved to Movies/PromoReel" path that nobody reads.
            Wrap(
              alignment: WrapAlignment.center,
              spacing: PrSpacing.xs,
              runSpacing: PrSpacing.xxs + 2,
              children: const [
                _DoneChip(icon: Icons.check_circle_rounded, label: 'In your gallery'),
                _DoneChip(icon: Icons.verified_rounded, label: 'No watermark'),
              ],
            ),
          ],
        );
      case _ExportState.error:
        return Column(
          children: [
            Text('CUT.', style: AppTextStyles.kicker),
            const SizedBox(height: PrSpacing.xxs + 2),
            Text('Something went wrong',
                style: AppTextStyles.displaySmall,
                textAlign: TextAlign.center),
            const SizedBox(height: PrSpacing.xs),
            Text(
              error ?? 'Export failed. Please try again.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
            ),
          ],
        );
    }
  }

  String _phaseLabel(double p) {
    if (p < 0.1) return 'Reading photos · starting engine';
    if (p < 0.4) return 'Pre-compositing frames';
    if (p < 0.7) return 'Applying motion & transitions';
    if (p < 0.92) return 'Encoding video · almost there';
    return 'Finalising · adding to your library';
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Reel thumbnail hero — shows the finished video's first frame with a play
// overlay. This is the biggest UX upgrade of the success screen: instead of
// an abstract green tick, the user sees the thing they just made.
// ════════════════════════════════════════════════════════════════════════════

class _ReelThumbnailHero extends StatefulWidget {
  const _ReelThumbnailHero({this.outputPath, this.onTap});
  final String? outputPath;
  final VoidCallback? onTap;

  @override
  State<_ReelThumbnailHero> createState() => _ReelThumbnailHeroState();
}

class _ReelThumbnailHeroState extends State<_ReelThumbnailHero> {
  Uint8List? _thumbBytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _ReelThumbnailHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.outputPath != widget.outputPath) {
      _thumbBytes = null;
      _load();
    }
  }

  Future<void> _load() async {
    final path = widget.outputPath;
    if (path == null || !File(path).existsSync()) return;
    try {
      final data = await VideoThumbnail.thumbnailData(
        video: path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 720,
        quality: 85,
      );
      if (mounted && data != null) setState(() => _thumbBytes = data);
    } catch (_) {/* fall back to ember glow below */}
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(PrRadius.xl),
        onTap: () {
          PrHaptics.tap();
          widget.onTap?.call();
        },
        child: Container(
          width: 148,
          height: 264, // 9:16
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(PrRadius.xl),
            border: Border.all(
              color: AppColors.brandEmber.withValues(alpha: 0.55),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandEmber.withValues(alpha: 0.28),
                blurRadius: 40,
                spreadRadius: -4,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(PrRadius.xl - 1),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_thumbBytes != null)
                  Image.memory(_thumbBytes!, fit: BoxFit.cover)
                else
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF241709), Color(0xFF0A0807)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                // Subtle vignette — keeps the play button readable
                // regardless of thumbnail content
                Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.45),
                      ],
                      stops: const [0.5, 1],
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.22),
                      border:
                          Border.all(color: Colors.white, width: 1.4),
                    ),
                    child: const Icon(PrIcons.play,
                        color: Colors.white, size: 26),
                  ),
                ),
                // Success tick in the corner — matches the moment without
                // being the focal point.
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.signalLeaf,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: Colors.black, width: 1.2),
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: Colors.black, size: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// "Done" trust chip — small icon + label pill. Three of these reassure at the
// share moment: the reel is saved, it's HD, it has no watermark.
// ════════════════════════════════════════════════════════════════════════════

class _DoneChip extends StatelessWidget {
  const _DoneChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(PrRadius.pill),
        border: BorderDirectional(
          top: BorderSide(color: scheme.outlineVariant, width: 0.7),
          start: BorderSide(color: scheme.outlineVariant, width: 0.7),
          end: BorderSide(color: scheme.outlineVariant, width: 0.7),
          bottom: BorderSide(color: scheme.outlineVariant, width: 0.7),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.signalLeaf, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: scheme.onSurface,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Quick-share row — Instagram / Facebook / YouTube / More. Equal-weight
// peer destinations to WhatsApp (which is the big primary CTA above). Each
// tile is a solid-coloured circle in the platform's brand hue.
// ════════════════════════════════════════════════════════════════════════════

class _QuickShareRow extends StatelessWidget {
  const _QuickShareRow({
    required this.onInstagram,
    required this.onFacebook,
    required this.onYouTube,
    required this.onMore,
  });
  final VoidCallback onInstagram;
  final VoidCallback onFacebook;
  final VoidCallback onYouTube;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ShareCircle(
          color: const Color(0xFFE1306C),
          icon: Icons.camera_alt_rounded,
          label: 'Reels',
          onTap: onInstagram,
        ),
        _ShareCircle(
          color: const Color(0xFF1877F2),
          icon: Icons.facebook_rounded,
          label: 'Facebook',
          onTap: onFacebook,
        ),
        _ShareCircle(
          color: const Color(0xFFFF0000),
          icon: Icons.play_arrow_rounded,
          label: 'Shorts',
          onTap: onYouTube,
        ),
        _ShareCircle(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          iconColor: Theme.of(context).colorScheme.onSurface,
          icon: PrIcons.more,
          label: 'More',
          onTap: onMore,
        ),
      ],
    );
  }
}

class _ShareCircle extends StatelessWidget {
  const _ShareCircle({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        PrHaptics.tap();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 12,
                  spreadRadius: -2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: iconColor ?? Colors.white, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: AppTextStyles.labelSmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Utility row — Play fullscreen / Tweak captions / Make another. Text
// buttons so they don't compete with the share CTAs above.
// ════════════════════════════════════════════════════════════════════════════

class _UtilityRow extends StatelessWidget {
  const _UtilityRow({
    required this.onPlay,
    required this.onTweak,
    required this.onTweakStyle,
    required this.onNew,
  });
  final VoidCallback onPlay;
  final VoidCallback onTweak;
  final VoidCallback onTweakStyle;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _UtilityButton(
          icon: PrIcons.play,
          label: 'Play',
          onPressed: onPlay,
        ),
        _UtilityButton(
          icon: PrIcons.edit,
          label: 'Tweak',
          onPressed: () {
            // Open captions by default — most common tweak at success moment.
            onTweak();
          },
        ),
        _UtilityButton(
          icon: PrIcons.plus,
          label: 'Another',
          onPressed: onNew,
        ),
      ],
    );
  }
}

class _UtilityButton extends StatelessWidget {
  const _UtilityButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(PrRadius.sm),
        onTap: () {
          PrHaptics.tap();
          onPressed();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: PrSpacing.md, vertical: PrSpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: scheme.onSurfaceVariant, size: 18),
              const SizedBox(height: 3),
              Text(label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: scheme.onSurface,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// WhatsApp CTA — keeps the brand green; primary distribution channel for India
// ════════════════════════════════════════════════════════════════════════════

class _WhatsAppPrimaryCta extends StatelessWidget {
  const _WhatsAppPrimaryCta({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF25D366);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(PrRadius.md),
        onTap: () {
          PrHaptics.commit();
          onTap();
        },
        child: Ink(
          height: 54,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF25D366), Color(0xFF128C7E)],
            ),
            borderRadius: BorderRadius.circular(PrRadius.md),
            boxShadow: [
              BoxShadow(
                color: green.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 8),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.chat_rounded, color: Colors.white, size: 20),
                const SizedBox(width: PrSpacing.xs + 2),
                Text(
                  'Share to WhatsApp Status',
                  style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Confetti — lightweight one-shot particle burst
// ════════════════════════════════════════════════════════════════════════════

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t)
      : _seed = 42 // stable particle distribution
  ;
  final double t;
  final int _seed;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;

    final rnd = math.Random(_seed);
    const count = 40;

    final palette = [
      AppColors.brandEmber,
      AppColors.brandEmberDeep,
      AppColors.signalCrimson,
      AppColors.signalLeaf,
      AppColors.proAurum,
      const Color(0xFF6C5BFF),
    ];

    final originX = size.width / 2;
    final originY = size.height * 0.35;

    for (var i = 0; i < count; i++) {
      // Each particle gets a random angle, speed, spin, and color.
      final angle =
          (-math.pi / 2) + (rnd.nextDouble() - 0.5) * math.pi * 0.9;
      final speed = 320 + rnd.nextDouble() * 380;
      final gravity = 680;

      // t is 0..1; map to seconds assuming 900ms duration.
      final sec = t * 0.9;
      final x = originX + math.cos(angle) * speed * sec;
      final y = originY + math.sin(angle) * speed * sec + 0.5 * gravity * sec * sec;

      final fade = (1 - t * 1.2).clamp(0.0, 1.0);
      if (fade == 0) continue;

      final color = palette[i % palette.length].withValues(alpha: fade);
      final rot = t * 8 * math.pi * (rnd.nextDouble() - 0.5);
      final w = 6 + rnd.nextDouble() * 6;
      final h = 3 + rnd.nextDouble() * 3;

      canvas
        ..save()
        ..translate(x, y)
        ..rotate(rot);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: w, height: h),
            const Radius.circular(1.5)),
        Paint()..color = color,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}

// ════════════════════════════════════════════════════════════════════════════
// Quality chooser — two tiles with honest tradeoffs. Shown before the
// render kicks off so the user picks HD or Full HD with full context.
// ════════════════════════════════════════════════════════════════════════════

class _QualityChooser extends StatelessWidget {
  const _QualityChooser({required this.selected, required this.onChanged});

  final ExportQuality selected;
  final ValueChanged<ExportQuality> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('YOUR CUT', style: AppTextStyles.kicker),
        const SizedBox(height: PrSpacing.xxs + 2),
        Text('Pick your quality',
            style: AppTextStyles.displaySmall, textAlign: TextAlign.center),
        const SizedBox(height: PrSpacing.xs),
        Text(
          'You can always come back and re-export.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: PrSpacing.lg),
        _QualityTile(
          quality: ExportQuality.fullHd,
          selected: selected == ExportQuality.fullHd,
          onTap: () => onChanged(ExportQuality.fullHd),
        ),
        const SizedBox(height: PrSpacing.sm),
        _QualityTile(
          quality: ExportQuality.hd,
          selected: selected == ExportQuality.hd,
          onTap: () => onChanged(ExportQuality.hd),
        ),
      ],
    );
  }
}

class _QualityTile extends StatelessWidget {
  const _QualityTile({
    required this.quality,
    required this.selected,
    required this.onTap,
  });
  final ExportQuality quality;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isFullHd = quality == ExportQuality.fullHd;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(PrRadius.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: PrSpacing.md, vertical: PrSpacing.sm + 2),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.brandEmber.withValues(alpha: 0.14)
                : scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(PrRadius.md),
            border: Border.all(
              color: selected
                  ? AppColors.brandEmber
                  : scheme.outlineVariant,
              width: selected ? 1.6 : 0.8,
            ),
          ),
          child: Row(
            children: [
              // Left-side resolution badge. Uses `hd_rounded` for both and
              // differentiates via the text below it.
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.brandEmber.withValues(alpha: 0.22)
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(PrRadius.sm),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(isFullHd ? Icons.hd_rounded : Icons.sd_rounded,
                        color: selected
                            ? AppColors.brandEmber
                            : scheme.onSurfaceVariant,
                        size: 22),
                    Text(quality.resolutionLabel,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: selected
                              ? AppColors.brandEmber
                              : scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                          fontSize: 9,
                          letterSpacing: 0.3,
                        )),
                  ],
                ),
              ),
              const SizedBox(width: PrSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(quality.label,
                            style:
                                AppTextStyles.titleMedium.copyWith(
                              fontWeight: FontWeight.w800,
                            )),
                        const SizedBox(width: PrSpacing.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(quality.sizeHint,
                              style: AppTextStyles.labelSmall.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              )),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(quality.tagline,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded,
                    color: AppColors.brandEmber, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
