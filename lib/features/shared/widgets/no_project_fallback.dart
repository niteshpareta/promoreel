import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/ui/pr_empty_state.dart';
import '../../../core/ui/pr_icons.dart';

/// Shown when a wizard/editor screen is reached without an active project
/// (e.g. deep link, back from a partial flow, process resurrection). Uses
/// the unified empty-state primitive so the fallback doesn't look authored
/// by a different person than the rest of the app.
class NoProjectFallback extends StatelessWidget {
  const NoProjectFallback({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: PrEmptyState(
            icon: PrIcons.film,
            headline: 'No reel in progress',
            body:
                'Start a new promo from the home screen — pick a few photos and we\'ll handle the rest.',
            primaryLabel: 'Back home',
            onPrimary: () => context.go(AppRoutes.home),
          ),
        ),
      ),
    );
  }
}
