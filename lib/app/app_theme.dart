import 'package:flutter/material.dart';
import '../core/tadarruj_brand.dart';

class AppTheme {
  static ThemeData get lightTheme {
    final baseText = ThemeData.light().textTheme;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      scaffoldBackgroundColor: TadarrujColors.parchment,
      colorScheme: const ColorScheme.light(
        primary: TadarrujColors.emeraldDeep,
        secondary: TadarrujColors.sageGreen,
        tertiary: TadarrujColors.goldAccent,
        surface: TadarrujColors.parchment,
        surfaceContainerLow: TadarrujColors.beigeSoft,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: TadarrujColors.inkPrimary,
        onSurfaceVariant: TadarrujColors.warmGrey,
        outlineVariant: TadarrujColors.cardBorder,
      ),
      textTheme: baseText.copyWith(
        headlineSmall: baseText.headlineSmall?.copyWith(
          color: TadarrujColors.inkPrimary,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
        titleMedium: baseText.titleMedium?.copyWith(
          color: TadarrujColors.inkPrimary,
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: baseText.bodyMedium?.copyWith(
          color: TadarrujColors.inkPrimary,
          height: 1.45,
        ),
        bodySmall: baseText.bodySmall?.copyWith(
          color: TadarrujColors.warmGrey,
          height: 1.4,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: TadarrujColors.emeraldDeep,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: TadarrujColors.cardBorder, width: 1.1),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: TadarrujColors.emeraldDeep,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: TadarrujColors.emeraldDeep,
          backgroundColor: Colors.white,
          side: const BorderSide(color: TadarrujColors.emeraldPrimary, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: TadarrujColors.cardBorder,
        thickness: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    final baseText = ThemeData.dark().textTheme;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      scaffoldBackgroundColor: const Color(0xFF0F1614),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF52B788),
        secondary: Color(0xFF74C69D),
        tertiary: TadarrujColors.goldSoft,
        surface: Color(0xFF0F1614),
        surfaceContainerLow: Color(0xFF182420),
        onPrimary: Color(0xFF081C15),
        onSecondary: Color(0xFF081C15),
        onSurface: Color(0xFFF5F3EE),
        onSurfaceVariant: Color(0xFFB7C2BC),
        outlineVariant: Color(0xFF2B3D36),
      ),
      textTheme: baseText.copyWith(
        headlineSmall: baseText.headlineSmall?.copyWith(
          color: const Color(0xFFF5F3EE),
          fontWeight: FontWeight.w800,
        ),
        titleMedium: baseText.titleMedium?.copyWith(
          color: const Color(0xFFF5F3EE),
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: baseText.bodyMedium?.copyWith(
          color: const Color(0xFFF5F3EE),
        ),
        bodySmall: baseText.bodySmall?.copyWith(
          color: const Color(0xFFB7C2BC),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF13221D),
        foregroundColor: Color(0xFFF5F3EE),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF182420),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFF2B3D36), width: 1.1),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF52B788),
          foregroundColor: const Color(0xFF081C15),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF74C69D),
          side: const BorderSide(color: Color(0xFF3A5248), width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
