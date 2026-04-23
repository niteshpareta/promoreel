import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../../core/constants/app_constants.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/ui/aurora_backdrop.dart';
import '../../core/ui/haptics.dart';
import '../../core/ui/pr_badge.dart';
import '../../core/ui/pr_button.dart';
import '../../core/ui/pr_card.dart';
import '../../core/ui/pr_empty_state.dart';
import '../../core/ui/pr_icons.dart';
import '../../core/ui/pr_section_header.dart';
import '../../core/ui/reel_mark.dart';
import '../../core/ui/tokens.dart';
import '../../data/models/video_project.dart';
import '../../data/services/draft_service.dart';
import '../../data/services/video_history_service.dart';
import '../../providers/drafts_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/project_provider.dart';
import '../../providers/subscription_provider.dart';
import '../shared/widgets/platform_share_sheet.dart';

/// Home screen — the front door.
///
/// Layout, top to bottom:
///   1. Masthead      (rotating reel + wordmark + settings)
///   2. Hero          (kicker, editorial headline, single CTA, ember glow)
///   3. Resume banner (only when an orphaned render exists)
///   4. Catalog card  (Product catalog mode entry)
///   5. Drafts strip  (only when drafts exist)
///   6. Recent reels  (2-col grid, or empty state with CTA)
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = ref.watch(subscriptionProvider);
    final statsAsync = ref.watch(videoHistoryProvider);
    final drafts = ref.watch(draftsProvider).valueOrNull ?? const [];
    final orphans =
        ref.watch(orphanedRendersProvider).valueOrNull ?? const <DraftRecord>[];

    return Scaffold(
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _HomeBody(
            tier: sub,
            videos: const [],
            todayCount: 0,
            drafts: drafts,
            orphans: orphans),
        data: (s) => _HomeBody(
            tier: sub,
            videos: s.videos,
            todayCount: s.todayCount,
            drafts: drafts,
            orphans: orphans),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Body
// ════════════════════════════════════════════════════════════════════════════

class _HomeBody extends StatelessWidget {
  const _HomeBody({
    required this.tier,
    required this.videos,
    required this.todayCount,
    required this.drafts,
    required this.orphans,
  });

  final SubscriptionState tier;
  final List<VideoRecord> videos;
  final int todayCount;
  final List<DraftRecord> drafts;
  final List<DraftRecord> orphans;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const _Masthead(),
        SliverToBoxAdapter(
          child: _Hero(
              tier: tier, todayCount: todayCount, recentFirst: videos.take(6).toList()),
        ),
        if (orphans.isNotEmpty)
          SliverToBoxAdapter(child: _ResumeBanner(drafts: orphans)),
        const SliverToBoxAdapter(child: _CatalogCard()),
        if (drafts.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  PrSpacing.lg, PrSpacing.xl, PrSpacing.lg, PrSpacing.sm),
              child: PrSectionHeader(
                kicker: 'unfinished',
                title: 'Drafts',
                subtitle: '${drafts.length} in progress — tap to continue',
              ),
            ),
          ),
          SliverToBoxAdapter(child: _DraftsRow(drafts: drafts)),
        ],
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                PrSpacing.lg, PrSpacing.xl, PrSpacing.lg, PrSpacing.md),
            child: PrSectionHeader(
              kicker: 'your library',
              title: 'Recent reels',
              subtitle: videos.isEmpty
                  ? 'Exports will appear here'
                  : '${videos.length} created · $todayCount today',
            ),
          ),
        ),
        videos.isEmpty
            ? SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      PrSpacing.lg, 0, PrSpacing.lg, 80),
                  child: PrEmptyState(
                    icon: PrIcons.film,
                    headline: 'Your reel stage is ready',
                    body:
                        'Pick a few photos or short clips and PromoReel scores, cuts, and captions them into a share-ready reel in under a minute.',
                    primaryLabel: 'Start a reel',
                    onPrimary: () => context.push(AppRoutes.picker),
                  ),
                ),
              )
            : SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                    PrSpacing.lg, 0, PrSpacing.lg, 100),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: PrSpacing.sm,
                    mainAxisSpacing: PrSpacing.sm,
                    childAspectRatio: 9 / 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _VideoCard(record: videos[i]),
                    childCount: videos.length,
                  ),
                ),
              ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Masthead — rotating reel + wordmark + settings
// ════════════════════════════════════════════════════════════════════════════

