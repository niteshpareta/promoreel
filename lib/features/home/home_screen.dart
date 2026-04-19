import 'dart:io';
import 'dart:math' show pi, cos, sin;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/router/app_router.dart';
import '../../data/models/video_project.dart';
import '../../features/shared/widgets/pro_badge.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/services/draft_service.dart';
import '../../data/services/video_history_service.dart';
import '../../providers/drafts_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/project_provider.dart';
import '../../providers/subscription_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub        = ref.watch(subscriptionProvider);
    final statsAsync = ref.watch(videoHistoryProvider);
    final draftsAsync = ref.watch(draftsProvider);
    final drafts = draftsAsync.valueOrNull ?? [];

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: statsAsync.when(
        loading: () => const _LoadingBody(),
        error: (_, __) => _HomeBody(tier: sub, videos: [], todayCount: 0, drafts: drafts),
        data: (s) => _HomeBody(tier: sub, videos: s.videos, todayCount: s.todayCount, drafts: drafts),
      ),
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(color: AppColors.primary));
}

// ── Main body ─────────────────────────────────────────────────────────────────

class _HomeBody extends StatelessWidget {
  const _HomeBody({
    required this.tier,
    required this.videos,
    required this.todayCount,
    required this.drafts,
  });
  final SubscriptionTier tier;
  final List<VideoRecord> videos;
  final int todayCount;
  final List<DraftRecord> drafts;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _AppBar(tier: tier),
        SliverToBoxAdapter(
            child: _HeroCard(tier: tier, todayCount: todayCount)),
        SliverToBoxAdapter(child: _CatalogBanner()),
        // Drafts section — only shown when there are saved drafts
        if (drafts.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: _SectionHeader(
                title: 'Drafts',
                subtitle: '${drafts.length} in progress',
              ),
            ),
          ),
          SliverToBoxAdapter(child: _DraftsRow(drafts: drafts)),
        ],
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: _SectionHeader(
              title: 'Recent Reels',
              subtitle: videos.isEmpty ? 'None yet' : '${videos.length} created',
            ),
          ),
        ),
        videos.isEmpty
            ? SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 60),
                  child: _EmptyState(),
                ),
              )
            : SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 9 / 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _VideoCard(record: videos[i]),
                    childCount: videos.length,
                  ),
                ),
              ),
      ],
    );
  }
}

// ── Film reel logo ────────────────────────────────────────────────────────────

class _ReelLogo extends StatelessWidget {
  const _ReelLogo({this.size = 38});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF9C6FFF), AppColors.primary, Color(0xFF5E35B1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.5),
            blurRadius: 12, offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CustomPaint(painter: _ReelPainter()),
    );
  }
}

class _ReelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final ro = size.width * 0.30;
    final ri = size.width * 0.10;
    final white  = Paint()..color = Colors.white;
    final bgPaint = Paint()..color = const Color(0xFF7C4DFF);

    // Outer circle
    canvas.drawCircle(Offset(cx, cy), ro, white);

    // 6 sprocket holes
    final holeR  = size.width * 0.055;
    final ringR  = size.width * 0.195;
    for (int i = 0; i < 6; i++) {
      final a  = (i * 60 - 90) * pi / 180;
      final hx = cx + ringR * cos(a);
      final hy = cy + ringR * sin(a);
      canvas.drawCircle(Offset(hx, hy), holeR, bgPaint);
    }

    // Inner hub
    canvas.drawCircle(Offset(cx, cy), ri, bgPaint);

    // Play triangle (coral orange)
    final triPaint = Paint()..color = const Color(0xFFFF6E40);
    final th = size.width * 0.13;
    final tw = size.width * 0.115;
    final tx = cx - tw * 0.15;
    final ty = cy;
    final path = Path()
      ..moveTo(tx, ty - th / 2)
      ..lineTo(tx + tw, ty)
      ..lineTo(tx, ty + th / 2)
      ..close();
    canvas.drawPath(path, triPaint);
  }

  @override
  bool shouldRepaint(_ReelPainter old) => false;
}

// ── App Bar ───────────────────────────────────────────────────────────────────

class _AppBar extends StatelessWidget {
  const _AppBar({required this.tier});
  final SubscriptionTier tier;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      backgroundColor: AppColors.bgDark,
      surfaceTintColor: Colors.transparent,
      pinned: true,
      expandedHeight: 0,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            const _ReelLogo(),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('PromoReel',
                    style: AppTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.w800, fontSize: 17,
                        letterSpacing: -0.3)),
                Text('Business Reel Maker',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.textSecondary, fontSize: 10)),
              ],
            ),
            const Spacer(),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.tune_rounded,
                  color: AppColors.textSecondary, size: 22),
              onPressed: () => context.push(AppRoutes.branding),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hero Card ─────────────────────────────────────────────────────────────────

