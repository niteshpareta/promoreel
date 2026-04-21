import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../ui/tokens.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

/// PromoReel theme — "Studio Cinematic" for both dark and light.
///
/// Two themes are peers here, not a dark-first with a bolted-on light:
///   • **Dark**: warm blacks + ember brand. The default, tuned for indoor
///     editing and WhatsApp-Status-at-night workflow.
///   • **Light**: warm cream + deeper ember. Tuned for outdoor readability
///     on a shop counter under sunlight.
abstract final class AppTheme {
  static ThemeData get dark => _buildDark();
  static ThemeData get light => _buildLight();

  // ═══════════════════════════════════════════════════════════════════════
  // Dark
  // ═══════════════════════════════════════════════════════════════════════
  static ThemeData _buildDark() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.brandEmber,
      onPrimary: AppColors.onBrand,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.brandEmberSoft,
      secondary: AppColors.signalCrimson,
      onSecondary: AppColors.onSecondary,
      secondaryContainer: AppColors.signalCrimsonSoft,
      onSecondaryContainer: AppColors.signalCrimson,
      tertiary: AppColors.proAurum,
      onTertiary: Color(0xFF1A1205),
      surface: AppColors.surfaceDark,
      onSurface: AppColors.contentPrimaryDark,
      surfaceContainerLowest: AppColors.canvasDark,
      surfaceContainerLow: AppColors.surfaceDark,
      surfaceContainer: AppColors.surfaceRaisedDark,
      surfaceContainerHigh: AppColors.surfaceRaisedDark,
      surfaceContainerHighest: AppColors.surfaceOverlayDark,
      onSurfaceVariant: AppColors.contentSecondaryDark,
      outline: AppColors.borderDark,
      outlineVariant: AppColors.hairlineDark,
      error: AppColors.signalError,
      onError: Colors.white,
      errorContainer: AppColors.signalErrorSoft,
      onErrorContainer: AppColors.signalError,
      scrim: AppColors.scrim,
      inverseSurface: AppColors.canvasLight,
      onInverseSurface: AppColors.contentPrimaryLight,
      inversePrimary: AppColors.brandEmberDeep,
    );
    return _buildBase(scheme, Brightness.dark);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Light
  // ═══════════════════════════════════════════════════════════════════════
  static ThemeData _buildLight() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.brandEmberDeep, // darker on light for contrast
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFFBE0B8),
      onPrimaryContainer: Color(0xFF4A2B06),
      secondary: AppColors.signalCrimson,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFFBDCE7),
      onSecondaryContainer: Color(0xFF5C1730),
      tertiary: AppColors.proAurumDeep,
      onTertiary: Colors.white,
      surface: AppColors.surfaceLight,
      onSurface: AppColors.contentPrimaryLight,
      surfaceContainerLowest: AppColors.canvasLight,
      surfaceContainerLow: AppColors.canvasLight,
      surfaceContainer: AppColors.surfaceRaisedLight,
      surfaceContainerHigh: AppColors.surfaceOverlayLight,
      surfaceContainerHighest: AppColors.surfaceOverlayLight,
      onSurfaceVariant: AppColors.contentSecondaryLight,
      outline: AppColors.borderLight,
      outlineVariant: AppColors.hairlineLight,
      error: Color(0xFFBA1A1A),
      onError: Colors.white,
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF410002),
      scrim: AppColors.scrim,
      inverseSurface: AppColors.surfaceDark,
      onInverseSurface: AppColors.contentPrimaryDark,
      inversePrimary: AppColors.brandEmberSoft,
    );
    return _buildBase(scheme, Brightness.light);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Shared base
  // ═══════════════════════════════════════════════════════════════════════
  static ThemeData _buildBase(ColorScheme scheme, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final canvas =
        isDark ? AppColors.canvasDark : AppColors.canvasLight;
    final hairline =
        isDark ? AppColors.hairlineDark : AppColors.hairlineLight;
    final overlay =
        isDark ? AppColors.surfaceOverlayDark : AppColors.surfaceOverlayLight;
    final primaryText =
        isDark ? AppColors.contentPrimaryDark : AppColors.contentPrimaryLight;
    final secondaryText =
        isDark ? AppColors.contentSecondaryDark : AppColors.contentSecondaryLight;
    final hintText =
        isDark ? AppColors.contentMutedDark : AppColors.contentMutedLight;

    final textTheme = TextTheme(
      displayLarge: AppTextStyles.displayLarge.copyWith(color: primaryText),
      displayMedium: AppTextStyles.displayMedium.copyWith(color: primaryText),
      displaySmall: AppTextStyles.displaySmall.copyWith(color: primaryText),
      headlineLarge: AppTextStyles.headlineLarge.copyWith(color: primaryText),
      headlineMedium: AppTextStyles.headlineMedium.copyWith(color: primaryText),
      headlineSmall: AppTextStyles.headlineSmall.copyWith(color: primaryText),
      titleLarge: AppTextStyles.titleLarge.copyWith(color: primaryText),
      titleMedium: AppTextStyles.titleMedium.copyWith(color: primaryText),
      titleSmall: AppTextStyles.titleSmall.copyWith(color: primaryText),
      bodyLarge: AppTextStyles.bodyLarge.copyWith(color: primaryText),
      bodyMedium: AppTextStyles.bodyMedium.copyWith(color: primaryText),
      bodySmall: AppTextStyles.bodySmall.copyWith(color: secondaryText),
      labelLarge: AppTextStyles.labelLarge.copyWith(color: primaryText),
      labelMedium: AppTextStyles.labelMedium.copyWith(color: primaryText),
      labelSmall: AppTextStyles.labelSmall.copyWith(color: secondaryText),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      splashFactory: InkRipple.splashFactory,
      textTheme: textTheme,

      // ── AppBar — flat, reads as "canvas extends under system chrome" ──
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        iconTheme: IconThemeData(color: primaryText, size: 22),
        titleTextStyle: textTheme.titleLarge,
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: canvas,
        selectedItemColor: scheme.primary,
        unselectedItemColor: secondaryText,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: AppTextStyles.labelSmall,
        unselectedLabelStyle: AppTextStyles.labelSmall,
      ),

      cardTheme: CardThemeData(
        color: isDark
            ? AppColors.surfaceRaisedDark
            : AppColors.surfaceRaisedLight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PrRadius.lg),
          side: BorderSide(color: hairline, width: 0.7),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: overlay,
          disabledForegroundColor: hintText,
          minimumSize: const Size(double.infinity, 54),
          maximumSize: const Size(double.infinity, 60),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PrRadius.md),
          ),
          textStyle: AppTextStyles.labelLarge,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: PrSpacing.xl),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryText,
          minimumSize: const Size(double.infinity, 54),
          side: BorderSide(color: hairline, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PrRadius.md),
          ),
          textStyle: AppTextStyles.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: PrSpacing.xl),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: AppTextStyles.labelLarge,
          padding: const EdgeInsets.symmetric(
              horizontal: PrSpacing.md, vertical: PrSpacing.xs),
          minimumSize: const Size(0, 40),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: primaryText,
          padding: const EdgeInsets.all(PrSpacing.sm),
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PrRadius.sm),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor:
            isDark ? AppColors.surfaceDark : AppColors.surfaceRaisedLight,
        hintStyle: AppTextStyles.bodyLarge.copyWith(color: hintText),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: PrSpacing.md, vertical: PrSpacing.sm + 2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PrRadius.md),
          borderSide: BorderSide(color: hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PrRadius.md),
          borderSide: BorderSide(color: hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PrRadius.md),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PrRadius.md),
          borderSide: BorderSide(color: scheme.error),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: isDark
            ? AppColors.surfaceRaisedDark
            : AppColors.surfaceOverlayLight,
        selectedColor: scheme.primary,
        labelStyle: AppTextStyles.labelMedium.copyWith(color: primaryText),
        secondaryLabelStyle:
            AppTextStyles.labelMedium.copyWith(color: scheme.onPrimary),
        side: BorderSide(color: hairline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PrRadius.pill),
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: PrSpacing.md, vertical: PrSpacing.xs),
        showCheckmark: false,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark
            ? AppColors.surfaceRaisedDark
            : AppColors.surfaceRaisedLight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(PrRadius.xl),
          ),
        ),
        showDragHandle: true,
        dragHandleColor: hairline,
        dragHandleSize: const Size(44, 4),
      ),

      dividerTheme: DividerThemeData(
        color: hairline,
        thickness: 0.7,
        space: 1,
      ),

      iconTheme: IconThemeData(color: primaryText, size: 22),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: hairline,
        circularTrackColor: hairline,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: overlay,
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(color: primaryText),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PrRadius.md),
          side: BorderSide(color: hairline),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        actionTextColor: scheme.primary,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? scheme.primary
              : hintText,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? scheme.primary.withValues(alpha: 0.3)
              : hairline,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: overlay,
          borderRadius: BorderRadius.circular(PrRadius.sm),
          border: Border.all(color: hairline),
        ),
        textStyle: AppTextStyles.labelSmall.copyWith(color: primaryText),
        padding: const EdgeInsets.symmetric(
            horizontal: PrSpacing.sm, vertical: PrSpacing.xs),
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
