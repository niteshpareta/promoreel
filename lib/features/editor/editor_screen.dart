import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/router/app_router.dart';
import '../../core/ui/haptics.dart';
import '../../core/ui/pr_button.dart';
import '../../core/ui/pr_icons.dart';
import '../../core/ui/tokens.dart';
import '../../data/models/branding_preset.dart';
import '../../data/models/caption_style.dart';
import '../../data/models/export_format.dart';
import '../../data/models/motion_style.dart';
import '../../data/models/video_project.dart';
import '../../engine/text_renderer.dart' show googleFontsStyleFor;
import '../../features/overlays/countdown_sheet.dart';
import '../../features/overlays/qr_overlay_sheet.dart';
import '../../features/shared/widgets/no_project_fallback.dart';
import '../../providers/branding_provider.dart';
import '../../providers/drafts_provider.dart';
import '../../providers/project_provider.dart';
import '../preview/timeline_player.dart';
import '../voiceover/voiceover_sheet.dart';

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key, this.assetPaths = const []});
  final List<String> assetPaths;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  int _previewIndex = 0;

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectProvider);
    if (project == null) return const NoProjectFallback();

    final branding = ref.watch(brandingProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _EditorAppBar(onExport: () => context.push(AppRoutes.export)),

            // Preview canvas — full width, takes all available space
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                child: _PreviewCanvas(
                  project: project,
                  currentIndex: _previewIndex,
                  onIndexChanged: (i) => setState(() => _previewIndex = i),
                  branding: branding.businessName.isNotEmpty &&
                          project.brandingEnabled
                      ? branding
                      : null,
                ),
              ),
            ),

            // Horizontal tool strip — ALL tools visible at once
            _HorizToolStrip(
              project: project,
              brandingHasName: branding.businessName.isNotEmpty,
              onTextTap: () => context.push(AppRoutes.captionWizard),
              onBrandingTap: () {
                FocusScope.of(context).unfocus();
                if (branding.businessName.isNotEmpty) {
                  ref
                      .read(projectProvider.notifier)
                      .toggleBranding(!project.brandingEnabled);
                } else {
                  context.push(AppRoutes.branding);
                }
              },
              onSlidesTap: () => _showSlidesSheet(context),
              onQrTap: () {
                FocusScope.of(context).unfocus();
                showQrOverlaySheet(context);
              },
              onCountdownTap: () {
                FocusScope.of(context).unfocus();
                showCountdownSheet(context);
              },
              onVoiceoverTap: () {
                FocusScope.of(context).unfocus();
                showVoiceoverSheet(context, initialFrameIndex: _previewIndex);
              },
              onFormatSelect: (f) =>
                  ref.read(projectProvider.notifier).setExportFormat(f),
            ),

            // Motion style picker
            _MotionStylePicker(
              selected: project.motionStyleId,
              onSelect: (id) =>
                  ref.read(projectProvider.notifier).setMotionStyle(id),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  void _showSlidesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _SlidesBottomSheet(),
    );
  }
}

// ── App bar ───────────────────────────────────────────────────────────────────

class _EditorAppBar extends ConsumerWidget {
  const _EditorAppBar({required this.onExport});
  final VoidCallback onExport;

  Future<void> _onChangePhotos(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: const Text('Change photos?'),
        content: const Text(
          'This starts a new project with your new photos. '
          'Captions, price tags, motion style, and music will reset. '
          'Branding is kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Change'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final results = await ImagePicker().pickMultipleMedia(
      limit: AppConstants.maxAssetsPerVideo,
    );
    if (results.isEmpty) return;

    final paths = results
        .take(AppConstants.maxAssetsPerVideo)
        .map((f) => f.path)
        .toList();
    ref.read(projectProvider.notifier).startNew(paths);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.fromLTRB(
            PrSpacing.xs, PrSpacing.xs, PrSpacing.sm + 2, 0),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(PrIcons.back),
              onPressed: () => context.pop(),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('EDITOR', style: AppTextStyles.kicker),
                  Text(
                    'Cutting room',
                    style: AppTextStyles.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(PrIcons.swap),
              tooltip: 'Change photos',
              onPressed: () => _onChangePhotos(context, ref),
            ),
            IconButton(
              icon: const Icon(PrIcons.save),
              tooltip: 'Save draft',
              onPressed: () async {
                final project = ref.read(projectProvider);
                if (project == null) return;
                PrHaptics.commit();
                await ref.read(draftsProvider.notifier).save(project);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Draft saved'),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
            SizedBox(
              width: 96,
              child: PrButton(
                label: 'Export',
                icon: PrIcons.sparkle,
                size: PrButtonSize.sm,
                onPressed: onExport,
              ),
            ),
          ],
        ),
      );
}

// ── Horizontal tool strip (replaces sidebar + format picker) ─────────────────
//
// All tools in one scrollable row — nothing hidden off-screen.

class _HorizToolStrip extends StatelessWidget {
  const _HorizToolStrip({
    required this.project,
    required this.brandingHasName,
    required this.onTextTap,
    required this.onBrandingTap,
    required this.onSlidesTap,
    required this.onQrTap,
    required this.onCountdownTap,
    required this.onVoiceoverTap,
    required this.onFormatSelect,
  });

