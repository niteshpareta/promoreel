import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/home/home_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/picker/picker_screen.dart';
import '../../features/caption/caption_wizard_screen.dart';
import '../../features/style/style_picker_screen.dart';
import '../../features/review/review_screen.dart';
import '../../features/editor/editor_screen.dart';
import '../../features/export/export_screen.dart';
import '../../features/branding/branding_screen.dart';
import '../../features/player/video_player_screen.dart';
import '../../features/catalog/catalog_screen.dart';
import '../../features/paywall/paywall_screen.dart';

abstract final class AppRoutes {
  static const onboarding   = '/onboarding';
  static const home         = '/';
  static const picker       = '/picker';
  static const captionWizard = '/caption-wizard';
  static const stylePicker  = '/style-picker';
  static const review       = '/review';
  static const editor       = '/editor';
  static const export       = '/export';
  static const branding     = '/branding';
  static const player       = '/player';
  static const paywall      = '/paywall';
  static const catalog      = '/catalog';
}

// Keep for any code that still references appRouter directly
final appRouter = buildRouter();

GoRouter buildRouter({bool showOnboarding = false}) => GoRouter(
  initialLocation: showOnboarding ? AppRoutes.onboarding : AppRoutes.home,
  routes: [
    GoRoute(path: AppRoutes.onboarding,    builder: (ctx, s) => const OnboardingScreen()),
    GoRoute(path: AppRoutes.home,          builder: (ctx, s) => const HomeScreen()),
    GoRoute(path: AppRoutes.picker,        builder: (ctx, s) => const PickerScreen()),
    GoRoute(path: AppRoutes.captionWizard, builder: (ctx, s) => const CaptionWizardScreen()),
    GoRoute(path: AppRoutes.stylePicker,   builder: (ctx, s) => const StylePickerScreen()),
    GoRoute(path: AppRoutes.review,        builder: (ctx, s) => const ReviewScreen()),
    GoRoute(path: AppRoutes.editor,        builder: (ctx, s) => const EditorScreen()),
    GoRoute(path: AppRoutes.export,        builder: (ctx, s) => const ExportScreen()),
    GoRoute(path: AppRoutes.branding,      builder: (ctx, s) => const BrandingScreen()),
    GoRoute(
      path: AppRoutes.player,
      builder: (ctx, s) => VideoPlayerScreen(
        videoPath: s.uri.queryParameters['path'] ?? '',
      ),
    ),
    GoRoute(path: AppRoutes.catalog, builder: (ctx, s) => const CatalogScreen()),
    GoRoute(
      path: AppRoutes.paywall,
      builder: (ctx, s) => PaywallScreen(
        highlightTier: s.uri.queryParameters['tier'] ?? 'pro',
      ),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(child: Text('Page not found: ${state.uri}')),
  ),
);
