import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/whatsapp_share.dart';
import '../../engine/media_encoder.dart';
import '../../providers/branding_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/project_provider.dart';

enum _ExportState { rendering, done, error }

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key, this.projectId = ''});
  final String projectId;

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen>
    with SingleTickerProviderStateMixin {
  _ExportState _state = _ExportState.rendering;
  double _progress = 0;
  String? _errorMessage;
  String? _doneOutputPath;
  bool _exportStarted = false;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    // Auto-start rendering immediately — no "ready" gate
    WidgetsBinding.instance.addPostFrameCallback((_) => _startExport());
  }

  Future<void> _startExport() async {
    if (_exportStarted) return;
    _exportStarted = true;
    setState(() => _state = _ExportState.rendering);

    final project = ref.read(projectProvider);
    if (project == null) {
      setState(() { _state = _ExportState.error; _errorMessage = 'Project not found.'; });
      return;
    }

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
      HapticFeedback.heavyImpact();
      ref.invalidate(videoHistoryProvider);
      // Don't reset project — user may want to edit and re-export
      setState(() {
        _state = _ExportState.done;
        _doneOutputPath = result.outputPath;
      });
    } else {
      setState(() { _state = _ExportState.error; _errorMessage = result.error; });
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
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
      await Share.shareXFiles(
        [XFile(path, mimeType: 'video/mp4', name: 'status_video.mp4')],
        subject: 'Check out my latest offer!',
      );
    }
  }

  Future<void> _openEnhancement(String route) async {
    await context.push(route);
    if (mounted) _reExport();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: _RenderingView(
          state: _state,
          progress: _progress,
          errorMessage: _errorMessage,
          outputPath: _doneOutputPath,
          pulseCtrl: _pulseCtrl,
          onRetry: _reExport,
          onViewVideo: () => context.push(
            '${AppRoutes.player}?path=${Uri.encodeComponent(_doneOutputPath!)}',
          ),
          onShareWhatsApp: () => _shareVideo(_doneOutputPath!, whatsAppOnly: true),
          onShareOther: () => _shareVideo(_doneOutputPath!, whatsAppOnly: false),
          onAddCaptions: () => _openEnhancement(AppRoutes.captionWizard),
          onChangeStyle: () => _openEnhancement(AppRoutes.stylePicker),
          onNewVideo: () {
            ref.read(projectProvider.notifier).reset();
            context.go(AppRoutes.home);
          },
        ),
      ),
    );
  }
}

// ── Enhance card ──────────────────────────────────────────────────────────────

class _EnhanceCard extends StatelessWidget {
  const _EnhanceCard({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 18),
                ),
                const SizedBox(height: 7),
                Text(label,
                    style: AppTextStyles.labelSmall.copyWith(
                        fontWeight: FontWeight.w600, fontSize: 11)),
                const SizedBox(height: 2),
                Text('Tap to edit',
                    style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textDisabled, fontSize: 9)),
              ],
            ),
          ),
        ),
      );
}

// ── Rendering / done / error phase ────────────────────────────────────────────

