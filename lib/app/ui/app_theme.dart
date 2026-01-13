import 'package:flutter/material.dart';

class AppTheme {
  static const Color ink = Color(0xFF1F1E2B);
  static const Color mutedInk = Color(0xFF6B6A7A);
  static const Color card = Color(0xFFFFFFFF);
  static const Color accent = Color(0xFF5CC8C0);
  static const Color accentSoft = Color(0xFFD7F3F1);
  static const Color warm = Color(0xFFF2B8A2);
  static const Color warmSoft = Color(0xFFFBE4DA);
  static const Color sky = Color(0xFF8EB5FF);
  static const Color skySoft = Color(0xFFE5EEFF);

  static const LinearGradient background = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF7F6FF),
      Color(0xFFE9F4FF),
      Color(0xFFFDF0E7),
    ],
  );

  static ThemeData buildTheme() {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: accent),
      useMaterial3: true,
    );

    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: base.textTheme.copyWith(
        headlineSmall: const TextStyle(
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        titleMedium: const TextStyle(
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        bodyMedium: const TextStyle(color: ink),
        bodySmall: const TextStyle(color: mutedInk),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: ink,
        iconTheme: IconThemeData(color: ink),
        actionsIconTheme: IconThemeData(color: ink),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        toolbarTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF4F5FA),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: const BorderSide(color: Color(0xFFE3E5EF)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: const Color(0xFFF1F2F7),
        labelStyle: const TextStyle(color: ink),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