class _Masthead extends StatelessWidget {
  const _Masthead();

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 0,
      toolbarHeight: 68,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.fromLTRB(
            PrSpacing.lg, PrSpacing.xs, PrSpacing.md, 0),
        child: Row(
          children: [
            const ReelMark(size: 32),
            const SizedBox(width: PrSpacing.sm + 2),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'PromoReel',
                  style: AppTextStyles.headlineSmall.copyWith(
                    letterSpacing: -0.3,
                    fontSize: 18,
                  ),
                ),
                Text(
                  'Business reels, offline',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 10.5,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
            const Spacer(),
            PrIconButton(
              icon: PrIcons.branding,
              tooltip: 'Branding',
              onPressed: () => context.push(AppRoutes.branding),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Hero — the "start a reel" invitation
// ════════════════════════════════════════════════════════════════════════════

class _Hero extends StatelessWidget {
  const _Hero({
    required this.tier,
    required this.todayCount,
    required this.recentFirst,
  });

  final SubscriptionState tier;
  final int todayCount;

  /// First few recent videos — rendered as a peekaboo filmstrip on the right
  /// side of the hero when we have any, so the hero doubles as a taste of
  /// the user's last work.
  final List<VideoRecord> recentFirst;

  bool _gated() =>
      kSubscriptionEnabled &&
      !tier.isPro &&
      todayCount >= tier.dailyVideoLimit;

  @override
  Widget build(BuildContext context) {
    final blocked = _gated();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          PrSpacing.lg, PrSpacing.sm, PrSpacing.lg, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(PrRadius.xl),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PrRadius.xl),
            border: Border.all(
              color: AppColors.brandEmber.withValues(alpha: 0.28),
              width: 0.7,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandEmber.withValues(alpha: 0.10),
                blurRadius: 42,
                spreadRadius: -6,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              const Positioned.fill(child: AuroraBackdrop(intensity: 1.05)),
              // Content
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    PrSpacing.xl, PrSpacing.xl, PrSpacing.xl, PrSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const SprocketRule(count: 4),
                        const Spacer(),
                        PrBadge(
                          label: blocked ? 'LIMIT · TODAY' : 'OFFLINE · INSTANT',
                          tone: blocked
                              ? PrBadgeTone.warn
                              : PrBadgeTone.success,
                          dense: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: PrSpacing.md),
                    RichText(
                      text: TextSpan(
                        style: AppTextStyles.displayMedium.copyWith(
                          fontSize: 34,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        children: [
                          const TextSpan(text: 'Reels\n'),
                          TextSpan(
                            text: 'that sell.',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: PrSpacing.xs + 2),
                    Text(
                      'Photos in, promo out.\nOne minute. No accounts, no upload.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: PrSpacing.xl),
                    Row(
                      children: [
                        Expanded(
                          child: PrButton(
                            label: blocked ? 'Unlock more' : 'Start a reel',
                            icon: blocked ? PrIcons.pro : PrIcons.plus,
                            size: PrButtonSize.lg,
                            variant: blocked
                                ? PrButtonVariant.pro
                                : PrButtonVariant.primary,
                            onPressed: () {
                              if (blocked) {
                                context.push('${AppRoutes.paywall}?tier=pro');
                              } else {
                                context.push(AppRoutes.picker);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
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
// Catalog card
// ════════════════════════════════════════════════════════════════════════════

class _CatalogCard extends StatelessWidget {
  const _CatalogCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          PrSpacing.lg, PrSpacing.lg, PrSpacing.lg, 0),
      child: PrCard(
        variant: PrCardVariant.interactive,
        onTap: () => context.push(AppRoutes.catalog),
        padding: const EdgeInsets.all(PrSpacing.md),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.signalCrimson.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(PrRadius.sm + 2),
                border: Border.all(
                  color: AppColors.signalCrimson.withValues(alpha: 0.3),
                  width: 0.7,
                ),
              ),
              child: const Icon(
                PrIcons.price,
                color: AppColors.signalCrimson,
                size: 20,
              ),
            ),
            const SizedBox(width: PrSpacing.sm + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Catalog mode', style: AppTextStyles.titleMedium),
                      const SizedBox(width: PrSpacing.xs),
                      const PrBadge(
                        label: 'NEW',
                        tone: PrBadgeTone.crimson,
                        dense: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'One slide per product, prices auto-placed',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(PrIcons.chevronRight,
                color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Drafts horizontal rail
// ════════════════════════════════════════════════════════════════════════════

class _DraftsRow extends ConsumerWidget {
  const _DraftsRow({required this.drafts});
  final List<DraftRecord> drafts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 144,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: PrSpacing.lg),
        itemCount: drafts.length,
        separatorBuilder: (_, __) => const SizedBox(width: PrSpacing.sm),
        itemBuilder: (_, i) => _DraftCard(draft: drafts[i]),
      ),
    );
  }
}

class _DraftCard extends ConsumerWidget {
  const _DraftCard({required this.draft});
  final DraftRecord draft;

  String _age() {
    final diff = DateTime.now().difference(draft.updatedAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumb = draft.thumbnailPath;
    final firstAsset = draft.project.assetPaths.isNotEmpty
        ? draft.project.assetPaths.first
        : null;
    final frames = draft.project.assetPaths.length;

    return SizedBox(
      width: 96,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            PrHaptics.tap();
            ref.read(projectProvider.notifier).loadFrom(draft.project);
            context.go(AppRoutes.editor);
          },
          onLongPress: () => _confirmDelete(context, ref),
          borderRadius: BorderRadius.circular(PrRadius.md),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(PrRadius.md),
              border: Border.all(
                color: AppColors.brandEmber.withValues(alpha: 0.3),
                width: 0.7,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _DraftThumb(thumbPath: thumb, firstAsset: firstAsset),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: PrBadge(
                          label: '$frames',
                          tone: PrBadgeTone.neutral,
                          dense: true,
                          icon: PrIcons.film,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      PrSpacing.xs, PrSpacing.xxs + 2, PrSpacing.xs, PrSpacing.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _age(),
                        style: AppTextStyles.labelSmall.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 9.5,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Continue',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.brandEmber,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const Icon(PrIcons.chevronRight,
                              color: AppColors.brandEmber, size: 14),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    PrHaptics.warn();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete draft?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: TextStyle(color: AppColors.signalCrimson)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(draftsProvider.notifier).delete(draft.id);
    }
  }
}

class _DraftThumb extends StatelessWidget {
  const _DraftThumb({this.thumbPath, this.firstAsset});
  final String? thumbPath;
  final String? firstAsset;

  @override
  Widget build(BuildContext context) {
    if (thumbPath != null && File(thumbPath!).existsSync()) {
      return Image.file(File(thumbPath!), fit: BoxFit.cover);
    }
    if (firstAsset != null &&
        firstAsset != kTextSlide &&
        !isBeforeAfterPath(firstAsset!) &&
        File(firstAsset!).existsSync()) {
      return Image.file(File(firstAsset!), fit: BoxFit.cover);
    }
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Center(
        child: Icon(PrIcons.film,
            color: Theme.of(context).colorScheme.primary, size: 26),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Resume banner
// ════════════════════════════════════════════════════════════════════════════

class _ResumeBanner extends ConsumerWidget {
  const _ResumeBanner({required this.drafts});
  final List<DraftRecord> drafts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mostRecent = drafts.first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          PrSpacing.lg, PrSpacing.md, PrSpacing.lg, 0),
      child: PrCard(
        variant: PrCardVariant.interactive,
        onTap: () => _resume(context, ref, mostRecent),
        padding: const EdgeInsets.all(PrSpacing.sm + 2),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(PrSpacing.xs),
              decoration: BoxDecoration(
                color: AppColors.signalAmber.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(PrRadius.sm),
              ),
              child: const Icon(PrIcons.refresh,
                  color: AppColors.signalAmber, size: 20),
            ),
            const SizedBox(width: PrSpacing.sm + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Resume interrupted render',
                      style: AppTextStyles.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    drafts.length == 1
                        ? "Your last export didn't finish. Tap to continue."
                        : "${drafts.length} exports didn't finish. Tap to resume the latest.",
                    style: AppTextStyles.bodySmall.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            PrIconButton(
              icon: PrIcons.close,
              tooltip: 'Dismiss',
              size: 18,
              onPressed: () async {
                for (final d in drafts) {
                  await DraftService().clearRenderingFlag(d.id);
                }
                ref.invalidate(orphanedRendersProvider);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resume(
      BuildContext context, WidgetRef ref, DraftRecord draft) async {
    try {
      ref.read(projectProvider.notifier).loadFrom(draft.project);
      if (!context.mounted) return;
      context.push(AppRoutes.export);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not resume — project data is corrupt.')));
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Video grid card
// ════════════════════════════════════════════════════════════════════════════

class _VideoCard extends ConsumerStatefulWidget {
  const _VideoCard({required this.record});
  final VideoRecord record;

  @override
  ConsumerState<_VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends ConsumerState<_VideoCard> {
  Uint8List? _thumb;

  @override
  void initState() {
    super.initState();
    if (widget.record.fileExists) _loadThumb();
  }

  Future<void> _loadThumb() async {
    if (widget.record.thumbnailPath.isNotEmpty &&
        File(widget.record.thumbnailPath).existsSync()) {
      final data = await File(widget.record.thumbnailPath).readAsBytes();
      if (mounted) setState(() => _thumb = data);
      return;
    }
    try {
      final data = await VideoThumbnail.thumbnailData(
        video: widget.record.outputPath,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 480,
        quality: 80,
      );
      if (mounted && data != null) setState(() => _thumb = data);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (!widget.record.fileExists) return;
          PrHaptics.tap();
          context.push(
              '${AppRoutes.player}?path=${Uri.encodeComponent(widget.record.outputPath)}');
        },
        onLongPress: () => _showOptions(context),
        borderRadius: BorderRadius.circular(PrRadius.lg),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(PrRadius.lg),
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.record.fileExists && _thumb != null
                  ? Image.memory(_thumb!, fit: BoxFit.cover)
                  : Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      child: Center(
                          child: Icon(PrIcons.film,
                              color: Theme.of(context).colorScheme.onSurfaceVariant, size: 32)),
                    ),
              // Softer bottom gradient — preserves the image while keeping text legible.
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.78),
                    ],
                    stops: const [0.5, 1.0],
                  ),
                ),
              ),
              // Subtle play indicator (only visible on focus via ink response)
              Center(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.6),
                        width: 1.2),
                  ),
                  child: const Icon(PrIcons.play,
                      color: Colors.white, size: 26),
                ),
              ),
              Positioned(
                bottom: PrSpacing.xs,
                left: PrSpacing.xs,
                child: PrBadge(
                  label: '${widget.record.durationSeconds}s',
                  tone: PrBadgeTone.neutral,
                  dense: true,
                ),
              ),
              Positioned(
                bottom: PrSpacing.xs,
                right: PrSpacing.xs,
                child: _WhatsAppShareDot(
                  onTap: widget.record.fileExists ? _shareVideo : null,
                ),
              ),
              if (widget.record.hasProject)
                Positioned(
                  top: PrSpacing.xs,
                  right: PrSpacing.xs,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: AppColors.brandEmber.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(PrIcons.edit,
                        color: AppColors.onBrand, size: 13),
                  ),
                ),
              if (!widget.record.fileExists)
                Container(
                  color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.85),
                  child: Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: Theme.of(context).colorScheme.onSurfaceVariant, size: 28)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareVideo() async {
    if (!widget.record.fileExists) return;
    if (!mounted) return;
    await showPlatformShareSheet(context, videoPath: widget.record.outputPath);
  }

  Future<void> _deleteRecord(BuildContext context) async {
    PrHaptics.warn();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete video?'),
        content: const Text(
            'This removes it from history. The file will also be deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: TextStyle(color: AppColors.signalCrimson)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await VideoHistoryService().delete(widget.record.id);
      final file = File(widget.record.outputPath);
      if (file.existsSync()) await file.delete();
      if (context.mounted) ref.invalidate(videoHistoryProvider);
    }
  }

  void _showOptions(BuildContext context) {
    PrHaptics.select();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(PrSpacing.sm),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(PrRadius.lg),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 0.7),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: PrSpacing.sm),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: PrSpacing.sm),
              if (widget.record.hasProject)
                _SheetRow(
                  icon: PrIcons.edit,
                  label: 'Re-edit',
                  subtitle: 'Open in editor with original settings',
                  onTap: () {
                    Navigator.pop(context);
                    _reEdit(context);
                  },
                ),
              if (widget.record.fileExists) ...[
                _SheetRow(
                  icon: PrIcons.play,
                  label: 'Play',
                  onTap: () {
                    Navigator.pop(context);
                    context.push(
                        '${AppRoutes.player}?path=${Uri.encodeComponent(widget.record.outputPath)}');
                  },
                ),
                _SheetRow(
                  icon: PrIcons.share,
                  label: 'Share',
                  onTap: () {
                    Navigator.pop(context);
                    _shareVideo();
                  },
                ),
              ],
              _SheetRow(
                icon: PrIcons.trash,
                label: 'Delete',
                tone: AppColors.signalCrimson,
                onTap: () {
                  Navigator.pop(context);
                  _deleteRecord(context);
                },
              ),
              const SizedBox(height: PrSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }

  void _reEdit(BuildContext context) {
    final json = widget.record.projectJson;
    if (json == null) return;
    try {
      final project = VideoProject.fromJson(json);
      ref.read(projectProvider.notifier).loadFrom(project);
      context.push(AppRoutes.editor);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not restore project.')));
    }
  }
}

class _WhatsAppShareDot extends StatelessWidget {
  const _WhatsAppShareDot({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                PrHaptics.tap();
                onTap!();
              },
        borderRadius: BorderRadius.circular(PrRadius.pill),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFF25D366).withValues(alpha: 0.9),
            shape: BoxShape.circle,
            border:
                Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: const Icon(PrIcons.share, color: Colors.white, size: 14),
        ),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.icon,
    required this.label,
    this.subtitle,
    this.onTap,
    this.tone,
  });
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final fg = tone ?? Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: PrSpacing.lg, vertical: PrSpacing.sm + 2),
        child: Row(
          children: [
            Icon(icon, color: fg, size: 20),
            const SizedBox(width: PrSpacing.sm + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style:
                          AppTextStyles.titleMedium.copyWith(color: fg)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: AppTextStyles.bodySmall.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
