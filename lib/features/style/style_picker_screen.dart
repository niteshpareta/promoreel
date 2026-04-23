import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/ui/haptics.dart';
import '../../core/ui/pr_badge.dart';
import '../../core/ui/pr_button.dart';
import '../../core/ui/pr_icons.dart';
import '../../core/ui/pr_section_header.dart';
import '../../core/ui/tokens.dart';
import '../../data/models/motion_style.dart';
import '../../providers/project_provider.dart';
import '../../providers/subscription_provider.dart';
import '../shared/widgets/no_project_fallback.dart';

/// Style picker — choose how your reel moves.
///
/// Each tile is its own animated preview: an abstract 3-frame filmstrip that
/// actually *demonstrates* the style's motion character (pan, crossfade,
/// slide, pop). This is the point — users can't tell "Whoosh" from "Slide"
/// from a static icon.
class StylePickerScreen extends ConsumerWidget {
  const StylePickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider);
    if (project == null) return const NoProjectFallback();
    final tier = ref.watch(subscriptionProvider);
    final selected = project.motionStyleId;
    final selectedStyle = MotionStyle.all.firstWhere((s) => s.id == selected);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(selectedNameEn: selectedStyle.nameEn),
            Expanded(
              child: _Grid(selected: selected, tier: tier, ref: ref),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  PrSpacing.lg, PrSpacing.sm, PrSpacing.lg, PrSpacing.md),
              child: PrButton(
                label: 'Use ${selectedStyle.nameEn}',
                icon: PrIcons.check,
                onPressed: () => context.pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.selectedNameEn});
  final String selectedNameEn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          PrSpacing.xs, PrSpacing.xs, PrSpacing.lg, PrSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(PrIcons.back),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: PrSectionHeader(
              kicker: 'motion',
              title: 'How should it move?',
              subtitle: 'Current: $selectedNameEn',
            ),
          ),
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({
    required this.selected,
    required this.tier,
    required this.ref,
  });
  final MotionStyleId selected;
  final SubscriptionState tier;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final families = [
      ('Subtle', 'Calm, classy — for portraits, before/after, service menus',
          MotionStyleFamily.subtle),
      (
        'Energetic',
        'High-tempo — for sales, launches, promos with music',
        MotionStyleFamily.energetic
      ),
      (
        'Informational',
        'Explainers — prices, steps, FAQs, open hours',
        MotionStyleFamily.informational
      ),
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(
          horizontal: PrSpacing.lg, vertical: PrSpacing.xs),
      physics: const BouncingScrollPhysics(),
      children: [
        for (final fam in families) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
                0, PrSpacing.md, 0, PrSpacing.sm),
            child: PrSectionHeader(
              kicker: fam.$1,
              title: _familyLabel(fam.$3),
              subtitle: fam.$2,
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: PrSpacing.sm,
              mainAxisSpacing: PrSpacing.sm,
              childAspectRatio: 0.78,
            ),
            itemCount: MotionStyle.all
                .where((s) => s.family == fam.$3)
                .toList()
                .length,
            itemBuilder: (ctx, i) {
              final styles = MotionStyle.all
                  .where((s) => s.family == fam.$3)
                  .toList();
              final style = styles[i];
              final isSelected = style.id == selected;
              final locked = style.isPro && !tier.isPro;
              return _StyleTile(
                style: style,
                selected: isSelected,
                locked: locked,
                onTap: () {
                  if (locked) {
                    PrHaptics.warn();
                    ctx.push('${AppRoutes.paywall}?tier=pro');
                    return;
                  }
                  PrHaptics.select();
                  ref.read(projectProvider.notifier).setMotionStyle(style.id);
                },
              );
            },
          ),
        ],
        const SizedBox(height: PrSpacing.xl),
      ],
    );
  }

  String _familyLabel(MotionStyleFamily f) => switch (f) {
        MotionStyleFamily.subtle => 'Subtle motion',
        MotionStyleFamily.energetic => 'Energetic cuts',
        MotionStyleFamily.informational => 'Informational layouts',
      };
}

// ────────────────────────────────────────────────────────────────────────────
// Tile with live animated preview
// ────────────────────────────────────────────────────────────────────────────

class _StyleTile extends StatefulWidget {
  const _StyleTile({
    required this.style,
    required this.selected,
    required this.locked,
    required this.onTap,
  });
  final MotionStyle style;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  State<_StyleTile> createState() => _StyleTileState();
}

