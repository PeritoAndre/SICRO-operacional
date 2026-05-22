import 'package:flutter/material.dart';

class AppColors {
  static const base = Color(0xFF060B14);
  static const panel = Color(0xFF0A1628);
  static const card = Color(0xFF0F1C35);
  static const active = Color(0xFF1A3A8F);
  static const border = Color(0xFF1A3060);
  static const gold = Color(0xFFF0B429);
  static const textPrimary = Color(0xFFF0F4FF);
  static const textSecondary = Color(0xFF9AA8C7);
  static const success = Color(0xFF3DB87A);
  static const danger = Color(0xFFC94040);
}

class AppTheme {
  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.active,
      brightness: Brightness.dark,
      surface: AppColors.panel,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.base,
      colorScheme: scheme.copyWith(
        primary: AppColors.gold,
        secondary: AppColors.active,
        surface: AppColors.panel,
        error: AppColors.danger,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.panel,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.4),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.base,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.gold,
        textColor: AppColors.textPrimary,
      ),
    );
  }
}
