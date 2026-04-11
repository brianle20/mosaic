import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData build() {
    const seedColor = Color(0xFF0D5C63);

    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F1E8),
      useMaterial3: true,
    );
  }
}
