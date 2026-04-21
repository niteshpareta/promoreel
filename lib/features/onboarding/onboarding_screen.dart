import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/ui/aurora_backdrop.dart';
import '../../core/ui/haptics.dart';
import '../../core/ui/pr_button.dart';
import '../../core/ui/pr_icons.dart';
import '../../core/ui/reel_mark.dart';
import '../../core/ui/tokens.dart';

/// Onboarding — 3 slides, designed for conversion.
///
/// The job of this screen isn't to teach features; it's to make the user want
/// to tap "Start". Each slide commits to a single message, written as
/// benefit-first editorial copy (not feature-list bullets). Visuals are built
/// in code (vector + animation) so everything is crisp and on-brand, with no
/// marketing PNGs to maintain.
///
///   1. **The Moment**   — why PromoReel exists (ember reel, aurora, bold promise)
///   2. **The Method**   — how it works in three beats (cycling phone frame)
///   3. **The Ask**      — compelling CTA + trust row (no card / no account / offline)
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  int _currentPage = 0;

  Future<void> _markSeenAndGo(String route) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);
    if (mounted) context.go(route);
  }

  void _next() {
    PrHaptics.tap();
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: PrCurves.cinematic,
      );
    } else {
      _markSeenAndGo(AppRoutes.picker);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == 2;

    return Scaffold(
      body: Stack(
        children: [
          // Aurora ambient — the "this is cinema" atmosphere
          const Positioned.fill(
            child: Opacity(opacity: 0.55, child: AuroraBackdrop(intensity: 1.05)),
          ),
          SafeArea(
            child: Column(
              children: [
                // ── Top bar: filmstrip progress + skip ──────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      PrSpacing.lg, PrSpacing.xs, PrSpacing.xs, 0),
                  child: Row(
                    children: [
                      _FilmstripProgress(current: _currentPage, total: 3),
                      const Spacer(),
                      TextButton(
                        onPressed: () => _markSeenAndGo(AppRoutes.home),
                        child: Text(
                          'Skip',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Pages ───────────────────────────────────────────────
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const BouncingScrollPhysics(),
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    children: const [
                      _SlideMoment(),
                      _SlideMethod(),
                      _SlideAsk(),
                    ],
                  ),
                ),
                // ── CTA + secondary ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      PrSpacing.xl, PrSpacing.sm, PrSpacing.xl, PrSpacing.xl),
                  child: Column(
                    children: [
                      PrButton(
                        label: isLast ? 'Start my first reel' : 'Next',
                        icon: isLast ? PrIcons.sparkle : null,
                        trailing:
                            isLast ? null : const Icon(PrIcons.chevronRight),
                        onPressed: _next,
                      ),
                      if (isLast) ...[
                        const SizedBox(height: PrSpacing.xs + 2),
                        Text(
                          'Free · No card · No account',
                          style: AppTextStyles.labelSmall.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ],
                  ),
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
// Filmstrip progress — three perforated panels, active one glows ember.
// Replaces the generic 3-dot indicator.
// ════════════════════════════════════════════════════════════════════════════

class _FilmstripProgress extends StatelessWidget {
  const _FilmstripProgress({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.outlineVariant;
    return Row(
      children: List.generate(total, (i) {
        final active = i == current;
        final done = i < current;
        return AnimatedContainer(
          duration: PrDuration.base,
          curve: PrCurves.enter,
          margin: const EdgeInsets.only(right: 6),
          width: active ? 36 : 14,
          height: 6,
          decoration: BoxDecoration(
            color: active
                ? AppColors.brandEmber
                : done
                    ? AppColors.brandEmberDeep.withValues(alpha: 0.6)
                    : muted.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SLIDE 1 — The Moment
// Giant rotating ReelMark. Editorial "ISSUE NO." kicker. A single promise
// written in Fraunces serif. Anchors the emotional pitch.
// ════════════════════════════════════════════════════════════════════════════

class _SlideMoment extends StatelessWidget {
  const _SlideMoment();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PrSpacing.xl),
      child: Column(
        children: [
          const Spacer(flex: 2),
          // The hero reel — rotates ambiently, sets the "this is cinema" tone.
          Stack(
            alignment: Alignment.center,
            children: [
              // Halo ring
              Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.brandEmber.withValues(alpha: 0.22),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              const ReelMark(size: 180),
            ],
          ),
          const SizedBox(height: PrSpacing.xl),
          const _SprocketDivider(),
          const SizedBox(height: PrSpacing.lg),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: AppTextStyles.displayMedium.copyWith(
                fontSize: 34,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              children: [
                const TextSpan(text: 'Your work,\nmade '),
                TextSpan(
                  text: 'cinematic.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: PrSpacing.sm),
          Text(
            'If you sell, serve, teach, or create —\nturn your photos into scroll-stopping reels.',
            style: AppTextStyles.bodyLarge.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.55,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SLIDE 2 — The Method
// A single phone frame that cycles through the three stages of creation
// every ~2s: raw photos → style picker → finished reel. Shows the journey.
// ════════════════════════════════════════════════════════════════════════════

class _SlideMethod extends StatefulWidget {
  const _SlideMethod();

  @override
  State<_SlideMethod> createState() => _SlideMethodState();
}

class _SlideMethodState extends State<_SlideMethod>
    with SingleTickerProviderStateMixin {
  int _stage = 0;
  late final Animation<double> _tick;
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _tick = _ctrl;
    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        setState(() => _stage = (_stage + 1) % 3);
      }
    });
    _ctrl.addListener(() {
      if (_ctrl.value > 0.98 && _stage != (_stage + 1) % 3) {
        // (no-op; state change driven by status listener)
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PrSpacing.xl),
      child: Column(
        children: [
          const Spacer(flex: 1),
          // Cycling phone mock
          _CyclingPhone(stage: _stage, tick: _tick),
          const Spacer(flex: 1),
          Text('HOW IT WORKS', style: AppTextStyles.kicker),
          const SizedBox(height: PrSpacing.xs + 2),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: AppTextStyles.displayMedium.copyWith(
                fontSize: 30,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              children: [
                const TextSpan(text: 'Pick. Pick. '),
                TextSpan(
                  text: 'Posted.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: PrSpacing.md),
          _StepRow(
            active: _stage == 0,
            number: '01',
            label: 'Pick 5 photos',
            sublabel: 'From your gallery',
          ),
          _StepRow(
            active: _stage == 1,
            number: '02',
            label: 'Pick a motion style',
            sublabel: '12 cinematic templates',
          ),
          _StepRow(
            active: _stage == 2,
            number: '03',
            label: 'We cut the reel',
            sublabel: 'Captions, beats, branding — done',
          ),
          const Spacer(flex: 1),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.active,
    required this.number,
    required this.label,
    required this.sublabel,
  });
  final bool active;
  final String number;
  final String label;
  final String sublabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: PrDuration.base,
      curve: PrCurves.enter,
      margin: const EdgeInsets.only(top: PrSpacing.xs),
      padding: const EdgeInsets.symmetric(
          horizontal: PrSpacing.sm, vertical: PrSpacing.xs + 1),
      decoration: BoxDecoration(
        color: active
            ? AppColors.brandEmber.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(PrRadius.sm),
        border: Border.all(
          color: active
              ? AppColors.brandEmber.withValues(alpha: 0.35)
              : Colors.transparent,
          width: 0.7,
        ),
      ),
      child: Row(
        children: [
          Text(
            number,
            style: AppTextStyles.numeric.copyWith(
              color: active ? AppColors.brandEmber : scheme.onSurfaceVariant,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: PrSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: scheme.onSurface,
                    )),
                Text(sublabel,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11,
                    )),
              ],
            ),
          ),
          if (active)
            Icon(PrIcons.sparkle,
                color: AppColors.brandEmber, size: 16),
        ],
      ),
    );
  }
}

// ── Cycling phone — shows the three stages of creation in a loop ─────────

class _CyclingPhone extends StatelessWidget {
  const _CyclingPhone({required this.stage, required this.tick});
  final int stage;
  final Animation<double> tick;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168,
      height: 290,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PrRadius.xl),
        color: Colors.black,
        border: Border.all(
          color: AppColors.brandEmber.withValues(alpha: 0.35),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandEmber.withValues(alpha: 0.25),
            blurRadius: 40,
            spreadRadius: -4,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(PrRadius.xl - 4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(PrRadius.lg),
            child: AnimatedSwitcher(
              duration: PrDuration.slow,
              switchInCurve: PrCurves.cinematic,
              switchOutCurve: PrCurves.exit,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.94, end: 1).animate(anim),
                  child: child,
                ),
              ),
              child: switch (stage) {
                0 => const _StagePhotos(key: ValueKey('stage-photos')),
                1 => const _StageStyles(key: ValueKey('stage-styles')),
                _ => _StageReel(key: const ValueKey('stage-reel'), tick: tick),
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _StagePhotos extends StatelessWidget {
  const _StagePhotos({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.canvasDark,
      padding: const EdgeInsets.all(PrSpacing.xs),
      child: Column(
        children: [
          // Top strip — "Photos"
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: PrSpacing.xs, vertical: PrSpacing.xxs + 2),
            child: Row(
              children: [
                Icon(PrIcons.gallery,
                    color: AppColors.brandEmber, size: 12),
                const SizedBox(width: 4),
                Text('Gallery',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: Colors.white,
                      fontSize: 9,
                    )),
              ],
            ),
          ),
          // Photo grid (6 mock tiles)
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 3,
              crossAxisSpacing: 3,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              children: List.generate(6, (i) {
                final selected = i < 3; // first 3 "picked"
                return Container(
                  decoration: BoxDecoration(
                    color: _tileColor(i),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: selected
                          ? AppColors.brandEmber
                          : Colors.transparent,
                      width: 1.4,
                    ),
                  ),
                  child: selected
                      ? Align(
                          alignment: Alignment.topRight,
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppColors.brandEmber,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.black, width: 1),
                            ),
                            child: Icon(PrIcons.check,
                                color: AppColors.onBrand, size: 8),
                          ),
                        )
                      : null,
                );
              }),
            ),
          ),
          // Bottom strip — "3 selected · Next"
          Container(
            margin: const EdgeInsets.symmetric(vertical: PrSpacing.xxs + 2),
            padding: const EdgeInsets.symmetric(
                horizontal: PrSpacing.xs, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.brandEmber,
              borderRadius: BorderRadius.circular(PrRadius.sm),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('3 selected · Continue',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.onBrand,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _tileColor(int i) {
    const swatches = [
      Color(0xFF8A6B3C),
      Color(0xFF4A3A2A),
      Color(0xFF6B4524),
      Color(0xFF2E2923),
      Color(0xFF4F3A28),
      Color(0xFF3A2E25),
    ];
    return swatches[i % swatches.length];
  }
}

class _StageStyles extends StatelessWidget {
  const _StageStyles({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.canvasDark,
      padding: const EdgeInsets.all(PrSpacing.xs + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MOTION',
              style: AppTextStyles.kicker.copyWith(
                fontSize: 8,
                letterSpacing: 1.8,
                color: AppColors.brandEmberSoft,
              )),
          const SizedBox(height: 2),
          Text('Choose a vibe',
              style: AppTextStyles.titleSmall.copyWith(
                color: Colors.white,
                fontSize: 10,
              )),
          const SizedBox(height: PrSpacing.xs),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1.1,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                _StyleChip(name: 'Subtle', color: 0xFFB8772A, selected: true),
                _StyleChip(name: 'Bold', color: 0xFFE63E7A),
                _StyleChip(name: 'Zoom', color: 0xFF60A5FA),
                _StyleChip(name: 'Beat', color: 0xFF4ADE80),
                _StyleChip(name: 'Fade', color: 0xFFF2C661),
                _StyleChip(name: 'Flash', color: 0xFFF87171),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StyleChip extends StatelessWidget {
  const _StyleChip({
    required this.name,
    required this.color,
    this.selected = false,
  });
  final String name;
  final int color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = Color(color);
    return Container(
      decoration: BoxDecoration(
        color: selected ? c.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: selected ? c : Colors.white.withValues(alpha: 0.08),
          width: selected ? 1.2 : 0.5,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        name,
        style: AppTextStyles.labelSmall.copyWith(
          color: selected ? c : Colors.white.withValues(alpha: 0.7),
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StageReel extends StatelessWidget {
  const _StageReel({super.key, required this.tick});
  final Animation<double> tick;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: tick,
      builder: (_, __) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF251A11), Color(0xFF0A0807)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Faux video background shimmer
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.brandEmber.withValues(
                          alpha: 0.18 + 0.1 * math.sin(tick.value * math.pi * 2)),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Play glyph
            Center(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
                ),
                child: const Icon(PrIcons.play,
                    color: Colors.white, size: 24),
              ),
            ),
            // Faux caption + price badge
            Positioned(
              bottom: 32,
              left: 8,
              right: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.brandEmber,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text('NEW',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.onBrand,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        )),
                  ),
                  const SizedBox(height: 4),
                  Text('Your best work.',
                      style: AppTextStyles.titleSmall.copyWith(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        shadows: const [
                          Shadow(color: Colors.black, blurRadius: 6),
                        ],
                      )),
                ],
              ),
            ),
            // Bottom progress scrubber
            Positioned(
              bottom: 12,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(1),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: tick.value,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.brandEmber,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Branding strip at the very bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 16,
                color: Colors.black.withValues(alpha: 0.75),
                alignment: Alignment.center,
                child: Text('YOUR BRAND',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 7.5,
                      letterSpacing: 1,
                    )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SLIDE 3 — The Ask
// A completed-reel moment + WhatsApp share + trust row. Converts.
// ════════════════════════════════════════════════════════════════════════════

class _SlideAsk extends StatelessWidget {
  const _SlideAsk();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PrSpacing.xl),
      child: Column(
        children: [
          const Spacer(flex: 1),
          // Trio of channels — WhatsApp leads, IG + shorts follow
          const _ShareTrio(),
          const Spacer(flex: 1),
          Text('YOUR TURN', style: AppTextStyles.kicker),
          const SizedBox(height: PrSpacing.xs + 2),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: AppTextStyles.displayMedium.copyWith(
                fontSize: 32,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              children: [
                const TextSpan(text: 'Let\'s post your\n'),
                TextSpan(
                  text: 'first reel.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: PrSpacing.sm),
          Text(
            'One tap to WhatsApp Status, Reels, or Shorts.\nNothing uploads. Nothing watermarks. Ever.',
            style: AppTextStyles.bodyLarge.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.55,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: PrSpacing.lg),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: PrSpacing.xs,
            runSpacing: PrSpacing.xs,
            children: const [
              _TrustChip(icon: Icons.offline_bolt_rounded, label: 'Offline'),
              _TrustChip(icon: Icons.hd_rounded, label: '720p HD'),
              _TrustChip(
                  icon: Icons.cloud_off_rounded, label: 'No upload'),
              _TrustChip(
                  icon: Icons.account_circle_outlined, label: 'No account'),
            ],
          ),
          const Spacer(flex: 1),
        ],
      ),
    );
  }
}

class _ShareTrio extends StatelessWidget {
  const _ShareTrio();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: PrSpacing.lg, vertical: PrSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(PrRadius.xl),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.7,
        ),
      ),
      child: Column(
        children: [
          // Top row — reel thumb
          Container(
            width: 110,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(PrRadius.md),
              border: Border.all(
                color: AppColors.brandEmber.withValues(alpha: 0.5),
                width: 1.3,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brandEmber.withValues(alpha: 0.25),
                  blurRadius: 28,
                  spreadRadius: -4,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(PrRadius.md - 2),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF251A11), Color(0xFF0A0807)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Icon(PrIcons.check,
                        color: AppColors.signalLeaf, size: 14),
                  ),
                  Center(
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.18),
                        border:
                            Border.all(color: Colors.white.withValues(alpha: 0.7)),
                      ),
                      child: const Icon(PrIcons.play,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 6,
                    right: 6,
                    child: Text('READY',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.brandEmberSoft,
                          fontSize: 8,
                          letterSpacing: 1.8,
                          fontWeight: FontWeight.w800,
                        )),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: PrSpacing.md),
          // Three destination icons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ShareIcon(
                color: const Color(0xFF25D366),
                icon: Icons.chat_rounded,
                label: 'WhatsApp',
                prominent: true,
              ),
              const SizedBox(width: PrSpacing.sm),
              _ShareIcon(
                color: const Color(0xFFE1306C),
                icon: Icons.camera_alt_rounded,
                label: 'Reels',
              ),
              const SizedBox(width: PrSpacing.sm),
              _ShareIcon(
                color: const Color(0xFFFF0000),
                icon: Icons.play_arrow_rounded,
                label: 'Shorts',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShareIcon extends StatelessWidget {
  const _ShareIcon({
    required this.color,
    required this.icon,
    required this.label,
    this.prominent = false,
  });
  final Color color;
  final IconData icon;
  final String label;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: prominent ? 44 : 36,
          height: prominent ? 44 : 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: prominent ? 0.9 : 0.18),
            border: Border.all(
              color: color.withValues(alpha: prominent ? 1 : 0.35),
              width: prominent ? 0 : 1,
            ),
            boxShadow: prominent
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: prominent ? 20 : 16,
            color: prominent ? Colors.white : color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: AppTextStyles.labelSmall.copyWith(
              color: prominent
                  ? color
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 10,
              fontWeight: prominent ? FontWeight.w800 : FontWeight.w600,
            )),
      ],
    );
  }
}

class _TrustChip extends StatelessWidget {
  const _TrustChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: PrSpacing.sm, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(PrRadius.pill),
        border: Border.all(color: scheme.outlineVariant, width: 0.7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.signalLeaf),
          const SizedBox(width: 5),
          Text(label,
              style: AppTextStyles.labelSmall.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
              )),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Sprocket divider — the "this is cinema" editorial tell.
// ════════════════════════════════════════════════════════════════════════════

class _SprocketDivider extends StatelessWidget {
  const _SprocketDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _dot(), _gap(), _dot(), _gap(),
        const SizedBox(width: 10),
        Container(
          width: 28,
          height: 1,
          color: AppColors.brandEmber.withValues(alpha: 0.6),
        ),
        const SizedBox(width: 10),
        _dot(), _gap(), _dot(),
      ],
    );
  }

  Widget _dot() => Container(
        width: 4,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.brandEmber,
          shape: BoxShape.circle,
        ),
      );
  Widget _gap() => const SizedBox(width: 6);
}
