import 'package:flutter/material.dart';

class AppColors {
  static const dark = Color(0xFF14181B);      // header background
  static const dark2 = Color(0xFF232A2E);     // header gradient start
  static const dark3 = Color(0xFF1C2226);     // quick-action panel
  static const bg = Color(0xFFF2F4F5);        // page background
  static const green = Color(0xFF2ECC71);
  static const red = Color(0xFFEF5350);
  static const blue = Color(0xFF42A5F5);
  static const purple = Color(0xFF7E57C2);
  static const orange = Color(0xFFFFA726);
}

ThemeData buildTheme(Brightness brightness) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.green,
      brightness: brightness,
    ),
    scaffoldBackgroundColor:
        brightness == Brightness.light ? AppColors.bg : null,
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
  );
}