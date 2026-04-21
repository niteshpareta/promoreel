import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import '../../data/services/draft_service.dart';
import '../../engine/media_encoder.dart';
import '../../features/shared/widgets/platform_share_sheet.dart';
import '../../providers/branding_provider.dart';
import '../../providers/drafts_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/project_provider.dart';

enum _ExportState { rendering, done, error }

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
  _ExportState _state = _ExportState.rendering;
  double _progress = 0;
  String? _errorMessage;
  String? _doneOutputPath;
  bool _exportStarted = false;

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _startExport());
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

  Future<void> _openEnhancement(String route) async {
    await context.push(route);
    if (mounted) _reExport();
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
                _ProgressVisual(
                  state: state,
                  progress: progress,
                  pulseCtrl: pulseCtrl,
                  celebrateCtrl: celebrateCtrl,
                ),
                const SizedBox(height: PrSpacing.xl),
                _StatusText(state: state, progress: progress, error: errorMessage),
                if (state == _ExportState.rendering)
                  Padding(
                    padding: const EdgeInsets.only(top: PrSpacing.md),
                    child: _FilmstripScrubber(progress: progress),
                  ),
                const Spacer(flex: 3),
                if (state == _ExportState.done) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _EnhanceCard(
                          icon: PrIcons.text,
                          label: 'Captions',
                          onTap: onAddCaptions,
                        ),
                      ),
                      const SizedBox(width: PrSpacing.xs),
                      Expanded(
                        child: _EnhanceCard(
                          icon: PrIcons.sparkle,
                          label: 'Style',
                          onTap: onChangeStyle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: PrSpacing.md),
                  _WhatsAppPrimaryCta(onTap: onShareWhatsApp),
                  const SizedBox(height: PrSpacing.xs + 2),
                  Row(
                    children: [
                      Expanded(
                        child: PrButton(
                          label: 'Play',
                          icon: PrIcons.play,
                          variant: PrButtonVariant.secondary,
                          size: PrButtonSize.sm,
                          onPressed: onViewVideo,
                        ),
                      ),
                      const SizedBox(width: PrSpacing.xs),
                      Expanded(
                        child: PrButton(
                          label: 'Share',
                          icon: PrIcons.share,
                          variant: PrButtonVariant.secondary,
                          size: PrButtonSize.sm,
                          onPressed: onShareOther,
                        ),
                      ),
                      const SizedBox(width: PrSpacing.xs),
                      Expanded(
                        child: PrButton(
                          label: 'New',
                          icon: PrIcons.plus,
                          variant: PrButtonVariant.secondary,
                          size: PrButtonSize.sm,
                          onPressed: onNewVideo,
                        ),
                      ),
                    ],
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
  });
  final _ExportState state;
  final double progress;
  final AnimationController pulseCtrl;
  final AnimationController celebrateCtrl;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _ExportState.done:
        return AnimatedBuilder(
          animation: celebrateCtrl,
          builder: (_, __) {
            // Scale from 0.6 → 1.04 → 1.0 (elastic overshoot)
            final t = celebrateCtrl.value;
            final scale = 0.6 +
                (t < 0.7
                    ? Curves.elasticOut.transform(t / 0.7) * 0.44
                    : 0.44 - (t - 0.7) / 0.3 * 0.04);
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.signalLeaf.withValues(alpha: 0.14),
                  border: Border.all(
                      color: AppColors.signalLeaf, width: 2),
                ),
                child: Icon(
                  PrIcons.check,
                  color: AppColors.signalLeaf,
                  size: 76,
                ),
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
            Text('SCENE.  TAKE.  PRINT.',
                style: AppTextStyles.kicker.copyWith(letterSpacing: 3.2)),
            const SizedBox(height: PrSpacing.xxs + 2),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: AppTextStyles.displaySmall,
                children: [
                  const TextSpan(text: 'Ready for its '),
                  TextSpan(
                    text: 'audience.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: PrSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(PrIcons.check,
                    color: AppColors.signalLeaf, size: 16),
                const SizedBox(width: 4),
                Text('Saved to Movies/PromoReel',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.signalLeaf,
                    )),
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
// Enhance card — tap to jump back into editor for tweaks
// ════════════════════════════════════════════════════════════════════════════

class _EnhanceCard extends StatelessWidget {
  const _EnhanceCard(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(PrRadius.md),
        onTap: () {
          PrHaptics.tap();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: PrSpacing.sm + 2),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(PrRadius.md),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 0.7),
          ),
          child: Column(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.brandEmber.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.brandEmber, size: 18),
              ),
              const SizedBox(height: PrSpacing.xs),
              Text(label, style: AppTextStyles.titleSmall),
              Text('Tap to edit',
                  style: AppTextStyles.labelSmall.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 9.5)),
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
