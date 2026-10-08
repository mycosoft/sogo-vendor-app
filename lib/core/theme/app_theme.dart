import 'package:flutter/material.dart';
import 'app_colors.dart';

class SogoSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

class SogoRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const pill = 999.0;
}

class SogoShadows {
  static const card = BoxShadow(
    color: Color(0x0F000000),
    blurRadius: 10,
    offset: Offset(0, 2),
  );

  static const elevated = BoxShadow(
    color: Color(0x14000000),
    blurRadius: 20,
    offset: Offset(0, 6),
  );
}

ThemeData buildSogoTheme() {
  final base = ThemeData(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: SogoColors.surfaceMuted,
    colorScheme: const ColorScheme.light(
      primary: SogoColors.primary,
      onPrimary: SogoColors.textOnPrimary,
      secondary: SogoColors.secondary,
      onSecondary: SogoColors.textOnPrimary,
      tertiary: SogoColors.tertiary,
      surface: SogoColors.surface,
      onSurface: SogoColors.textPrimary,
      error: SogoColors.danger,
      onError: SogoColors.textOnPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: SogoColors.surface,
      foregroundColor: SogoColors.textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: SogoColors.textPrimary,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: SogoColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SogoRadius.md),
        borderSide: const BorderSide(color: SogoColors.surfaceBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SogoRadius.md),
        borderSide:
            const BorderSide(color: SogoColors.surfaceBorder, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SogoRadius.md),
        borderSide: const BorderSide(color: SogoColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: SogoSpacing.lg,
        vertical: SogoSpacing.md + 2,
      ),
      hintStyle: const TextStyle(
        fontFamily: 'Inter',
        color: SogoColors.textMuted,
        fontSize: 14,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: SogoColors.primary,
        foregroundColor: SogoColors.textOnPrimary,
        padding: const EdgeInsets.symmetric(
          horizontal: SogoSpacing.xl,
          vertical: SogoSpacing.md + 4,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SogoRadius.md),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    ),
    cardTheme: const CardThemeData(
      color: SogoColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(SogoRadius.lg)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: SogoColors.secondary,
      contentTextStyle: TextStyle(color: Colors.white, fontFamily: 'Inter'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
