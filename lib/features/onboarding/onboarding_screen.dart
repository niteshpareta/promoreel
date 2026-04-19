import 'dart:math' show pi, cos, sin;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/router/app_router.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  int _currentPage = 0;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _markSeenAndGo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);
    if (mounted) context.go(AppRoutes.home);
  }

  void _next() {
    if (_currentPage < 2) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut);
    } else {
      _markSeenAndGo();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            // Skip
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, top: 4),
                child: TextButton(
                  onPressed: _markSeenAndGo,
                  child: Text('Skip',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondary)),
                ),
              ),
            ),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _Page1(pulse: _pulse),
                  const _Page2(),
                  const _Page3(),
                ],
              ),
            ),

            // Dots + button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                children: [
                  // Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      3,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _currentPage ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _currentPage
                              ? AppColors.primary
                              : AppColors.divider,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // CTA button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _currentPage == 2
                            ? AppColors.secondary
                            : AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Text(
                        _currentPage == 2 ? 'Start for Free' : 'Next',
                        style: AppTextStyles.titleMedium
                            .copyWith(color: Colors.white),
                      ),
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
}

// ── Page 1 — Brand intro + mock phone ────────────────────────────────────────

class _Page1 extends StatelessWidget {
  const _Page1({required this.pulse});
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 12),

          // Mock phone preview
          Expanded(
            child: Center(
              child: AnimatedBuilder(
                animation: pulse,
                builder: (_, __) => Container(
                  width: 160,
                  height: 260,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E0A4A), Color(0xFF2D1B69)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: AppColors.primary
                          .withValues(alpha: 0.3 + 0.3 * pulse.value),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary
                            .withValues(alpha: 0.15 + 0.15 * pulse.value),
                        blurRadius: 40,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Mock slide image placeholder
                      ClipRRect(
                        borderRadius: BorderRadius.circular(26),
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF0F0630),
                                Color(0xFF1E0A4A),
                                Color(0xFF2D1B69),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Store icon
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary
                                      .withValues(alpha: 0.2),
                                  border: Border.all(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.5)),
                                ),
                                child: const Icon(Icons.store_rounded,
                                    color: AppColors.primary, size: 28),
                              ),
                              const SizedBox(height: 12),
                              // Mock text lines
                              Container(
                                width: 100,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: 70,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Offer badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text('50% OFF',
                                    style: AppTextStyles.labelSmall.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Bottom branding strip
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(26)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.store_rounded,
                                  color: AppColors.primary, size: 12),
                              const SizedBox(width: 4),
                              Text('My Shop',
                                  style: AppTextStyles.labelSmall.copyWith(
                                      fontSize: 9, color: Colors.white70)),
                            ],
                          ),
                        ),
                      ),
                      // Play button overlay
                      Center(
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                          child: const Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 22),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 28),
          // Logo row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ReelLogoMini(),
              const SizedBox(width: 8),
              Text('PromoReel',
                  style: AppTextStyles.titleLarge.copyWith(
                      fontWeight: FontWeight.w800, fontSize: 20)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Make shop videos in 60 seconds',
            style: AppTextStyles.headlineSmall
                .copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Daily offers, new stock, greetings — share directly to WhatsApp Status',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── Page 2 — Motion styles showcase ──────────────────────────────────────────

class _Page2 extends StatelessWidget {
  const _Page2();

  static const _styles = [
    ('Slow Zoom', Icons.zoom_in_rounded, Color(0xFF7C4DFF), 'Jewelry'),
    ('Bold Slide', Icons.swipe_right_rounded, Color(0xFFFF6E40), 'Electronics'),
    ('Beat Sync', Icons.graphic_eq_rounded, Color(0xFF00C853), 'Offers'),
    ('Caption Stack', Icons.layers_rounded, Color(0xFFFFB300), 'Real Estate'),
    ('Ken Burns', Icons.panorama_rounded, Color(0xFF29B6F6), 'Wedding'),
    ('Flash Reveal', Icons.flash_on_rounded, Color(0xFFE53935), 'Sales'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Style grid
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: _styles.map((s) {
                final (name, icon, color, tag) = s;
                return Container(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: color.withValues(alpha: 0.3), width: 1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withValues(alpha: 0.15),
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      const SizedBox(height: 6),
                      Text(name,
                          style: AppTextStyles.labelSmall.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 2),
                      Text(tag,
                          style: AppTextStyles.labelSmall.copyWith(
                              fontSize: 8, color: color),
                          textAlign: TextAlign.center),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 24),
          Text(
            '12 Professional Motion Styles',
            style: AppTextStyles.headlineSmall
                .copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'From subtle jewelry elegance to energetic sale announcements — a perfect style for every business',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── Page 3 — WhatsApp share + free trial ─────────────────────────────────────

class _Page3 extends StatelessWidget {
  const _Page3();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // WhatsApp share illustration
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Phone → WhatsApp flow
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Phone icon
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.15),
                          border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.4)),
                        ),
                        child: const Icon(Icons.phone_android_rounded,
                            color: AppColors.primary, size: 34),
                      ),
                      // Arrow
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: List.generate(
                            3,
                            (i) => Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.secondary
                                    .withValues(alpha: 0.3 + i * 0.25),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // WhatsApp icon
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF25D366).withValues(alpha: 0.15),
                          border: Border.all(
                              color: const Color(0xFF25D366)
                                  .withValues(alpha: 0.4)),
                        ),
                        child: const Icon(Icons.chat_rounded,
                            color: Color(0xFF25D366), size: 34),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Feature chips
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      _Chip(Icons.offline_bolt_rounded, 'Works offline',
                          AppColors.primary),
                      _Chip(Icons.hd_rounded, '720p HD video',
                          AppColors.secondary),
                      _Chip(Icons.no_photography_rounded, 'No watermark',
                          AppColors.success),
                      _Chip(Icons.timer_rounded, 'Ready in 30s',
                          const Color(0xFFFFB300)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Free trial badge
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.secondary.withValues(alpha: 0.15),
                  AppColors.primary.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.secondary.withValues(alpha: 0.2),
                  ),
                  child: const Icon(Icons.workspace_premium_rounded,
                      color: AppColors.secondary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('3-day free Pro trial',
                          style: AppTextStyles.titleSmall
                              .copyWith(fontWeight: FontWeight.w800)),
                      Text('All features unlocked — no credit card needed',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Share to WhatsApp in One Tap',
            style: AppTextStyles.headlineSmall
                .copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Export directly to WhatsApp Status, no extra steps',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.icon, this.label, this.color);
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: AppTextStyles.labelSmall
                  .copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Mini reel logo ────────────────────────────────────────────────────────────

class _ReelLogoMini extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF9C6FFF), AppColors.primary, Color(0xFF5E35B1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(9),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: CustomPaint(painter: _MiniReelPainter()),
    );
  }
}

class _MiniReelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final ro = size.width * 0.30;
    final ri = size.width * 0.10;
    final white = Paint()..color = Colors.white;
    final bg = Paint()..color = const Color(0xFF7C4DFF);

    canvas.drawCircle(Offset(cx, cy), ro, white);
    final holeR = size.width * 0.055;
    final ringR = size.width * 0.195;
    for (int i = 0; i < 6; i++) {
      final a = (i * 60 - 90) * pi / 180;
      canvas.drawCircle(
          Offset(cx + ringR * cos(a), cy + ringR * sin(a)), holeR, bg);
    }
    canvas.drawCircle(Offset(cx, cy), ri, bg);

    final tri = Paint()..color = const Color(0xFFFF6E40);
    final th = size.width * 0.13;
    final tw = size.width * 0.115;
    final path = Path()
      ..moveTo(cx - tw * 0.15, cy - th / 2)
      ..lineTo(cx - tw * 0.15 + tw, cy)
      ..lineTo(cx - tw * 0.15, cy + th / 2)
      ..close();
    canvas.drawPath(path, tri);
  }

  @override
  bool shouldRepaint(_MiniReelPainter old) => false;
}