class _HeroCard extends StatefulWidget {
  const _HeroCard({required this.tier, required this.todayCount});
  final SubscriptionTier tier;
  final int todayCount;

  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: GestureDetector(
        onTap: () {
          if (!widget.tier.isPro &&
              widget.todayCount >= widget.tier.dailyVideoLimit) {
            context.push('${AppRoutes.paywall}?tier=pro');
          } else {
            context.push(AppRoutes.picker);
          }
        },
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (ctx, child) => Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                colors: [Color(0xFF1E0A4A), Color(0xFF2D1B69), Color(0xFF0F0630)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: AppColors.primary
                    .withValues(alpha: 0.2 + 0.2 * _pulse.value),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary
                      .withValues(alpha: 0.15 + 0.12 * _pulse.value),
                  blurRadius: 40,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: child,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(27),
            child: Stack(
              children: [
                // Glow orbs
                Positioned(
                  right: -50, top: -50,
                  child: Container(
                    width: 220, height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        AppColors.primary.withValues(alpha: 0.22),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                ),
                Positioned(
                  left: -30, bottom: -30,
                  child: Container(
                    width: 160, height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        AppColors.secondary.withValues(alpha: 0.16),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                ),
                // Floating video frames decoration
                Positioned(
                  right: 16, top: 18,
                  child: _FloatingFrame(
                      width: 64, height: 100, rotate: 0.08,
                      opacity: 0.9, gradient: const [Color(0xFF3D1F8A), Color(0xFF1A0840)]),
                ),
                Positioned(
                  right: 52, top: 30,
                  child: _FloatingFrame(
                      width: 54, height: 86, rotate: -0.05,
                      opacity: 0.55, gradient: const [Color(0xFF4B2DA0), Color(0xFF251060)]),
                ),

                // Main content
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 26, 100, 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.success.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6, height: 6,
                              decoration: const BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 5),
                            Text('OFFLINE • INSTANT',
                                style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.success,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Headline
                      Text('Make Reels\nThat Sell.',
                          style: AppTextStyles.headlineMedium.copyWith(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                              letterSpacing: -0.8,
                              color: Colors.white)),
                      const SizedBox(height: 8),
                      Text('Any business • Any format\n60 seconds flat',
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              height: 1.5)),
                      const SizedBox(height: 22),

                      // CTA button — full feel
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF9C6FFF), AppColors.primary],
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.55),
                              blurRadius: 16,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.movie_creation_rounded,
                                color: Colors.white, size: 17),
                            const SizedBox(width: 7),
                            Text('Create Reel',
                                style: AppTextStyles.labelMedium.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14)),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_rounded,
                                color: Colors.white, size: 15),
                          ],
                        ),
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
}

class _FloatingFrame extends StatelessWidget {
  const _FloatingFrame({
    required this.width, required this.height, required this.rotate,
    required this.opacity, required this.gradient,
  });
  final double width, height, rotate, opacity;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotate,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: width, height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.18), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3), blurRadius: 12),
            ],
          ),
          child: Stack(
            children: [
              Center(
                child: Icon(Icons.play_arrow_rounded,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: width * 0.35),
              ),
              Positioned(
                bottom: 8, left: 6, right: 6,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Positioned(
                bottom: 14, left: 6, right: 20,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});
  final String title, subtitle;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(title,
              style: AppTextStyles.headlineSmall
                  .copyWith(fontWeight: FontWeight.w800, fontSize: 17)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.divider),
            ),
            child: Text(subtitle,
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textSecondary, fontSize: 10)),
          ),
        ],
      );
}

// ── Drafts row ────────────────────────────────────────────────────────────────

class _DraftsRow extends ConsumerWidget {
  const _DraftsRow({required this.drafts});
  final List<DraftRecord> drafts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: drafts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) => _DraftCard(draft: drafts[i]),
      ),
    );
  }
}

class _DraftCard extends ConsumerWidget {
  const _DraftCard({required this.draft});
  final DraftRecord draft;

  String _label() {
    final n = draft.project.assetPaths.length;
    final d = draft.updatedAt;
    final now = DateTime.now();
    final diff = now.difference(d);
    String when;
    if (diff.inMinutes < 1) {
      when = 'just now';
    } else if (diff.inHours < 1) {
      when = '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      when = '${diff.inHours}h ago';
    } else {
      when = '${diff.inDays}d ago';
    }
    return '$n slide${n == 1 ? '' : 's'} · $when';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumb = draft.thumbnailPath;
    final firstAsset = draft.project.assetPaths.isNotEmpty
        ? draft.project.assetPaths.first
        : null;

    return GestureDetector(
      onTap: () {
        ref.read(projectProvider.notifier).loadFrom(draft.project);
        context.go(AppRoutes.editor);
      },
      onLongPress: () => _confirmDelete(context, ref),
      child: Container(
        width: 90,
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: _DraftThumb(
                    thumbPath: thumb, firstAsset: firstAsset),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _label(),
                    style: AppTextStyles.labelSmall
                        .copyWith(fontSize: 9, color: AppColors.textSecondary),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Continue',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.labelSmall.copyWith(
                          fontSize: 9, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: const Text('Delete draft?',
            style: TextStyle(color: Colors.white)),
        content: const Text('This cannot be undone.',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.redAccent))),
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
      color: AppColors.bgElevated,
      child: const Center(
        child: Icon(Icons.video_library_rounded,
            color: AppColors.primary, size: 28),
      ),
    );
  }
}

