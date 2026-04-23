import 'package:flutter_riverpod/flutter_riverpod.dart';

/// All the states the subscription flow can be in. New installs start at
/// `none` and are required to pass through `trial` before ever reaching a
/// paid tier. Once the trial elapses without a purchase the user lands in
/// `expired` and the app shows a hard paywall.
enum SubscriptionTier {
  none,      // install-fresh, no trial taken yet — shown paywall before app use
  trial,     // 3-day free trial, full feature access
  expired,   // trial ended + no active subscription — hard paywall
  monthly,   // ₹299/month auto-renew
  yearly,    // ₹1,999/year auto-renew (best value badge)
  lifetime,  // ₹2,999 one-time, unlocks forever
}

extension SubscriptionTierX on SubscriptionTier {
  /// True if the user is currently entitled to paid features (including
  /// during the free trial). Paywall gates read this.
  bool get hasAccess => switch (this) {
        SubscriptionTier.trial => true,
        SubscriptionTier.monthly => true,
        SubscriptionTier.yearly => true,
        SubscriptionTier.lifetime => true,
        SubscriptionTier.none => false,
        SubscriptionTier.expired => false,
      };

  /// Display-friendly name for badges and settings.
  String get displayName => switch (this) {
        SubscriptionTier.none => 'Not started',
        SubscriptionTier.trial => 'Free Trial',
        SubscriptionTier.expired => 'Trial Expired',
        SubscriptionTier.monthly => 'Monthly',
        SubscriptionTier.yearly => 'Annual',
        SubscriptionTier.lifetime => 'Lifetime',
      };

  /// Short banner label used on the home trial-countdown strip.
  String get bannerLabel => switch (this) {
        SubscriptionTier.trial => 'Free Trial',
        SubscriptionTier.monthly => 'Monthly',
        SubscriptionTier.yearly => 'Annual',
        SubscriptionTier.lifetime => 'Lifetime',
        _ => '',
      };
}

/// Which of the 3 plan tiles the user has tapped on the paywall. Distinct
/// from `SubscriptionTier` because "selected on the screen" isn't yet
/// "purchased".
enum PlanChoice { monthly, yearly, lifetime }

extension PlanChoiceX on PlanChoice {
  String get label => switch (this) {
        PlanChoice.monthly => 'Monthly',
        PlanChoice.yearly => 'Annual',
        PlanChoice.lifetime => 'Lifetime',
      };

  /// Display price shown on the tile.
  String get priceLabel => switch (this) {
        PlanChoice.monthly => '₹299',
        PlanChoice.yearly => '₹1,999',
        PlanChoice.lifetime => '₹2,999',
      };

  String get priceCadence => switch (this) {
        PlanChoice.monthly => '/ month',
        PlanChoice.yearly => '/ year',
        PlanChoice.lifetime => 'one-time',
      };

  /// The headline hook underneath the price on each tile.
  String get hook => switch (this) {
        PlanChoice.monthly => '3-day free trial · cancel anytime',
        PlanChoice.yearly => 'Just ₹167/month · save 44%',
        PlanChoice.lifetime => 'One payment · yours forever',
      };

  /// Optional ribbon badge on the tile — null for monthly.
  String? get badge => switch (this) {
        PlanChoice.yearly => 'Best Value',
        PlanChoice.lifetime => 'Most Loved',
        PlanChoice.monthly => null,
      };

  /// Which final `SubscriptionTier` this plan maps to on purchase.
  SubscriptionTier get purchasedTier => switch (this) {
        PlanChoice.monthly => SubscriptionTier.monthly,
        PlanChoice.yearly => SubscriptionTier.yearly,
        PlanChoice.lifetime => SubscriptionTier.lifetime,
      };
}

/// Canonical trial length. Also controls the "X days left" strip copy.
const Duration kTrialDuration = Duration(days: 3);

/// Snapshot of the user's billing state. Kept as a record so rebuilding
/// is cheap and providers can `watch` it without wiring up N fields.
class SubscriptionState {
  const SubscriptionState({
    required this.tier,
    this.trialStartedAt,
    this.subscriptionExpiresAt,
    this.selectedPlan = PlanChoice.yearly,
    this.hasEverHadTrial = false,
  });

  final SubscriptionTier tier;

  /// When the trial was started. Null until [SubscriptionNotifier.startTrial]
  /// fires. Persists across launches once real storage wiring lands; today
  /// it's in-memory only.
  final DateTime? trialStartedAt;

  /// When a paid subscription will run out (not applicable to lifetime).
  final DateTime? subscriptionExpiresAt;

  /// Which plan tile is currently highlighted on the paywall. Defaults to
  /// `yearly` — the "Best Value" preference matches Play Store behaviour
  /// patterns and nudges ARPU upward.
  final PlanChoice selectedPlan;

  /// True once the user has ever started a trial. Prevents repeat trials
  /// after expiration — they must pay to come back.
  final bool hasEverHadTrial;

  bool get isTrialActive =>
      tier == SubscriptionTier.trial && trialDaysLeft > 0;

  int get trialDaysLeft {
    if (trialStartedAt == null) return 0;
    final elapsed = DateTime.now().difference(trialStartedAt!);
    final remaining = kTrialDuration - elapsed;
    return remaining.isNegative ? 0 : remaining.inDays + 1;
  }