class _RenderingView extends StatelessWidget {
  const _RenderingView({
    required this.state,
    required this.progress,
    required this.errorMessage,
    required this.outputPath,
    required this.pulseCtrl,
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
      children: [
        if (state == _ExportState.rendering)
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 8),
            child: Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: onNewVideo,
                child: const Text('Cancel',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                // Icon + status text — upper area
                const Spacer(flex: 3),
                _ProgressVisual(
                    state: state, progress: progress, pulseCtrl: pulseCtrl),
                const SizedBox(height: 28),
                _StatusText(state: state, progress: progress, error: errorMessage),
                if (state == _ExportState.done) ...[
                  const SizedBox(height: 12),
                  _SavedBadge(),
                ],
                const Spacer(flex: 2),

                // Done: enhance row + share button
                if (state == _ExportState.done) ...[
                  // Enhance options row
                  Row(
                    children: [
                      _EnhanceCard(
                        icon: Icons.title_rounded,
                        label: 'Captions',
                        onTap: onAddCaptions,
                      ),
                      const SizedBox(width: 8),
                      _EnhanceCard(
                        icon: Icons.auto_awesome_rounded,
                        label: 'Style',
                        onTap: onChangeStyle,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Primary: WhatsApp share
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: onShareWhatsApp,
                      icon: const Icon(Icons.send_rounded, size: 20),
                      label: const Text('Share to WhatsApp Status'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 6,
                        shadowColor:
                            const Color(0xFF25D366).withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Secondary row: Play + Share Other + New Video
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onViewVideo,
                          icon: const Icon(Icons.play_circle_outline_rounded,
                              size: 16),
                          label: const Text('Play'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: const BorderSide(color: AppColors.divider),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onShareOther,
                          icon: const Icon(Icons.share_rounded, size: 16),
                          label: const Text('Share…'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: const BorderSide(color: AppColors.divider),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onNewVideo,
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('New'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: const BorderSide(color: AppColors.divider),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                if (state == _ExportState.error) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: onNewVideo,
                    child: const Text('Go Home'),
                  ),
                ],

                if (state == _ExportState.rendering)
                  const SizedBox.shrink(),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressVisual extends StatelessWidget {
  const _ProgressVisual(
      {required this.state, required this.progress, required this.pulseCtrl});
  final _ExportState state;
  final double progress;
  final AnimationController pulseCtrl;

  @override
  Widget build(BuildContext context) {
    if (state == _ExportState.done) {
      return Container(
        width: 120, height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.successContainer,
          border: Border.all(color: AppColors.success, width: 2),
        ),
        child: const Icon(Icons.check_rounded, color: AppColors.success, size: 56),
      );
    }

    if (state == _ExportState.error) {
      return Container(
        width: 120, height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.errorContainer,
          border: Border.all(color: AppColors.error, width: 2),
        ),
        child: const Icon(Icons.error_outline_rounded,
            color: AppColors.error, size: 56),
      );
    }

    return AnimatedBuilder(
      animation: pulseCtrl,
      builder: (ctx, child) => Container(
        width: 220, height: 220,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            AppColors.primary.withValues(alpha: 0.08 + 0.12 * pulseCtrl.value),
            Colors.transparent,
          ]),
        ),
        child: child,
      ),
      child: Center(
        child: SizedBox(
          width: 180, height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 10,
                  backgroundColor: AppColors.divider,
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: AppTextStyles.headlineLarge.copyWith(
                      color: AppColors.primary,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'rendering',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText(
      {required this.state, required this.progress, this.error});
  final _ExportState state;
  final double progress;
  final String? error;

  @override
  Widget build(BuildContext context) => switch (state) {
        _ExportState.rendering => Column(children: [
            Text('Rendering your video...',
                style: AppTextStyles.headlineMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text('Your Status video is being created',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
          ]),
        _ExportState.done => Column(children: [
            Text('Video Ready!',
                style: AppTextStyles.headlineMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text('Your Status video is ready to share',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
          ]),
        _ExportState.error => Column(children: [
            Text('Something went wrong',
                style: AppTextStyles.headlineMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(error ?? 'Export failed. Please try again.',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
                maxLines: 3),
          ]),
      };
}

class _SavedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              color: AppColors.success, size: 16),
          const SizedBox(width: 6),
          Text('Saved to Gallery',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.success)),
        ],
      );
}

class _WatermarkBanner extends StatelessWidget {
  const _WatermarkBanner({required this.onUpgrade});
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onUpgrade,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.proGold.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: AppColors.proGold.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.workspace_premium_rounded,
                  color: AppColors.proGold, size: 15),
              const SizedBox(width: 6),
              Text('Watermark added — Upgrade to remove',
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.proGold, fontSize: 11)),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.proGold, size: 15),
            ],
          ),
        ),
      );
}