// ── Catalog banner ────────────────────────────────────────────────────────────

class _CatalogBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: GestureDetector(
        onTap: () => context.push(AppRoutes.catalog),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.secondary.withValues(alpha: 0.15),
                AppColors.secondary.withValues(alpha: 0.05),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: AppColors.secondary.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.grid_view_rounded,
                    color: AppColors.secondary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Product Catalog Mode',
                            style: AppTextStyles.titleSmall.copyWith(
                                fontWeight: FontWeight.w800)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.secondary
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('NEW',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.secondary,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              )),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Add products with prices — auto-generates one slide per item',
                      style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.secondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => context.push(AppRoutes.picker),
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.08),
                AppColors.bgSurface,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
                style: BorderStyle.solid),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    AppColors.primary.withValues(alpha: 0.25),
                    AppColors.primary.withValues(alpha: 0.08),
                  ]),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.35)),
                ),
                child: const Icon(Icons.movie_creation_rounded,
                    color: AppColors.primary, size: 30),
              ),
              const SizedBox(height: 14),
              Text('No reels yet',
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 5),
              Text('Tap to create your first promo reel',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF9C6FFF), AppColors.primary]),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 14,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: Text('Create Now →',
                    style: AppTextStyles.labelMedium.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      );
}

// ── Video card ────────────────────────────────────────────────────────────────

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
    return GestureDetector(
      onTap: () {
        if (!widget.record.fileExists) return;
        context.push(
          '${AppRoutes.player}?path=${Uri.encodeComponent(widget.record.outputPath)}',
        );
      },
      onLongPress: () => _showOptions(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.record.fileExists && _thumb != null
                ? Image.memory(_thumb!, fit: BoxFit.cover)
                : Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1A0840), Color(0xFF0D0D1A)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.video_file_rounded,
                          color: AppColors.textDisabled, size: 36),
                    ),
                  ),
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.78)],
                  stops: const [0.45, 1.0],
                ),
              ),
            ),
            // Play button
            Center(
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.7), width: 1.5),
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 24),
              ),
            ),
            // Duration
            Positioned(
              bottom: 10, left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${widget.record.durationSeconds}s',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 11,
                        fontWeight: FontWeight.w800)),
              ),
            ),
            // Share button
            Positioned(
              bottom: 8, right: 8,
              child: GestureDetector(
                onTap: widget.record.fileExists ? () => _shareVideo() : null,
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.share_rounded,
                      color: Colors.white, size: 14),
                ),
              ),
            ),
            // Re-edit indicator
            if (widget.record.hasProject)
              Positioned(
                top: 8, right: 8,
                child: Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit_rounded,
                      color: Colors.white, size: 13),
                ),
              ),
            if (!widget.record.fileExists)
              Container(
                color: AppColors.bgElevated.withValues(alpha: 0.85),
                child: const Center(
                  child: Icon(Icons.broken_image_outlined,
                      color: AppColors.textDisabled, size: 28),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareVideo() async {
    if (!widget.record.fileExists) return;
    await Share.shareXFiles(
      [XFile(widget.record.outputPath, mimeType: 'video/mp4', name: 'status_video.mp4')],
      subject: 'Check out my latest offer!',
    );
  }

  Future<void> _deleteRecord(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: const Text('Delete video?', style: TextStyle(color: Colors.white)),
        content: const Text('This removes it from history. The file will also be deleted.',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await VideoHistoryService().delete(widget.record.id);
      // Also delete file if it exists
      final file = File(widget.record.outputPath);
      if (file.existsSync()) await file.delete();
      if (context.mounted) ref.invalidate(videoHistoryProvider);
    }
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
            if (widget.record.hasProject)
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: AppColors.primary),
                title: const Text('Re-edit'),
                subtitle: const Text('Opens in editor with original settings'),
                onTap: () {
                  Navigator.pop(context);
                  _reEdit(context);
                },
              ),
            if (widget.record.fileExists) ...[
              ListTile(
                leading: const Icon(Icons.play_arrow_rounded, color: AppColors.textSecondary),
                title: const Text('Play'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('${AppRoutes.player}?path=${Uri.encodeComponent(widget.record.outputPath)}');
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded, color: Color(0xFF25D366)),
                title: const Text('Share'),
                onTap: () {
                  Navigator.pop(context);
                  _shareVideo();
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              title: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(context);
                _deleteRecord(context);
              },
            ),
            const SizedBox(height: 8),
          ],
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
        const SnackBar(content: Text('Could not restore project.')),
      );
    }
  }
}
