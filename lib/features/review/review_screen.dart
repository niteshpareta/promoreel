import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/ui/haptics.dart';
import '../../core/ui/pr_badge.dart';
import '../../core/ui/pr_card.dart';
import '../../core/ui/pr_icons.dart';
import '../../core/ui/pr_section_header.dart';
import '../../core/ui/tokens.dart';
import '../../data/models/motion_style.dart';
import '../../data/models/music_track.dart';
import '../../data/models/video_project.dart';
import '../../data/services/music_library.dart';
import '../../features/shared/widgets/no_project_fallback.dart';
import '../../providers/project_provider.dart';

/// Review screen — the "before you export" preview.
///
/// Slideshow runs on a 2s loop showing each slide in sequence, with caption
/// overlay exactly as it will render. Below: editorial summary of
/// motion/music/format, three trust badges, and quick-edit shortcuts back
/// into the wizard.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      final project = ref.read(projectProvider);
      if (project == null || project.assetPaths.isEmpty) return;
      setState(() {
        _currentIndex = (_currentIndex + 1) % project.assetPaths.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectProvider);
    if (project == null) return const NoProjectFallback();

    final style =
        MotionStyle.all.firstWhere((s) => s.id == project.motionStyleId);
    final track = project.musicTrackId != null
        ? MusicLibrary.findById(project.musicTrackId!)
        : null;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                    PrSpacing.lg, 0, PrSpacing.lg, PrSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: PrSpacing.sm),
                    _Preview(project: project, index: _currentIndex),
                    const SizedBox(height: PrSpacing.lg),
                    _SummaryRow(style: style, track: track),
                    const SizedBox(height: PrSpacing.md),
                    _TrustBadges(),
                    const SizedBox(height: PrSpacing.lg),
                    PrSectionHeader(
                      kicker: 'fine cuts',
                      title: 'Last look?',
                      subtitle: 'Jump back for any final tweaks',
                    ),
                    const SizedBox(height: PrSpacing.sm),
                    _QuickEdits(),
                    const SizedBox(height: PrSpacing.lg),
                  ],
                ),
              ),
            ),
            _ExportBar(),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          PrSpacing.xs, PrSpacing.xs, PrSpacing.lg, PrSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(PrIcons.back),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: PrSectionHeader(
              kicker: 'step 4 of 4',
              title: 'Review & export',
              subtitle: 'Previewing as it will render',
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════

class _Preview extends StatelessWidget {
  const _Preview({required this.project, required this.index});
  final VideoProject project;
  final int index;

  @override
  Widget build(BuildContext context) {
    final path =
        project.assetPaths[index.clamp(0, project.assetPaths.length - 1)];
    final caption = (index < project.frameCaptions.length)
        ? project.frameCaptions[index]
        : '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(PrRadius.xl),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.brandEmber.withValues(alpha: 0.22),
            width: 0.7,
          ),
          borderRadius: BorderRadius.circular(PrRadius.xl),
          boxShadow: [
            BoxShadow(
              color: AppColors.brandEmber.withValues(alpha: 0.08),
              blurRadius: 40,
              spreadRadius: -6,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: AspectRatio(
          aspectRatio: 9 / 16,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedSwitcher(
                duration: PrDuration.slow,
                switchInCurve: PrCurves.cinematic,
                child: File(path).existsSync()
                    ? Image.file(
                        File(path),
                        key: ValueKey(path),
                        fit: BoxFit.cover,
                      )
                    : Container(
                        key: ValueKey(path),
                        color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      ),
              ),
              // Caption overlay matches export rendering
              if (caption.isNotEmpty) ...[
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xCC000000)],
                      stops: [0.55, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  left: PrSpacing.md,
                  right: PrSpacing.md,
                  bottom: PrSpacing.lg,
                  child: Text(
                    caption,
                    style: AppTextStyles.headlineSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 8),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              // Slide dots
              if (project.assetPaths.length > 1)
                Positioned(
                  top: PrSpacing.sm,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      project.assetPaths.length,
                      (i) => AnimatedContainer(
                        duration: PrDuration.fast,
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        width: i == index ? 22 : 6,
                        height: 5,
                        decoration: BoxDecoration(
                          color: i == index
                              ? AppColors.brandEmber
                              : Colors.white.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
              // Editorial "frame X of Y" label
              Positioned(
                top: PrSpacing.md,
                right: PrSpacing.md,
                child: PrBadge(
                  label: '${index + 1} / ${project.assetPaths.length}',
                  tone: PrBadgeTone.neutral,
                  dense: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.style, required this.track});
  final MotionStyle style;
  final MusicTrack? track;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            icon: PrIcons.sparkle,
            kicker: 'MOTION',
            value: style.nameEn,
          ),
        ),
        const SizedBox(width: PrSpacing.xs),
        Expanded(
          child: _SummaryTile(
            icon: track != null ? PrIcons.music : Icons.music_off_rounded,
            kicker: 'SOUND',
            value: track?.nameEn ?? 'Silent',
            muted: track == null,
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.kicker,
    required this.value,
    this.muted = false,
  });
  final IconData icon;
  final String kicker;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final accent = muted
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : AppColors.brandEmber;
    return PrCard(
      variant: PrCardVariant.surface,
      padding: const EdgeInsets.all(PrSpacing.sm + 2),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(PrRadius.sm),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: PrSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(kicker, style: AppTextStyles.kicker),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════

class _TrustBadges extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: _TrustTile(
                icon: Icons.data_usage_rounded, label: '~8 MB')),
        const SizedBox(width: PrSpacing.xs),
        Expanded(
            child: _TrustTile(
                icon: PrIcons.whatsapp, label: 'WhatsApp\nready')),
      ],
    );
  }
}

class _TrustTile extends StatelessWidget {
  const _TrustTile({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: PrSpacing.sm + 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(PrRadius.md),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 0.7),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.signalLeaf, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 10.5,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════

class _QuickEdits extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PrCard(
      variant: PrCardVariant.surface,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _QuickEditTile(
            icon: PrIcons.text,
            label: 'Captions & prices',
            onTap: () => context.push(AppRoutes.captionWizard),
          ),
          Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
          _QuickEditTile(
            icon: PrIcons.sparkle,
            label: 'Motion style',
            onTap: () => context.push(AppRoutes.stylePicker),
          ),
        ],
      ),
    );
  }
}

class _QuickEditTile extends StatelessWidget {
  const _QuickEditTile(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        PrHaptics.tap();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: PrSpacing.md, vertical: PrSpacing.sm + 2),
        child: Row(
          children: [
            Icon(icon, color: AppColors.brandEmber, size: 20),
            const SizedBox(width: PrSpacing.sm + 2),
            Expanded(
                child: Text(label, style: AppTextStyles.bodyLarge)),
            Icon(PrIcons.chevronRight,
                color: Theme.of(context).colorScheme.onSurfaceVariant, size: 18),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════

class _ExportBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            PrSpacing.md, PrSpacing.xs, PrSpacing.md, PrSpacing.md),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(PrRadius.md),
            onTap: () {
              PrHaptics.commit();
              context.push(AppRoutes.export);
            },
            child: Ink(
              height: 58,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                ),
                borderRadius: BorderRadius.circular(PrRadius.md),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF25D366).withValues(alpha: 0.25),
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
                    const Icon(Icons.chat_rounded,
                        color: Colors.white, size: 20),
                    const SizedBox(width: PrSpacing.xs + 2),
                    Text(
                      'Export & share',
                      style: AppTextStyles.labelLarge
                          .copyWith(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
