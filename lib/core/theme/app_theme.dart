import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const tngBlue = Color(0xFF0066FF);
  static const tngBlueMid = Color(0xFF0057E0);
  static const tngBlueDark = Color(0xFF003DB8);
  static const scaffoldBg = Color(0xFFF1F5F9);

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: tngBlue),
      scaffoldBackgroundColor: scaffoldBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: const CardThemeData(
        margin: EdgeInsets.zero,
        color: Colors.white,
        elevation: 0,
        shadowColor: Color(0x18000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
  }
}
