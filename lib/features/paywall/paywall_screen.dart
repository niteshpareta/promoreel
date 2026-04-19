import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/subscription_provider.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key, this.highlightTier = 'pro'});

  /// 'pro' or 'business' — which tier tab to open on
  final String highlightTier;

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  // 0 = Pro Monthly, 1 = Pro Yearly, 2 = Business Monthly
  int _selectedPlan = 1;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this,
        initialIndex: widget.highlightTier == 'business' ? 1 : 0);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  bool get _isBusinessTab => _tab.index == 1;

  void _purchase() {
    final tier = _selectedPlan == 2
        ? SubscriptionTier.business
        : _selectedPlan == 1
            ? SubscriptionTier.proYearly
            : SubscriptionTier.proMonthly;

    // TODO: replace with in_app_purchase flow before release
    ref.read(subscriptionProvider.notifier).upgrade(tier);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${tier.displayName} activated! Enjoy all features.'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(subscriptionProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            // Close + current plan
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
              child: Row(
                children: [
                  if (current.isPro)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.proGoldContainer,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: AppColors.proGold.withValues(alpha: 0.5)),
                      ),
                      child: Text('Current: ${current.displayName}',
                          style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.proGold, fontSize: 11)),
                    ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textSecondary),
                    onPressed: () => context.pop(),
                  ),
                ],
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        AppColors.proGold.withValues(alpha: 0.25),
                        Colors.transparent,
                      ]),
                    ),
                    child: const Icon(Icons.workspace_premium_rounded,
                        color: AppColors.proGold, size: 46),
                  ),
                  const SizedBox(height: 10),
                  Text('Unlock PromoReel',
                      style: AppTextStyles.displayMedium,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Text('No limits. No watermarks. Pure results.',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondary),
                      textAlign: TextAlign.center),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Pro / Business tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tab,
                  indicator: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: AppColors.primary, width: 1.5),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelStyle: AppTextStyles.labelMedium
                      .copyWith(fontWeight: FontWeight.w700),
                  unselectedLabelStyle: AppTextStyles.labelMedium,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  tabs: const [
                    Tab(text: 'Pro'),
                    Tab(text: 'Business'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 4),

            // Feature list + plan cards
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: _isBusinessTab
                    ? _BusinessContent(
                        selectedPlan: _selectedPlan,
                        onSelectPlan: (i) => setState(() => _selectedPlan = i),
                      )
                    : _ProContent(
                        selectedPlan: _selectedPlan,
                        onSelectPlan: (i) => setState(() => _selectedPlan = i),
                      ),
              ),
            ),

            // CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
              child: _CTASection(
                selectedPlan: _selectedPlan,
                onPurchase: _purchase,
                currentTier: current,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pro content ───────────────────────────────────────────────────────────────

class _ProContent extends StatelessWidget {
  const _ProContent(
      {required this.selectedPlan, required this.onSelectPlan});
  final int selectedPlan;
  final void Function(int) onSelectPlan;

  static const _features = [
    (Icons.auto_awesome_rounded, 'All 12 Motion Styles',
        '8 more premium styles unlocked'),
    (Icons.music_note_rounded, '50 Music Tracks', 'Full royalty-free library'),
    (Icons.no_photography_rounded, 'No Watermark', 'Clean professional output'),
    (Icons.all_inclusive_rounded, 'Unlimited Videos', 'No daily caps'),
    (Icons.branding_watermark_rounded, '3 Branding Presets',
        'Shop, event & promo modes'),
    (Icons.qr_code_rounded, 'QR Code Overlay', 'Link to your store or offer'),
    (Icons.record_voice_over_rounded, 'Voice-over Recording',
        'Add your voice to reels'),
    (Icons.format_shapes_rounded, 'Animated Text', 'Dynamic text animations'),
    (Icons.timer_rounded, 'Countdown Timer', 'Urgency-driving overlays'),
    (Icons.compare_rounded, 'Before / After Slider', 'Show product transformations'),
    (Icons.share_rounded, 'Direct Platform Posting',
        'One-tap to Instagram, Facebook'),
    (Icons.auto_fix_high_rounded, 'Background Removal',
        'Smart subject extraction'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Everything in Pro',
            style: AppTextStyles.titleMedium
                .copyWith(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 10),
        ..._features.map((f) => _FeatureRow(icon: f.$1, title: f.$2, sub: f.$3)),
        const SizedBox(height: 20),
        _PlanCard(
          index: 0,
          isSelected: selectedPlan == 0,
          title: 'Pro Monthly',
          price: '₹299',
          period: '/mo',
          badge: null,
          note: 'Billed monthly',
          onTap: () => onSelectPlan(0),
        ),
        const SizedBox(height: 10),
        _PlanCard(
          index: 1,
          isSelected: selectedPlan == 1,
          title: 'Pro Yearly',
          price: '₹1,999',
          period: '/yr',
          badge: 'Save 44%',
          note: '₹167/mo — best value',
          onTap: () => onSelectPlan(1),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Business content ──────────────────────────────────────────────────────────

class _BusinessContent extends StatelessWidget {
  const _BusinessContent(
      {required this.selectedPlan, required this.onSelectPlan});
  final int selectedPlan;
  final void Function(int) onSelectPlan;

  static const _proFeatures = [
    (Icons.auto_awesome_rounded, 'Everything in Pro', 'All Pro features included'),
  ];

  static const _bizFeatures = [
    (Icons.hd_rounded, '1080p HD Export', 'Crisp 1080×1920 portrait video'),
    (Icons.access_time_rounded, '60-Second Videos',
        'Double the storytelling time'),
    (Icons.collections_rounded, 'Product Catalog Mode',
        'Multi-product showcase reels'),
    (Icons.copy_all_rounded, 'Batch Mode', 'Export multiple reels at once'),
    (Icons.palette_rounded, 'Multi-Branding Presets',
        'Up to 5 brand profiles'),
    (Icons.support_agent_rounded, 'Priority Support', 'Fast-track help desk'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Everything in Business',
            style: AppTextStyles.titleMedium
                .copyWith(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 10),
        ..._proFeatures.map((f) => _FeatureRow(
            icon: f.$1, title: f.$2, sub: f.$3, tint: AppColors.primary)),
        ..._bizFeatures
            .map((f) => _FeatureRow(icon: f.$1, title: f.$2, sub: f.$3)),
        const SizedBox(height: 20),
        _PlanCard(
          index: 2,
          isSelected: selectedPlan == 2,
          title: 'Business Monthly',
          price: '₹999',
          period: '/mo',
          badge: null,
          note: 'For serious creators',
          accent: AppColors.secondary,
          onTap: () => onSelectPlan(2),
        ),
        const SizedBox(height: 10),
        _PlanCard(
          index: 3,
          isSelected: selectedPlan == 3,
          title: 'Business Yearly',
          price: '₹7,999',
          period: '/yr',
          badge: 'Save 33%',
          note: '₹667/mo — best value',
          accent: AppColors.secondary,
          onTap: () => onSelectPlan(3),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _FeatureRow extends StatelessWidget {
  const _FeatureRow(
      {required this.icon,
      required this.title,
      required this.sub,
      this.tint});
  final IconData icon;
  final String title, sub;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final color = tint ?? AppColors.proGold;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleSmall),
                Text(sub,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          Icon(Icons.check_rounded, color: AppColors.success, size: 18),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.index,
    required this.isSelected,
    required this.title,
    required this.price,
    required this.period,
    required this.badge,
    required this.note,
    required this.onTap,
    this.accent,
  });

  final int index;
  final bool isSelected;
  final String title, price, period, note;
  final String? badge;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.1)
              : AppColors.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? color : Colors.transparent,
                border: Border.all(
                  color: isSelected ? color : AppColors.border,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      size: 13, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.titleMedium),
                  Text(note,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                RichText(
                  text: TextSpan(children: [
                    TextSpan(
                        text: price,
                        style: AppTextStyles.headlineSmall
                            .copyWith(color: AppColors.proGold)),
                    TextSpan(
                        text: period,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary)),
                  ]),
                ),
                if (badge != null)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.proGoldContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(badge!,
                        style: AppTextStyles.proBadge
                            .copyWith(color: AppColors.proGold)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CTASection extends StatelessWidget {
  const _CTASection({
    required this.selectedPlan,
    required this.onPurchase,
    required this.currentTier,
  });
  final int selectedPlan;
  final VoidCallback onPurchase;
  final SubscriptionTier currentTier;

  String get _label => switch (selectedPlan) {
        0 => 'Start Pro — ₹299/month',
        1 => 'Best Value — ₹1,999/year',
        2 => 'Go Business — ₹999/month',
        _ => 'Best Value — ₹7,999/year',
      };

  SubscriptionTier get _targetTier => switch (selectedPlan) {
        0 => SubscriptionTier.proMonthly,
        1 => SubscriptionTier.proYearly,
        _ => SubscriptionTier.business,
      };

  bool get _alreadyHas => currentTier == _targetTier ||
      (currentTier.isBusiness && _targetTier.isPro && !_targetTier.isBusiness);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _alreadyHas ? null : onPurchase,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.proGold,
              foregroundColor: AppColors.bgDark,
              disabledBackgroundColor: AppColors.bgSurface,
              disabledForegroundColor: AppColors.textSecondary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              textStyle: AppTextStyles.labelLarge
                  .copyWith(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            child: Text(_alreadyHas ? 'Already on this plan' : _label),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '3-day free trial · Cancel anytime · Payment via Google Play',
          style: AppTextStyles.labelSmall
              .copyWith(color: AppColors.textDisabled),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