class _StyleTileState extends State<_StyleTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.style;
    final bg = widget.selected
        ? AppColors.brandEmber.withValues(alpha: 0.10)
        : Theme.of(context).colorScheme.surfaceContainer;
    final border = widget.selected
        ? AppColors.brandEmber
        : Theme.of(context).colorScheme.outlineVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(PrRadius.lg),
        child: AnimatedContainer(
          duration: PrDuration.fast,
          curve: PrCurves.enter,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(PrRadius.lg),
            border: Border.all(
              color: border,
              width: widget.selected ? 1.5 : 0.7,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(PrSpacing.sm + 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Live motion preview
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(PrRadius.sm),
                    child: _MotionPreview(
                      family: s.family,
                      ctrl: _ctrl,
                      accent: widget.selected
                          ? AppColors.brandEmber
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: PrSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.nameEn,
                        style: AppTextStyles.titleMedium.copyWith(
                          color: widget.selected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.locked)
                      const PrBadge(
                          label: 'PRO',
                          tone: PrBadgeTone.pro,
                          dense: true,
                          icon: PrIcons.lock)
                    else if (widget.selected)
                      const Icon(PrIcons.check,
                          color: AppColors.brandEmber, size: 16),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  s.nameHi,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 3-frame abstract filmstrip that animates *the actual motion character* of
/// the style family — slow parallax for subtle, quick cuts for energetic,
/// split layouts for informational. No video needed, no GIF asset — all
/// drawn with CustomPaint so it scales crisply and weighs nothing.
class _MotionPreview extends StatelessWidget {
  const _MotionPreview({
    required this.family,
    required this.ctrl,
    required this.accent,
  });
  final MotionStyleFamily family;
  final AnimationController ctrl;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) => CustomPaint(
        painter: _PreviewPainter(
          t: ctrl.value,
          family: family,
          accent: accent,
        ),
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  _PreviewPainter({
    required this.t,
    required this.family,
    required this.accent,
  });
  final double t;
  final MotionStyleFamily family;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    // Background panel — keep dark for contrast with ember accents regardless
    // of theme; the preview is its own micro-scene.
    final bg = Paint()..color = AppColors.canvasDark;
    canvas.drawRect(Offset.zero & size, bg);

    switch (family) {
      case MotionStyleFamily.subtle:
        _paintParallax(canvas, size);
        break;
      case MotionStyleFamily.energetic:
        _paintQuickCuts(canvas, size);
        break;
      case MotionStyleFamily.informational:
        _paintSplit(canvas, size);
        break;
    }
  }

  // Slow horizontal drift — Ken Burns feeling.
  void _paintParallax(Canvas canvas, Size size) {
    final bar = Paint()..color = accent.withValues(alpha: 0.8);
    final back = Paint()..color = accent.withValues(alpha: 0.22);

    // Background mountains (parallax back).
    final drift = math.sin(t * 2 * math.pi) * 6;
    final path = Path()
      ..moveTo(-10 + drift, size.height * 0.8)
      ..lineTo(size.width * 0.3 + drift, size.height * 0.45)
      ..lineTo(size.width * 0.6 + drift, size.height * 0.62)
      ..lineTo(size.width * 0.9 + drift, size.height * 0.4)
      ..lineTo(size.width + 10, size.height * 0.55)
      ..lineTo(size.width + 10, size.height)
      ..lineTo(-10, size.height)
      ..close();
    canvas.drawPath(path, back);

    // Foreground bar slowly zooming in.
    final zoom = 1 + math.sin(t * 2 * math.pi) * 0.05;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2 + drift * 2, size.height * 0.7),
      width: size.width * 0.7 * zoom,
      height: 6,
    );
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)), bar);
  }

  // Energetic — 3 quick cuts with flash transitions.
  void _paintQuickCuts(Canvas canvas, Size size) {
    final tri = (t * 3) % 1;
    final step = (t * 3).floor() % 3;

    final panel = Paint()..color = accent.withValues(alpha: 0.24);
    final highlight = Paint()..color = accent;

    // Flash on transition.
    final flashAlpha = (1 - (tri * 3).clamp(0, 1)).clamp(0.0, 1.0);
    final flashPaint = Paint()
      ..color = accent.withValues(alpha: 0.4 * flashAlpha);
    canvas.drawRect(Offset.zero & size, flashPaint);

    // Three panels — only active is bright.
    const panelW = 0.26;
    for (var i = 0; i < 3; i++) {
      final left = size.width * (0.12 + i * 0.3);
      final rect = Rect.fromLTWH(
        left,
        size.height * 0.2,
        size.width * panelW,
        size.height * 0.6,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        i == step ? highlight : panel,
      );
    }
  }

  // Informational — split-screen / bottom-third bar
  void _paintSplit(Canvas canvas, Size size) {
    final left = Paint()..color = accent.withValues(alpha: 0.3);
    final right = Paint()..color = accent.withValues(alpha: 0.55);
    final bar = Paint()..color = accent;

    // Split half fills with a sweep animation.
    final sweep = (math.sin(t * 2 * math.pi) + 1) / 2;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width * 0.5 * sweep, size.height),
      left,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.5, 0,
          size.width * 0.5 * (1 - sweep), size.height),
      right,
    );

    // Bottom-third highlight.
    final barRect = Rect.fromLTWH(
      size.width * 0.08,
      size.height * 0.78,
      size.width * 0.84,
      size.height * 0.12,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(barRect, const Radius.circular(3)),
      bar,
    );
  }

  @override
  bool shouldRepaint(covariant _PreviewPainter old) =>
      old.t != t || old.family != family || old.accent != accent;
}
