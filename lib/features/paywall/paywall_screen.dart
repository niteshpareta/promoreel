import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/ui/aurora_backdrop.dart';
import '../../core/ui/haptics.dart';
import '../../core/ui/pr_button.dart';
import '../../core/ui/pr_icons.dart';
import '../../core/ui/tokens.dart';
import '../../providers/subscription_provider.dart';

/// Unified paywall screen — trial-first model.
///
/// Handles three entry states with one layout:
/// • `SubscriptionTier.none` — first-time user landing here on install;
///   close button hidden so they must pick a plan.
/// • `SubscriptionTier.expired` — trial ran out without a purchase;
///   same hard-paywall treatment as `none`, different headline.
/// • `SubscriptionTier.trial` / paid — user browsed the upgrade screen
///   voluntarily; close button visible, can back out.
///
/// Three plans, all with a mandatory 3-day free trial:
///   Monthly  ₹299/mo
///   Annual   ₹1,999/yr  (default selected — "Best Value")
///   Lifetime ₹2,999      ("Most Loved")
///
/// The plumbing through `subscriptionProvider` is stubbed — `startTrial`
/// and `onPurchase` flip in-memory state only. Google Play Billing wires
/// in separately; TODOs mark the spots.
class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key, this.highlightTier = 'pro'});

  /// Kept for router back-compat. Not used in the new single-plan layout —
  /// all plans unlock everything now.
  final String highlightTier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(subscriptionProvider);
    final notifier = ref.read(subscriptionProvider.notifier);
    final dismissible = state.hasAccess; // only dismissible once entitled

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.55,
              child: AuroraBackdrop(intensity: 0.85, warmHue: true),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  PrSpacing.lg, PrSpacing.xs, PrSpacing.lg, PrSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top row — close button only when the paywall is soft
                  SizedBox(
                    height: 40,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (dismissible)
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => context.pop(),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Hero(state: state),
                          const SizedBox(height: PrSpacing.lg),
                          _PlanTile(
                            plan: PlanChoice.yearly,
                            selected: state.selectedPlan == PlanChoice.yearly,
                            onTap: () => notifier.selectPlan(PlanChoice.yearly),
                          ),
                          const SizedBox(height: PrSpacing.sm),
                          _PlanTile(
                            plan: PlanChoice.lifetime,
                            selected:
                                state.selectedPlan == PlanChoice.lifetime,
                            onTap: () =>
                                notifier.selectPlan(PlanChoice.lifetime),
                          ),
                          const SizedBox(height: PrSpacing.sm),
                          _PlanTile(
                            plan: PlanChoice.monthly,
                            selected: state.selectedPlan == PlanChoice.monthly,
                            onTap: () =>
                                notifier.selectPlan(PlanChoice.monthly),
                          ),
                          const SizedBox(height: PrSpacing.lg),
                          const _FeatureList(),
                        ],
                      ),
                    ),
                  ),
                  _CallToAction(
                    state: state,
                    onStartTrial: () => _onStart(context, ref),
                    onRestore: () => _onRestore(context, ref),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onStart(BuildContext context, WidgetRef ref) {
    PrHaptics.commit();
    final notifier = ref.read(subscriptionProvider.notifier);
    final state = ref.read(subscriptionProvider);
    final plan = state.selectedPlan;

    // TODO(pre-launch): replace with real `in_app_purchase` billing. For
    // now the trial is started locally; Play Billing will drive this in
    // production.
    if (!state.hasEverHadTrial && state.tier != SubscriptionTier.lifetime) {
      notifier.startTrial();
    } else {
      notifier.onPurchase(plan);
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.brandEmber.withValues(alpha: 0.95),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                state.hasEverHadTrial
                    ? '${plan.label} activated'
                    : '3-day free trial started',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      );
    if (context.canPop()) context.pop();
  }

  Future<void> _onRestore(BuildContext context, WidgetRef ref) async {
    await ref.read(subscriptionProvider.notifier).restore();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Checking your purchase history…'),
        ),
      );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero — the top block of copy. Headline changes based on entry state so
