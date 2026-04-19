import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/motion_style.dart';
import '../../data/models/music_track.dart';
import '../../data/models/video_project.dart';
import '../../data/services/music_library.dart';
import '../../providers/project_provider.dart';

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
    _startSlideshow();
  }

  void _startSlideshow() {
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      final project = ref.read(projectProvider);
      if (project == null) return;
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
    if (project == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go(AppRoutes.home));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final style = MotionStyle.all.firstWhere((s) => s.id == project.motionStyleId);
    final track  = project.musicTrackId != null
        ? MusicLibrary.findById(project.musicTrackId!)
        : null;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    _buildPreview(project),
                    const SizedBox(height: 20),
                    _buildSummaryRow(style, track),
                    const SizedBox(height: 16),
                    _buildTrustBadges(),
                    const SizedBox(height: 20),
                    _buildQuickEdits(context),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            _buildExportButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.pop(),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ready!', style: AppTextStyles.titleLarge),
                Text('Preview and share your video',
                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      );

  Widget _buildPreview(VideoProject project) {
    final path = project.assetPaths[_currentIndex.clamp(0, project.assetPaths.length - 1)];
    final caption = (_currentIndex < project.frameCaptions.length)
        ? project.frameCaptions[_currentIndex]
        : '';

    return AspectRatio(
      aspectRatio: 9 / 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              child: File(path).existsSync()
                  ? Image.file(File(path), key: ValueKey(path), fit: BoxFit.cover,
                      width: double.infinity, height: double.infinity)
                  : Container(key: ValueKey(path), color: AppColors.bgElevated),
            ),
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
                left: 16, right: 16, bottom: 20,
                child: Text(
                  caption,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            if (project.assetPaths.length > 1)
              Positioned(
                top: 12, left: 0, right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    project.assetPaths.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: i == _currentIndex ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _currentIndex ? AppColors.primary : Colors.white54,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(MotionStyle style, MusicTrack? track) => Row(
        children: [
          _SummaryChip(
            icon: Icons.animation_rounded,
            label: style.nameEn,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          _SummaryChip(
            icon: track != null ? Icons.music_note_rounded : Icons.music_off_rounded,
            label: track != null ? track.nameEn : 'No Music',
            color: track != null ? AppColors.secondary : AppColors.textSecondary,
          ),
        ],
      );

  Widget _buildTrustBadges() => Row(
        children: [
          Expanded(child: _TrustBadge(icon: Icons.hd_rounded, label: '720p HD')),
          const SizedBox(width: 8),
          Expanded(child: _TrustBadge(icon: Icons.data_usage_rounded, label: '~8MB')),
          const SizedBox(width: 8),
          Expanded(child: _TrustBadge(icon: Icons.check_circle_outline_rounded, label: 'WhatsApp\nReady')),
        ],
      );

  Widget _buildQuickEdits(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            _QuickEditTile(
              icon: Icons.edit_rounded,
              label: 'Edit Captions',
              onTap: () => context.push(AppRoutes.captionWizard),
            ),
            Divider(height: 1, color: AppColors.divider),
            _QuickEditTile(
              icon: Icons.auto_awesome_rounded,
              label: 'Change Style',
              onTap: () => context.push(AppRoutes.stylePicker),
            ),
          ],
        ),
      );

  Widget _buildExportButton(BuildContext context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton.icon(
              onPressed: () => context.push(AppRoutes.export),
              icon: const Icon(Icons.send_rounded, size: 22),
              label: Text(
                'Share to WhatsApp Status',
                style: AppTextStyles.labelLarge.copyWith(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 6,
                shadowColor: const Color(0xFF25D366).withValues(alpha: 0.4),
              ),
            ),
          ),
        ),
      );
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 5),
            Text(label,
                style: AppTextStyles.labelSmall.copyWith(color: color, fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      );
}

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.success, size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 10),
                textAlign: TextAlign.center),
          ],
        ),
      );
}

class _QuickEditTile extends StatelessWidget {
  const _QuickEditTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: AppColors.primary, size: 20),
        title: Text(label, style: AppTextStyles.bodyMedium),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
        onTap: onTap,
        dense: true,
      );
}
