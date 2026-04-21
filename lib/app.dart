import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/services/shared_media_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'providers/project_provider.dart';

class PromoReelApp extends StatelessWidget {
  const PromoReelApp({super.key, this.showOnboarding = false});
  final bool showOnboarding;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp.router(
        title: 'PromoReel',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        // Dark by default — the brand is tuned for it. Light mode is
        // wired up and ready; flip to ThemeMode.system (or add an in-app
        // toggle) when we want to expose it to users.
        themeMode: ThemeMode.dark,
        routerConfig: buildRouter(showOnboarding: showOnboarding),
        builder: (context, child) {
          SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
          final isDark = Theme.of(context).brightness == Brightness.dark;
          SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarColor:
                isDark ? AppColors.canvasDark : AppColors.canvasLight,
            systemNavigationBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
          ));
          return _SharedMediaGate(child: child ?? const SizedBox.shrink());
        },
      ),
    );
  }
}

/// Listens for photos/videos shared into PromoReel from other apps via
/// Android's share sheet. On first build and on every app resume, polls the
/// native queue; if anything is waiting, starts a new project with those
/// paths and navigates to the editor.
class _SharedMediaGate extends ConsumerStatefulWidget {
  const _SharedMediaGate({required this.child});
  final Widget child;

  @override
  ConsumerState<_SharedMediaGate> createState() => _SharedMediaGateState();
}

class _SharedMediaGateState extends ConsumerState<_SharedMediaGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumeShared());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _consumeShared();
    }
  }

  Future<void> _consumeShared() async {
    final paths = await SharedMediaService.getPendingSharedMedia();
    if (paths.isEmpty || !mounted) return;

    final clamped =
        paths.take(AppConstants.maxAssetsPerVideo).toList(growable: false);
    ref.read(projectProvider.notifier).startNew(clamped);
    if (!mounted) return;
    context.go(AppRoutes.editor);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