  Duration get trialTimeLeft {
    if (trialStartedAt == null) return Duration.zero;
    final elapsed = DateTime.now().difference(trialStartedAt!);
    final remaining = kTrialDuration - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get hasAccess => tier.hasAccess;

  SubscriptionState copyWith({
    SubscriptionTier? tier,
    DateTime? trialStartedAt,
    DateTime? subscriptionExpiresAt,
    PlanChoice? selectedPlan,
    bool? hasEverHadTrial,
  }) =>
      SubscriptionState(
        tier: tier ?? this.tier,
        trialStartedAt: trialStartedAt ?? this.trialStartedAt,
        subscriptionExpiresAt:
            subscriptionExpiresAt ?? this.subscriptionExpiresAt,
        selectedPlan: selectedPlan ?? this.selectedPlan,
        hasEverHadTrial: hasEverHadTrial ?? this.hasEverHadTrial,
      );
}

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  // TODO(pre-launch): hydrate from SharedPreferences so trial / subscription
  // state survives app restarts, and from `in_app_purchase` so Play Store
  // entitlement is the source of truth. For now new sessions start fresh.
  SubscriptionNotifier()
      : super(const SubscriptionState(tier: SubscriptionTier.none));

  /// Starts the free trial. Mandatory first step before any feature use.
  /// Real Play flow: this maps to Google Play's "3-day free trial" period
  /// attached to the Monthly sub — user links a payment method, Play gives
  /// them 3 days free, and auto-renews unless they cancel.
  void startTrial() {
    if (state.hasEverHadTrial) return; // one-shot trial only
    state = state.copyWith(
      tier: SubscriptionTier.trial,
      trialStartedAt: DateTime.now(),
      hasEverHadTrial: true,
    );
  }

  /// Called when a purchase completes successfully. Today this just flips
  /// local state; before release this will be driven by `in_app_purchase`
  /// delivery events so Play Store entitlement is authoritative.
  void onPurchase(PlanChoice plan) {
    final now = DateTime.now();
    final expires = switch (plan) {
      PlanChoice.monthly => now.add(const Duration(days: 30)),
      PlanChoice.yearly => now.add(const Duration(days: 365)),
      PlanChoice.lifetime => null, // never expires
    };
    state = state.copyWith(
      tier: plan.purchasedTier,
      subscriptionExpiresAt: expires,
      selectedPlan: plan,
    );
  }

  /// Forces the "trial ran out + no purchase" state. Exposed for dev /
  /// testing of the hard-paywall UI.
  void forceExpire() {
    state = state.copyWith(tier: SubscriptionTier.expired);
  }

  /// Updates the tile highlighted on the paywall without purchasing.
  void selectPlan(PlanChoice plan) {
    state = state.copyWith(selectedPlan: plan);
  }

  /// Called by the "Restore purchases" button. Real flow: query Play
  /// Store for the user's existing entitlement and set state accordingly.
  Future<void> restore() async {
    // TODO(pre-launch): query in_app_purchase for past purchases.
  }

  /// Re-checks trial remaining time and flips to `expired` if it's run
  /// out. Called opportunistically from the app root so the user hits the
  /// hard paywall the moment their clock rolls past the trial window.
  void refreshTrialIfNeeded() {
    if (state.tier != SubscriptionTier.trial) return;
    if (state.trialDaysLeft <= 0) {
      state = state.copyWith(tier: SubscriptionTier.expired);
    }
  }
}

final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, SubscriptionState>(
  (ref) => SubscriptionNotifier(),
);

/// Feature-flag surface that callers across the app watch against. With
/// the trial-first model the tiering collapses: anyone with access gets
/// everything, and gating is binary (has access / doesn't). Flags are
/// kept here (not inlined) so if we later need to reintroduce a
/// Pro-vs-Business split, it's one file to edit.
extension SubscriptionStateFlags on SubscriptionState {
  /// Alias — "Pro" means anyone with entitlement (trial or paid).
  bool get isPro => hasAccess;

  /// Alias — any paid plan (not trial). Some older callers distinguish
  /// between trial-access and paid-access; keep the split available.
  bool get isBusiness =>
      tier == SubscriptionTier.monthly ||
      tier == SubscriptionTier.yearly ||
      tier == SubscriptionTier.lifetime;

  // ── Feature capabilities ─────────────────────────────────────────────

  int get dailyVideoLimit => hasAccess ? 999 : 3;

  bool get hasWatermark => !hasAccess;
  bool get has1080p => hasAccess;
  bool get has60SecVideos => hasAccess;

  /// Motion-style count — 4 free + "None" shown to non-subscribed users;
  /// the full library when entitled.
  int get maxMotionStyles => hasAccess ? 13 : 4;

  int get brandingPresets => hasAccess ? 3 : 1;

  bool get hasMultiFormatLandscape => hasAccess;
  bool get hasAnimatedText => hasAccess;
  bool get hasQrCode => hasAccess;
  bool get hasCountdownTimer => hasAccess;
  bool get hasBeforeAfter => hasAccess;
  bool get hasVoiceOver => hasAccess;
  bool get hasBeatSync => hasAccess;
  bool get hasBackgroundRemoval => hasAccess;
  bool get hasDirectPosting => hasAccess;
  int get templateLibraryCount => hasAccess ? 20 : 3;

  bool get hasProductCatalog => hasAccess;
  bool get hasBatchMode => hasAccess;
  bool get hasMultiBranding => hasAccess;

  /// Short label shown on the home badge / settings row ("Free Trial",
  /// "Annual", etc).
  String get tierLabel => tier.displayName;
}
