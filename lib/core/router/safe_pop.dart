import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_router.dart';

/// Pop back if there's a navigation-stack entry to pop to; otherwise
/// fall back to Home. Use on every screen-level back button in the app.
///
/// Needed because most of our flows reach a screen via `context.go(...)`
/// or `context.pushReplacement(...)`, both of which reset the back
/// stack. A plain `context.pop()` on those entry paths silently does
/// nothing, leaving the user stranded. This helper always lands
/// somewhere sensible.
///
/// Pair with a `PopScope(canPop: false, onPopInvokedWithResult: ...)`
/// on the Scaffold so the Android hardware back button / swipe-back
/// gesture uses the same fallback.
void safePop(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(AppRoutes.home);
  }
}

/// Standard `PopScope` builder that wires the hardware/system back
/// button through [safePop]. Returns a widget tree that intercepts the
/// pop, runs the fallback, and prevents the route from popping itself.
Widget withSafePop({required Widget child}) {
  return Builder(
    builder: (context) => PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        safePop(context);
      },
      child: child,
    ),
  );
}