  final VideoProject project;
  final bool brandingHasName;
  final VoidCallback onTextTap;
  final VoidCallback onBrandingTap;
  final VoidCallback onSlidesTap;
  final VoidCallback onQrTap;
  final VoidCallback onCountdownTap;
  final VoidCallback onVoiceoverTap;
  final void Function(ExportFormat) onFormatSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      color: AppColors.bgSurface,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        children: [
          // ── Editing tools ──────────────────────────────────────────
          _HorizBtn(
            icon: Icons.title_rounded,
            label: 'Text',
            onTap: onTextTap,
          ),
          _HorizBtn(
            icon: Icons.photo_library_rounded,
            label: 'Slides\n${project.assetPaths.length}',
            onTap: onSlidesTap,
          ),
          _HorizBtn(
            icon: Icons.branding_watermark_rounded,
            label: 'Branding',
            onTap: onBrandingTap,
            isActive: project.brandingEnabled && brandingHasName,
          ),

          _Divider(),

          // ── Overlays ───────────────────────────────────────────────
          _HorizBtn(
            icon: Icons.qr_code_rounded,
            label: 'QR Code',
            onTap: onQrTap,
            isActive: project.qrEnabled,
          ),
          _HorizBtn(
            icon: Icons.timer_rounded,
            label: 'Urgency',
            onTap: onCountdownTap,
            isActive: project.countdownEnabled,
            activeColor: const Color(0xFFE53935),
          ),
          _HorizBtn(
            icon: Icons.mic_rounded,
            label: 'Voice',
            onTap: onVoiceoverTap,
            isActive: project.hasAnyVoiceover,
          ),

          _Divider(),

          // ── Format chips inline ────────────────────────────────────
          ...ExportFormat.values.map((f) {
            final sel = f == project.exportFormat;
            return GestureDetector(
              onTap: () => onFormatSelect(f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: sel
                      ? AppColors.primaryContainer
                      : AppColors.bgElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color:
                        sel ? AppColors.primary : AppColors.divider,
                    width: sel ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(f.icon,
                        size: 14,
                        color: sel
                            ? AppColors.primary
                            : AppColors.textSecondary),
                    const SizedBox(height: 3),
                    Text(f.label,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: sel
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight: sel
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 10,
                        )),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _HorizBtn extends StatelessWidget {
  const _HorizBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.activeColor,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 64,
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: isActive
              ? color.withValues(alpha: 0.15)
              : AppColors.bgElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? color : AppColors.divider,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 20,
                color: isActive ? color : AppColors.textPrimary),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                fontSize: 9,
                color: isActive ? color : AppColors.textSecondary,
                fontWeight:
                    isActive ? FontWeight.w700 : FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        color: AppColors.divider,
      );
}

// ── Preview canvas ────────────────────────────────────────────────────────────

bool _isVideoPath(String path) {
  final ext = path.split('.').last.toLowerCase();
  return ['mp4', 'mov', 'avi', 'mkv', 'webm', '3gp'].contains(ext);
}

class _PreviewCanvas extends StatefulWidget {
  const _PreviewCanvas({
    required this.project,
    required this.currentIndex,
    required this.onIndexChanged,
    this.branding,
  });
  final VideoProject project;
  final int currentIndex;
  final void Function(int) onIndexChanged;
  final BrandingPreset? branding;

  @override
  State<_PreviewCanvas> createState() => _PreviewCanvasState();
}

class _PreviewCanvasState extends State<_PreviewCanvas>
    with SingleTickerProviderStateMixin {
  // Cache video thumbnails: path → Uint8List
  final Map<String, Uint8List?> _thumbCache = {};

  /// Drives the entrance-animation replay on the preview. 0 → 1 during
  /// play; sits at 1 when settled so the caption appears normally.
  AnimationController? _entranceCtrl;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )
      ..addListener(() => setState(() {}))
      ..value = 1.0;
    // Auto-play on first open so users see the animation without
    // hunting for a button.
    WidgetsBinding.instance.addPostFrameCallback((_) => _replayEntrance());
  }

  @override
  void dispose() {
    _entranceCtrl?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_PreviewCanvas old) {
    super.didUpdateWidget(old);
    // Clamp index if slides were removed
    final maxIdx = widget.project.assetPaths.length - 1;
    if (widget.currentIndex > maxIdx) {
      widget.onIndexChanged(maxIdx.clamp(0, maxIdx));
    }
    // Replay when the user navigates to a different frame.
    if (old.currentIndex != widget.currentIndex) {
      _replayEntrance();
    }
  }

  void _replayEntrance() {
    final c = _entranceCtrl;
    if (c == null) return;
    c.duration = _entranceDuration(widget.project.textAnimStyle);
    c
      ..value = 0.0
      ..forward();
  }

  Duration _entranceDuration(String style) {
    switch (style) {
      case 'fade':
      case 'slide_up':
      case 'wipe':
        return const Duration(milliseconds: 350);
      case 'pop':
        return const Duration(milliseconds: 300);
      case 'typewriter':
        return const Duration(milliseconds: 800);
      default:
        return const Duration(milliseconds: 300);
    }
  }

  Future<Uint8List?> _getThumb(String path) async {
    if (_thumbCache.containsKey(path)) return _thumbCache[path];
    final bytes = await VideoThumbnail.thumbnailData(
      video: path,
      imageFormat: ImageFormat.JPEG,
      maxHeight: 640,
      quality: 75,
    );
    if (mounted) setState(() => _thumbCache[path] = bytes);
    return bytes;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = widget.project.exportFormat;
    return AspectRatio(
      aspectRatio: fmt.aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildBackground(),
            _buildCaptionOverlay(),
            if (widget.branding != null) _buildBrandingStrip(),
            if (widget.project.assetPaths.length > 1) _buildNavDots(),
            _buildPlayFullChip(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayFullChip() {
    return Positioned(
      top: 10,
      right: 10,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () {
            PrHaptics.tap();
            _openTimelinePlayer();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.brandEmber.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 18),
                SizedBox(width: 4),
                Text('Play preview',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openTimelinePlayer() {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: AspectRatio(
            aspectRatio: widget.project.exportFormat.aspectRatio,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: TimelinePlayer(
                project: widget.project,
                branding: widget.branding,
                onClose: () => Navigator.pop(dialogCtx),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBackground() {
    final paths = widget.project.assetPaths;
    if (paths.isEmpty) {
      return Container(
        color: AppColors.bgSurfaceVariant,
        child: const Center(
            child: Icon(Icons.image_rounded,
                color: AppColors.textDisabled, size: 56)),
      );
    }
    final path = paths[widget.currentIndex.clamp(0, paths.length - 1)];

    // Text-only slide
    if (path == kTextSlide) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E0A4A), Color(0xFF2D1B69), Color(0xFF0F0630)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: Icon(Icons.text_fields_rounded,
              color: Colors.white24, size: 48),
        ),
      );
    }

    // Before/After split slide
    if (isBeforeAfterPath(path)) {
      final parts = decodeBeforeAfter(path);
      Widget side(String p) => File(p).existsSync()
          ? Image.file(File(p), fit: BoxFit.cover,
              width: double.infinity, height: double.infinity)
          : Container(color: AppColors.bgSurfaceVariant,
              child: const Icon(Icons.image_rounded,
                  color: AppColors.textDisabled, size: 32));
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

    // Video file — show thumbnail with play icon
    if (_isVideoPath(path)) {
      return FutureBuilder<Uint8List?>(
        future: _getThumb(path),
        builder: (_, snap) {
          if (snap.hasData && snap.data != null) {
            return Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(snap.data!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity),
                Center(
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.5),
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 26),
                  ),
                ),
              ],
            );
          }
          return Container(
            color: AppColors.bgSurfaceVariant,
            child: const Center(
              child: Icon(Icons.videocam_rounded,
                  color: AppColors.textDisabled, size: 48),
            ),
          );
        },
      );
    }

    return Image.file(file,
        fit: BoxFit.cover, width: double.infinity, height: double.infinity);
  }

  Widget _buildCaptionOverlay() {
    final i = widget.currentIndex;
    final project = widget.project;
    final rawCaption =
        i < project.frameCaptions.length ? project.frameCaptions[i] : '';
    if (rawCaption.isEmpty) return const SizedBox.shrink();

    final uppercase = project.captionUppercaseFor(i);
    final rotation = project.captionRotationFor(i).toDouble();
    final position = i < project.frameTextPositions.length
        ? project.frameTextPositions[i]
        : 'bottom';
    final style = project.resolvedCaptionStyleFor(i);
    final caption = uppercase ? rawCaption.toUpperCase() : rawCaption;
    final animStyle = project.textAnimStyle;
    final progress = _entranceCtrl?.value ?? 1.0;

    const double fontPx = 16;
    // Map the position preset to an Align fraction. Matches the renderer
    // and caption-wizard preview.
    final Alignment align = switch (position) {
      'top' => const Alignment(0, -0.75),
      'center' => Alignment.center,
      _ => Alignment(0, widget.branding != null ? 0.65 : 0.80),
    };

    Widget caped = _styledCaption(text: caption, style: style, fontSize: fontPx);
    if (rotation != 0) {
      caped = Transform.rotate(
        angle: rotation * 3.14159265358979 / 180.0,
        child: caped,
      );
    }
    caped = _applyEntrance(
      child: caped,
      progress: progress,
      fontSize: fontPx,
      animStyle: animStyle,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        Align(alignment: align, child: caped),
        if (animStyle != 'none')
          Positioned(
            bottom: 10,
            right: 10,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () {
                  PrHaptics.tap();
                  _replayEntrance();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.brandEmber.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 16),
                      SizedBox(width: 3),
                      Text('Replay',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
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

  Widget _applyEntrance({
    required Widget child,
    required double progress,
    required double fontSize,
    required String animStyle,
  }) {
    if (progress >= 1.0) return child;
    switch (animStyle) {
      case 'fade':
        return Opacity(opacity: progress.clamp(0, 1), child: child);
      case 'slide_up':
        final dy = (1 - progress) * (fontSize * 4);
        return Transform.translate(offset: Offset(0, dy), child: child);
      case 'pop':
        final s = (0.6 + 0.4 * progress).clamp(0.6, 1.0);
        return Transform.scale(scale: s, child: child);
      case 'typewriter':
      case 'wipe':
        final dx = (1 - progress) * -300.0;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      default:
        return child;
    }
  }

  Widget _buildBrandingStrip() => Positioned(
        left: 0, right: 0, bottom: 0,
        child: Container(
          color: AppColors.brandingStrip,
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                  color: AppColors.bgSurfaceVariant,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Icon(Icons.store_rounded,
                    size: 14, color: AppColors.primary),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.branding!.businessName,
                        style: AppTextStyles.labelSmall
                            .copyWith(fontSize: 9),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (widget.branding!.phoneNumber.isNotEmpty)
                      Text(widget.branding!.phoneNumber,
                          style: AppTextStyles.labelSmall.copyWith(
                              fontSize: 8,
                              color: AppColors.textSecondary),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildNavDots() => Positioned(
        top: 10, left: 0, right: 0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.project.assetPaths.length,
            (i) => GestureDetector(
              onTap: () => widget.onIndexChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: i == widget.currentIndex ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == widget.currentIndex
                      ? Colors.white
                      : Colors.white54,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
      );
}
// ── Slides bottom sheet ───────────────────────────────────────────────────────

class _SlidesBottomSheet extends ConsumerStatefulWidget {
  const _SlidesBottomSheet();

  @override
  ConsumerState<_SlidesBottomSheet> createState() =>
      _SlidesBottomSheetState();
}

class _SlidesBottomSheetState extends ConsumerState<_SlidesBottomSheet> {
  Widget _slideThumbnail(String path, bool isText) {
    if (isText) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E0A4A), Color(0xFF2D1B69)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: const Icon(Icons.text_fields_rounded,
            color: Colors.white38, size: 20),
      );
    }
    if (isBeforeAfterPath(path)) {
      final parts = decodeBeforeAfter(path);
      Widget half(String hp) => File(hp).existsSync()
          ? Image.file(File(hp), fit: BoxFit.cover,
              width: double.infinity, height: double.infinity)
          : Container(color: AppColors.bgSurfaceVariant,
              child: const Icon(Icons.image_rounded,
                  color: AppColors.textDisabled, size: 12));
      return Row(
        children: [
          Expanded(child: ClipRect(child: half(parts[0]))),
          Container(width: 1, color: Colors.white),
          Expanded(child: ClipRect(child: half(parts[1]))),
        ],
      );
    }
    if (File(path).existsSync()) {
      return Image.file(File(path), fit: BoxFit.cover,
          width: 48, height: 72);
    }
    return Container(
        color: AppColors.bgSurfaceVariant,
        child: const Icon(Icons.broken_image_outlined,
            color: AppColors.textDisabled, size: 20));
  }

  Future<void> _showBeforeAfterPicker(
      BuildContext ctx, ProjectNotifier notifier) async {
    String? leftPath;
    String? rightPath;

    await showDialog<void>(
      context: ctx,
      barrierColor: Colors.black87,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return Dialog(
            backgroundColor: AppColors.bgSurface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Before / After Slide',
                      style: AppTextStyles.titleMedium),
                  const SizedBox(height: 6),
                  Text('Pick two images to compare side by side',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _PickSlot(
                          label: 'BEFORE',
                          path: leftPath,
                          onPick: () async {
                            final img = await ImagePicker()
                                .pickImage(source: ImageSource.gallery);
                            if (img != null) {
                              setDialogState(() => leftPath = img.path);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PickSlot(
                          label: 'AFTER',
                          path: rightPath,
                          onPick: () async {
                            final img = await ImagePicker()
                                .pickImage(source: ImageSource.gallery);
                            if (img != null) {
                              setDialogState(() => rightPath = img.path);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: leftPath != null && rightPath != null
                              ? () {
                                  notifier.addBeforeAfterSlide(
                                      leftPath!, rightPath!);
                                  Navigator.pop(dialogCtx);
                                }
                              : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Add Slide'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectProvider);
    if (project == null) return const SizedBox.shrink();

    final notifier = ref.read(projectProvider.notifier);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 16, 8),
            child: Row(
              children: [
                Text('Slides (${project.assetPaths.length}/10)',
                    style: AppTextStyles.titleMedium),
                const Spacer(),
                // Before/After slide button
                TextButton.icon(
                  onPressed: project.assetPaths.length < 10
                      ? () => _showBeforeAfterPicker(context, notifier)
                      : null,
                  icon: const Icon(Icons.compare_rounded, size: 16),
                  label: const Text('B/A'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.secondary,
                    textStyle: AppTextStyles.labelSmall
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                // Add text slide button
                TextButton.icon(
                  onPressed: project.assetPaths.length < 10
                      ? () => notifier.addTextSlide()
                      : null,
                  icon: const Icon(Icons.text_fields_rounded, size: 16),
                  label: const Text('Text'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    textStyle: AppTextStyles.labelSmall
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              scrollController: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: project.assetPaths.length,
              onReorder: (oldIdx, newIdx) =>
                  notifier.reorderFrames(oldIdx, newIdx),
              itemBuilder: (ctx, i) {
                final path = project.assetPaths[i];
                final isText = path == kTextSlide;
                final duration = i < project.frameDurations.length
                    ? project.frameDurations[i]
                    : 3;
                final caption = i < project.frameCaptions.length
                    ? project.frameCaptions[i]
                    : '';

                return Card(
                  key: ValueKey('slide_$i'),
                  margin: const EdgeInsets.only(bottom: 8),
                  color: AppColors.bgElevated,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        // Thumbnail
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 48, height: 72,
                            child: _slideThumbnail(path, isText),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isText
                                    ? 'Text Slide'
                                    : isBeforeAfterPath(path)
                                        ? 'Before/After'
                                        : 'Slide ${i + 1}',
                                style: AppTextStyles.titleSmall,
                              ),
                              if (caption.isNotEmpty)
                                Text(caption,
                                    style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text('$duration sec',
                                  style: AppTextStyles.labelSmall.copyWith(
                                      color: AppColors.textDisabled,
                                      fontSize: 10)),
                            ],
                          ),
                        ),
                        // Actions
                        Column(
                          children: [
                            // Duplicate
                            _SlideAction(
                              icon: Icons.copy_rounded,
                              tooltip: 'Duplicate',
                              onTap: project.assetPaths.length < 10
                                  ? () => notifier.duplicateFrame(i)
                                  : null,
                            ),
                            const SizedBox(height: 4),
                            // Remove
                            _SlideAction(
                              icon: Icons.delete_outline_rounded,
                              tooltip: 'Remove',
                              color: AppColors.error,
                              onTap: project.assetPaths.length > 1
                                  ? () => notifier.removeFrame(i)
                                  : null,
                            ),
                          ],
                        ),
                        const SizedBox(width: 4),
                        // Drag handle
                        const Icon(Icons.drag_handle_rounded,
                            color: AppColors.textDisabled, size: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideAction extends StatelessWidget {
  const _SlideAction(
      {required this.icon,
      required this.tooltip,
      required this.onTap,
      this.color});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: (color ?? AppColors.primary).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon,
              size: 14,
              color: onTap == null
                  ? AppColors.textDisabled
                  : (color ?? AppColors.primary)),
        ),
      );
}

// ── Before/After image pick slot ─────────────────────────────────────────────

class _PickSlot extends StatelessWidget {
  const _PickSlot(
      {required this.label, required this.path, required this.onPick});
  final String label;
  final String? path;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bgElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: path != null ? AppColors.secondary : AppColors.divider,
              width: path != null ? 2 : 1,
            ),
          ),
          child: path != null && File(path!).existsSync()
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(File(path!), fit: BoxFit.cover),
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        child: Container(
                          color: Colors.black54,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(label,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1)),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_photo_alternate_rounded,
                        color: AppColors.textSecondary, size: 28),
                    const SizedBox(height: 8),
                    Text(label,
                        style: AppTextStyles.labelSmall.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 1)),
                    const SizedBox(height: 2),
                    Text('Tap to pick',
                        style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textDisabled, fontSize: 9)),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Motion style picker ───────────────────────────────────────────────────────

class _MotionStylePicker extends ConsumerWidget {
  const _MotionStylePicker(
      {required this.selected, required this.onSelect});
  final MotionStyleId selected;
  final void Function(MotionStyleId) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Text('Motion Style',
              style: AppTextStyles.titleSmall
                  .copyWith(color: AppColors.textSecondary)),
        ),
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            itemCount: MotionStyle.all.length,
            separatorBuilder: (ctx, i) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final style = MotionStyle.all[i];
              final isSelected = style.id == selected;
              return GestureDetector(
                onTap: () => onSelect(style.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 70,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryContainer
                        : AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.divider,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_styleIcon(style.id),
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            size: 22),
                        const SizedBox(height: 4),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            style.nameEn,
                            style: AppTextStyles.labelSmall.copyWith(
                              fontSize: 9,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Per-style glyph hinting at what the motion actually does — zoom,
  /// horizontal pan, dissolve, slide-in direction, pulse, wipe, etc.
  /// Keeps each of the 12 styles visually distinct in the picker strip.
  IconData _styleIcon(MotionStyleId id) => switch (id) {
        // Default — no motion
        MotionStyleId.none => Icons.do_disturb_on_rounded,
        // Subtle family
        MotionStyleId.slowZoom => Icons.zoom_in_rounded,
        MotionStyleId.kenBurnsPan => Icons.swap_horiz_rounded,
        MotionStyleId.softCrossfade => Icons.blur_on_rounded,
        MotionStyleId.elegantSlide => Icons.north_rounded,
        // Energetic family
        MotionStyleId.quickCutBeatSync => Icons.graphic_eq_rounded,
        MotionStyleId.boldSlide => Icons.east_rounded,
        MotionStyleId.flashReveal => Icons.flash_on_rounded,
        MotionStyleId.gridPop => Icons.adjust_rounded,
        // Informational family
        MotionStyleId.splitScreenInfo => Icons.south_rounded,
        MotionStyleId.bottomThirdHighlight => Icons.subtitles_rounded,
        MotionStyleId.progressiveReveal =>
          Icons.keyboard_double_arrow_left_rounded,
        MotionStyleId.captionStack => Icons.list_alt_rounded,
      };
}
