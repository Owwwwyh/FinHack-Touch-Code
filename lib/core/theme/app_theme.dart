// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  // TNG brand blue (online state)
  static const tngBlue = Color(0xFF0061A8);
  static const tngBlueDark = Color(0xFF004A9D);
  // Muted tones for offline state (not red — offline is a feature, not an error)
  static const offlineGrey = Color(0xFF6B7280);
  static const offlineBg   = Color(0xFFE5E7EB);
  // Backgrounds
  static const scaffoldBg  = Color(0xFFF5F6FA);
  static const cardBg      = Color(0xFFFFFFFF);
  // Success
  static const settled     = Color(0xFF16A34A);
  static const pending     = Color(0xFFF59E0B);

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: tngBlue,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: scaffoldBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: tngBlueDark,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: const CardThemeData(
      color: cardBg,
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: tngBlue,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: Color(0xFF1F2937)),
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
      bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
    ),
  );
}
