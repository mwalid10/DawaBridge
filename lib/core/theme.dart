import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Brand palette — green / cream, aligned to the Figma Make prototype's
/// palette (Primary Green #2E8B57, Light Green #DDF5E5), with creamSoft
/// swapped to White Smoke #F5F5F5 and background swapped to pure white to
/// match surface. primaryLight/primaryDark/cream/creamDark are derived
/// tints/shades around those anchors (same hue family, offset
/// lightness/saturation) so the existing gradients keep their visual range.
class AppColors {
  AppColors._();

  static const primary = Color(0xFF2E8B57);
  static const primaryDark = Color(0xFF175F36);
  static const primaryLight = Color(0xFF48B076);
  static const primarySoft = Color(0xFFDDF5E5);

  static const cream = Color(0xFFF8E6AA);
  static const creamSoft = Color(0xFFF5F5F5);
  static const creamDark = Color(0xFFF0C662);

  static const surface = Color(0xFFFFFFFF);
  static const background = Color(0xFFFFFFFF);

  static const ink = Color(0xFF16231B);
  static const inkSoft = Color(0xFF5C6B61);
  static const inkFaint = Color(0xFF98A69C);
  static const divider = Color(0xFFE4E9E2);

  static const warn = Color(0xFFA15C00);
  static const warnBg = Color(0xFFFBF1DE);
  static const good = Color(0xFF1E7B4D);
  static const goodBg = Color(0xFFE8F5EC);
  static const danger = Color(0xFFC0392B);
  static const dangerBg = Color(0xFFFBEAE8);
}

class AppGradients {
  AppGradients._();

  static const hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primaryLight, AppColors.primaryDark],
  );

  static const cta = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.primaryLight, AppColors.primary],
  );

  static const cream = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.creamSoft, AppColors.cream],
  );
}

class AppRadius {
  AppRadius._();

  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 28.0;
  static const pill = 999.0;
}

class AppSpacing {
  AppSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
  static const huge = 40.0;
}

class AppShadows {
  AppShadows._();

  static const card = [
    BoxShadow(
      color: Color(0x14123B29),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];
}

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: Colors.white,
    secondary: AppColors.creamDark,
    surface: AppColors.surface,
    error: AppColors.danger,
  );

  const fontFamily = 'PlusJakartaSans';

  final textTheme = TextTheme(
    displayLarge: const TextStyle(fontFamily: fontFamily, fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.ink),
    headlineLarge: const TextStyle(fontFamily: fontFamily, fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.ink),
    headlineMedium: const TextStyle(fontFamily: fontFamily, fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.ink),
    titleLarge: const TextStyle(fontFamily: fontFamily, fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.ink),
    titleMedium: const TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink),
    bodyLarge: const TextStyle(fontFamily: fontFamily, fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.ink),
    bodyMedium: const TextStyle(fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.inkSoft),
    bodySmall: const TextStyle(fontFamily: fontFamily, fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.inkFaint),
    labelLarge: const TextStyle(fontFamily: fontFamily, fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink),
    labelMedium: const TextStyle(fontFamily: fontFamily, fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.inkSoft),
    labelSmall: const TextStyle(fontFamily: fontFamily, fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.inkFaint),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    fontFamily: fontFamily,
    textTheme: textTheme,
    scaffoldBackgroundColor: AppColors.background,
    splashFactory: InkRipple.splashFactory,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.headlineMedium,
      iconTheme: const IconThemeData(color: AppColors.ink),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.primarySoft.withValues(alpha: 0.35),
      labelStyle: textTheme.bodyMedium,
      floatingLabelStyle: textTheme.labelMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.inkFaint),
      prefixIconColor: AppColors.inkSoft,
      suffixIconColor: AppColors.inkSoft,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: const BorderSide(color: AppColors.danger, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        textStyle: textTheme.labelLarge,
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: textTheme.labelLarge,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.divider),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primarySoft,
      height: 68,
      elevation: 2,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return textTheme.labelMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600);
        }
        return textTheme.labelSmall?.copyWith(color: AppColors.inkFaint);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppColors.primary);
        }
        return const IconThemeData(color: AppColors.inkFaint);
      }),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: AppColors.surface,
      headerBackgroundColor: AppColors.primary,
      headerForegroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.ink,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      behavior: SnackBarBehavior.floating,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 1),
  );
}
