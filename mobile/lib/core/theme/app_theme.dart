import 'package:flutter/material.dart';

class AppTheme {
  static const tngBlue = Color(0xFF0061A8);
  static const tngBlueDark = Color(0xFF004A9D);
  static const offlineMuted = Color(0xFF6B7280);
  static const successGreen = Color(0xFF16A34A);
  static const dangerRed = Color(0xFFDC2626);

  static final lightTheme = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: tngBlue,
    scaffoldBackgroundColor: const Color(0xFFF5F6FA),
    appBarTheme: const AppBarTheme(
      backgroundColor: tngBlue,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: tngBlue,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}
