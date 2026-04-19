import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SubscriptionTier { free, proMonthly, proYearly, business }

extension SubscriptionTierX on SubscriptionTier {
  bool get isPro => this != SubscriptionTier.free;
  bool get isBusiness => this == SubscriptionTier.business;

  // Limits
  int get dailyVideoLimit => this == SubscriptionTier.free ? 3 : 999;

  // Quality
  bool get hasWatermark => this == SubscriptionTier.free;
  bool get has1080p => this == SubscriptionTier.business;
  bool get has60SecVideos => this == SubscriptionTier.business;

  // Motion styles
  int get maxMotionStyles => this == SubscriptionTier.free ? 4 : 12;

  // Branding
  int get brandingPresets => this == SubscriptionTier.free ? 1 : 3;

  // Pro features (unlocked at any paid tier)
  bool get hasMultiFormatLandscape => isPro;
  bool get hasAnimatedText => isPro;
  bool get hasQrCode => isPro;
  bool get hasCountdownTimer => isPro;
  bool get hasBeforeAfter => isPro;
  bool get hasVoiceOver => isPro;
  bool get hasBeatSync => isPro;
  bool get hasBackgroundRemoval => isPro;
  bool get hasDirectPosting => isPro;
  int get templateLibraryCount => this == SubscriptionTier.free ? 3 : 20;

  // Business-only features
  bool get hasProductCatalog => isBusiness;
  bool get hasBatchMode => isBusiness;
  bool get hasMultiBranding => isBusiness;

  // Display helpers
  String get displayName => switch (this) {
        SubscriptionTier.free => 'Free',
        SubscriptionTier.proMonthly || SubscriptionTier.proYearly => 'Pro',
        SubscriptionTier.business => 'Business',
      };

  String get tierLabel => switch (this) {
        SubscriptionTier.free => 'FREE',
        SubscriptionTier.proMonthly || SubscriptionTier.proYearly => 'PRO',
        SubscriptionTier.business => 'BUSINESS',
      };

  String get monthlyPrice => switch (this) {
        SubscriptionTier.free => '₹0',
        SubscriptionTier.proMonthly => '₹299',
        SubscriptionTier.proYearly => '₹167',
        SubscriptionTier.business => '₹999',
      };
}

class SubscriptionNotifier extends StateNotifier<SubscriptionTier> {
  SubscriptionNotifier() : super(SubscriptionTier.business);

  void upgrade(SubscriptionTier tier) => state = tier;
  void downgrade() => state = SubscriptionTier.free;

  bool canCreateVideo(int todayCount) => todayCount < state.dailyVideoLimit;
}

final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, SubscriptionTier>(
  (ref) => SubscriptionNotifier(),
);