// expired users don't see "Welcome" after their trial ran out.
// ─────────────────────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  const _Hero({required this.state});
  final SubscriptionState state;

  String get _headline => switch (state.tier) {
        SubscriptionTier.expired => 'Your trial ended',
        SubscriptionTier.trial => 'Keep all your features',
        SubscriptionTier.monthly ||
        SubscriptionTier.yearly ||
        SubscriptionTier.lifetime =>
          'Manage your plan',
        _ => 'Unlock PromoReel',
      };

  String get _subhead => switch (state.tier) {
        SubscriptionTier.expired =>
          'Pick a plan below to keep creating — we kept your work safe.',
        SubscriptionTier.trial =>
          'Your trial is active. Lock in a plan to continue after day 3.',
        _ => '3 days free. Cancel anytime.',
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              AppColors.brandEmber.withValues(alpha: 0.35),
              AppColors.brandEmber.withValues(alpha: 0.05),
            ]),
          ),
          child: const Icon(Icons.auto_awesome_rounded,
              color: Colors.white, size: 32),
        ),
        const SizedBox(height: PrSpacing.sm + 2),
        Text(_headline,
            style: AppTextStyles.displaySmall,
            textAlign: TextAlign.center),
        const SizedBox(height: PrSpacing.xs),
        Text(_subhead,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plan tile — 3 of these stacked vertically. Visual hierarchy: selected
// tile ember-bordered, optional ribbon badge in the top-right corner.
// ─────────────────────────────────────────────────────────────────────────────

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final PlanChoice plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(PrRadius.md),
        onTap: () {
          PrHaptics.select();
          onTap();
        },
        child: Stack(
          children: [
            AnimatedContainer(
              duration: PrDuration.fast,
              curve: PrCurves.enter,
              padding: const EdgeInsets.symmetric(
                  horizontal: PrSpacing.md, vertical: PrSpacing.md),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.brandEmber.withValues(alpha: 0.14)
                    : scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(PrRadius.md),
                border: Border.all(
                  color: selected ? AppColors.brandEmber : scheme.outlineVariant,
                  width: selected ? 1.8 : 0.7,
                ),
              ),
              child: Row(
                children: [
                  // Left — radio indicator
                  AnimatedContainer(
                    duration: PrDuration.fast,
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? AppColors.brandEmber
                          : Colors.transparent,
                      border: Border.all(
                        color: selected
                            ? AppColors.brandEmber
                            : scheme.outlineVariant,
                        width: 2,
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check_rounded,
                            size: 14, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: PrSpacing.md),
                  // Label + hook
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(plan.label,
                                style: AppTextStyles.titleMedium.copyWith(
                                  fontWeight: FontWeight.w800,
                                )),
                            const SizedBox(width: PrSpacing.xs),
                            Text(plan.priceLabel,
                                style: AppTextStyles.titleMedium.copyWith(
                                  color: AppColors.brandEmber,
                                  fontWeight: FontWeight.w900,
                                )),
                            Text(' ${plan.priceCadence}',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                )),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(plan.hook,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: scheme.onSurfaceVariant,
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (plan.badge != null)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.brandEmber,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(PrRadius.md),
                      bottomLeft: Radius.circular(PrRadius.sm),
                    ),
                  ),
                  child: Text(
                    plan.badge!.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Feature checklist — reassures users what they're actually unlocking.
// Flat list of tick items; kept short so the scroll stays comfortable on
// small phones.
// ─────────────────────────────────────────────────────────────────────────────

class _FeatureList extends StatelessWidget {
  const _FeatureList();

  static const _items = <(IconData, String)>[
    (Icons.hd_rounded, 'Full HD 1080p export'),
    (Icons.animation_rounded, 'All 13 motion styles + entrance animations'),
    (Icons.auto_awesome_rounded, 'Canva-style caption presets + fonts'),
    (Icons.local_offer_rounded, 'Badge shapes · shine · glow · pill'),
    (Icons.qr_code_rounded, 'QR code + countdown overlays'),
    (Icons.auto_fix_high_rounded, 'Clean-background (subject isolation)'),
    (Icons.mic_rounded, 'Voiceover + beat-synced music'),
    (Icons.storefront_rounded, 'No watermark · unlimited exports'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(PrSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(PrRadius.md),
        border: Border.all(color: scheme.outlineVariant, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("What's included",
              style: AppTextStyles.labelMedium.copyWith(
                color: scheme.onSurfaceVariant,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w800,
              )),
          const SizedBox(height: PrSpacing.sm),
          for (final item in _items) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_rounded,
                    color: AppColors.brandEmber, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(item.$2,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      )),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom CTA block — primary button (Start trial / Buy), fine-print under
// it, and a restore+terms+privacy footer.
// ─────────────────────────────────────────────────────────────────────────────

class _CallToAction extends StatelessWidget {
  const _CallToAction({
    required this.state,
    required this.onStartTrial,
    required this.onRestore,
  });

  final SubscriptionState state;
  final VoidCallback onStartTrial;
  final VoidCallback onRestore;

  String get _ctaLabel {
    if (state.hasEverHadTrial) return 'Continue with ${state.selectedPlan.label}';
    return 'Start 3-day free trial';
  }

  String get _fineprint {
    final plan = state.selectedPlan;
    if (plan == PlanChoice.lifetime) {
      return 'One-time payment of ${plan.priceLabel}. No recurring charges.';
    }
    if (state.hasEverHadTrial) {
      return '${plan.priceLabel} ${plan.priceCadence} · cancel anytime in Google Play.';
    }
    return 'After 3 free days, ${plan.priceLabel} ${plan.priceCadence}. '
        'Cancel anytime in Google Play.';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PrButton(
          label: _ctaLabel,
          icon: PrIcons.check,
          onPressed: onStartTrial,
        ),
        const SizedBox(height: PrSpacing.xs),
        Text(_fineprint,
            style: AppTextStyles.labelSmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 10.5,
            ),
            textAlign: TextAlign.center),
        const SizedBox(height: PrSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _FooterLink(label: 'Restore purchases', onTap: onRestore),
            _FooterDot(),
            _FooterLink(label: 'Terms', onTap: () {
              // TODO(pre-launch): open https://promoreel.app/terms
            }),
            _FooterDot(),
            _FooterLink(label: 'Privacy', onTap: () {
              // TODO(pre-launch): open https://promoreel.app/privacy
            }),
          ],
        ),
      ],
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      );
}

class _FooterDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Text('·',
            style: AppTextStyles.labelSmall.copyWith(
              color: Theme.of(context).colorScheme.outlineVariant,
            )),
      );
}
