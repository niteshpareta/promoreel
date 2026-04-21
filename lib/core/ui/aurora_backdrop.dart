import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'tokens.dart';

/// Ambient backdrop — two slow-moving radial "ember" blooms over the canvas
/// with a barely-there grain overlay. Used BEHIND hero surfaces, never as
/// a full-screen background (that would make the whole app feel noisy).
///
/// Runs at ~30fps via a looping AnimationController. Pauses when the widget
/// leaves the tree, so it won't burn battery off-screen.
class AuroraBackdrop extends StatefulWidget {
  const AuroraBackdrop({
    super.key,
    this.intensity = 1,
    this.grain = true,
    this.warmHue = true,
    this.child,
  });

  /// 0 = off, 1 = default, >1 = brighter (use sparingly on paywall/hero).
  final double intensity;

  /// Render the film-grain overlay on top.
  final bool grain;

  /// When true, blooms are ember/crimson. When false, blooms use a cooler
  /// twilight blue (for light-mode hero surfaces that would look muddy
  /// with warm blooms).
  final bool warmHue;

  final Widget? child;

  @override
  State<AuroraBackdrop> createState() => _AuroraBackdropState();
}

class _AuroraBackdropState extends State<AuroraBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => CustomPaint(
              painter: _AuroraPainter(
                t: _ctrl.value,
                intensity: widget.intensity,
                warmHue: widget.warmHue,
              ),
            ),
          ),
          if (widget.grain)
            const Positioned.fill(
              child: IgnorePointer(child: _GrainLayer()),
            ),
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({
    required this.t,
    required this.intensity,
    required this.warmHue,
  });
  final double t;
  final double intensity;
  final bool warmHue;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Slow drift — two Lissajous curves, offset out of phase.
    final a1 = t * 2 * math.pi;
    final a2 = (t + 0.33) * 2 * math.pi;

    final c1 = Offset(
      w * (0.3 + 0.22 * math.sin(a1 * 0.7)),
      h * (0.35 + 0.2 * math.cos(a1 * 0.5)),
    );
    final c2 = Offset(
      w * (0.7 + 0.18 * math.cos(a2 * 0.6)),
      h * (0.65 + 0.24 * math.sin(a2 * 0.4)),
    );

    final r1 = math.max(w, h) * 0.55;
    final r2 = math.max(w, h) * 0.45;

    final warm1 = AppColors.brandEmber.withValues(alpha: 0.22 * intensity);
    final warm2 = AppColors.signalCrimson.withValues(alpha: 0.14 * intensity);
    final cool1 = const Color(0xFF6C5BFF).withValues(alpha: 0.18 * intensity);
    final cool2 = const Color(0xFF00C2B8).withValues(alpha: 0.12 * intensity);

    final (color1, color2) = warmHue ? (warm1, warm2) : (cool1, cool2);

    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [color1, color1.withValues(alpha: 0)],
        stops: const [0, 1],
      ).createShader(Rect.fromCircle(center: c1, radius: r1))
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(c1, r1, paint1);

    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [color2, color2.withValues(alpha: 0)],
        stops: const [0, 1],
      ).createShader(Rect.fromCircle(center: c2, radius: r2))
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(c2, r2, paint2);
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter old) =>
      old.t != t || old.intensity != intensity || old.warmHue != warmHue;
}

/// Cheap procedural grain. Not a texture asset — a noise pattern painted
/// once per widget rebuild and blended with plus.
class _GrainLayer extends StatelessWidget {
  const _GrainLayer();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GrainPainter(Theme.of(context).brightness == Brightness.dark),
    );
  }
}

class _GrainPainter extends CustomPainter {
  _GrainPainter(this.isDark);
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(42); // fixed seed → stable grain pattern
    final paint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.02);
    // 1 dot per ~400px² — sparse, subliminal. ~ 800 for a 480x666 panel.
    final count = (size.width * size.height / 400).round().clamp(200, 2000);
    for (var i = 0; i < count; i++) {
      canvas.drawCircle(
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
        rnd.nextDouble() * 0.6 + 0.2,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GrainPainter old) => old.isDark != isDark;
}

/// Static signature — a subtle horizontal rule of three sprocket dots, the
/// cinematic "this is a PromoReel" tell. Use sparingly: page headers, the
/// onboarding splash, the export celebration.
class SprocketRule extends StatelessWidget {
  const SprocketRule({super.key, this.color, this.count = 3});
  final Color? color;
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.brandEmber;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        return Container(
          margin: EdgeInsets.only(right: i == count - 1 ? 0 : PrSpacing.xs),
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: c,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}
