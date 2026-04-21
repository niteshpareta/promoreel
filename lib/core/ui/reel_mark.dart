import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'tokens.dart';

/// The PromoReel brandmark — a film reel painted in code. Two concentric
/// rings, a hub, and five perfectly-spaced inner cutouts, all ember-lit.
/// When [animated] is true, the reel rotates slowly (ambient), signalling
/// "this app is about video motion" without the user having to do anything.
///
/// Always use this over a PNG logo: scales crisply at any size, the
/// rotation is built-in, and the ember gradient follows the theme.
class ReelMark extends StatefulWidget {
  const ReelMark({
    super.key,
    this.size = 36,
    this.animated = true,
    this.monochrome = false,
  });

  final double size;
  final bool animated;

  /// When true, paints in the current theme's primary text color instead of
  /// the ember gradient. Use on badges where the brand color would clash.
  final bool monochrome;

  @override
  State<ReelMark> createState() => _ReelMarkState();
}

class _ReelMarkState extends State<ReelMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animated) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(ReelMark old) {
    super.didUpdateWidget(old);
    if (widget.animated && !_ctrl.isAnimating) _ctrl.repeat();
    if (!widget.animated && _ctrl.isAnimating) _ctrl.stop();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ink =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.88);
    return Semantics(
      label: 'PromoReel',
      image: true,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => CustomPaint(
            painter: _ReelPainter(
              angle: _ctrl.value * 2 * math.pi,
              monochrome: widget.monochrome,
              ink: ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReelPainter extends CustomPainter {
  _ReelPainter({
    required this.angle,
    required this.monochrome,
    required this.ink,
  });
  final double angle;
  final bool monochrome;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;

    // Outer glow — a soft ember halo that hints at projector light.
    if (!monochrome) {
      final glow = Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.brandEmber.withValues(alpha: 0.35),
            AppColors.brandEmber.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r * 1.3));
      canvas.drawCircle(c, r * 1.25, glow);
    }

    // Outer ring (the reel's flange).
    final outerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.12
      ..shader = monochrome
          ? null
          : LinearGradient(
              colors: const [
                AppColors.brandEmberSoft,
                AppColors.brandEmber,
                AppColors.brandEmberDeep,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(Rect.fromCircle(center: c, radius: r))
      ..color = monochrome ? ink : Colors.white;
    canvas.drawCircle(c, r * 0.88, outerPaint);

    // Inner hub (the spindle).
    final hubPaint = Paint()
      ..color = monochrome ? ink : AppColors.brandEmber;
    canvas.drawCircle(c, r * 0.16, hubPaint);

    // Hub ring — the seam between hub and cutouts.
    canvas.drawCircle(c, r * 0.24,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.04
          ..color = monochrome
              ? ink.withValues(alpha: 0.6)
              : AppColors.brandEmberDeep);

    // Five sprocket cutouts (where the film was traditionally mounted).
    final cutoutPaint = Paint()
      ..color = monochrome ? ink : AppColors.brandEmberSoft;
    final cutoutRadius = r * 0.12;
    final cutoutDistance = r * 0.5;
    for (var i = 0; i < 5; i++) {
      final a = angle + i * (2 * math.pi / 5);
      final p = Offset(
        c.dx + cutoutDistance * math.cos(a),
        c.dy + cutoutDistance * math.sin(a),
      );
      canvas.drawCircle(p, cutoutRadius, cutoutPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ReelPainter old) =>
      old.angle != angle ||
      old.monochrome != monochrome ||
      old.ink != ink;
}

/// Horizontal "filmstrip" decoration — 4px-tall perforated strip with
/// evenly spaced sprocket holes. Use as a top/bottom accent on hero cards,
/// export headers, and onboarding slides.
class FilmPerforation extends StatelessWidget {
  const FilmPerforation({super.key, this.holes = 18, this.height = 10});
  final int holes;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: LayoutBuilder(builder: (_, c) {
        final step = c.maxWidth / holes;
        return Row(
          children: List.generate(holes, (i) {
            return SizedBox(
              width: step,
              child: Center(
                child: Container(
                  width: math.min(step * 0.5, 6),
                  height: height * 0.4,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
            );
          }),
        );
      }),
    );
  }
}

/// A horizontal filmstrip of tiles (thumbnails, frames, style swatches)
/// bounded by sprocket perforations above and below. This is the PromoReel
/// "this is a video app" visual signature.
///
/// Pass [tiles] as pre-sized widgets (usually 9:16 thumbnails at 60x106).
class FilmstripTile extends StatelessWidget {
  const FilmstripTile({
    super.key,
    required this.tiles,
    this.height = 120,
    this.tileGap = PrSpacing.xxs + 2,
  });

  final List<Widget> tiles;
  final double height;
  final double tileGap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.canvasDark,
        borderRadius: BorderRadius.circular(PrRadius.md),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: FilmPerforation(holes: 16, height: 10),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: PrSpacing.xs),
              itemBuilder: (_, i) => AspectRatio(
                aspectRatio: 9 / 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: tiles[i],
                ),
              ),
              separatorBuilder: (_, __) => SizedBox(width: tileGap),
              itemCount: tiles.length,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: FilmPerforation(holes: 16, height: 10),
          ),
        ],
      ),
    );
  }
}
