import 'package:flutter/material.dart';

class AppTheme {
  // User-provided palette
  static const Color richBlack = Color(0xFF000F1B);
  static const Color darkGreen = Color(0xFF032221);
  static const Color bangladeshGreen = Color(0xFF03624C);
  static const Color mountainMeadow = Color(0xFF2CC295);
  static const Color caribbeanGreen = Color(0xFF00DF81);
  static const Color antiFlashWhite = Color(0xFFF1F7F6);

  static const Color ink = richBlack;
  static const Color mutedInk = bangladeshGreen;
  static const Color card = antiFlashWhite;

  static const Color accent = caribbeanGreen;
  static const Color accentSoft = mountainMeadow;
  static const Color warm = bangladeshGreen;
  static const Color warmSoft = Color(0xFFDFF5EE);
  static const Color sky = mountainMeadow;
  static const Color skySoft = Color(0xFFE7F7F1);

  static LinearGradient backgroundFor(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF95DEC4), Color(0xFF63D0AD), Color(0xFF36C69A)],
      );
    }
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [antiFlashWhite, Color(0xFFE7F7F1), Color(0xFFD4F2E6)],
    );
  }

  static ThemeData buildLightTheme() => _buildTheme(Brightness.light);

  static ThemeData buildDarkTheme() => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final inkColor = ink;
    final mutedColor = mutedInk;
    final cardColor = isDark ? const Color(0xFFE2F5EE) : antiFlashWhite;
    final inputFillColor = isDark
        ? const Color(0xFFD6F0E7)
        : const Color(0xFFE8F8F2);

    final scheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: richBlack,
      secondary: mountainMeadow,
      onSecondary: richBlack,
      error: const Color(0xFFE05C5C),
      onError: antiFlashWhite,
      surface: cardColor,
      onSurface: inkColor,
    );

    final base = ThemeData(
      colorScheme: scheme,
      brightness: brightness,
      useMaterial3: true,
    );

    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: base.textTheme.copyWith(
        headlineSmall: TextStyle(fontWeight: FontWeight.w700, color: inkColor),
        titleMedium: TextStyle(fontWeight: FontWeight.w600, color: inkColor),
        bodyMedium: TextStyle(color: inkColor),
        bodySmall: TextStyle(color: mutedColor),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: inkColor,
        iconTheme: IconThemeData(color: inkColor),
        actionsIconTheme: IconThemeData(color: inkColor),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: inkColor,
        ),
        toolbarTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: inkColor,
        ),
      ),
      cardColor: cardColor,
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFillColor,
        hintStyle: TextStyle(color: mutedColor),
        labelStyle: TextStyle(color: mutedColor),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF2A6A5A) : const Color(0xFF9EDDC6),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: richBlack,
          disabledBackgroundColor: isDark
              ? const Color(0xFF9ACFBF)
              : const Color(0xFFBFE9D9),
          disabledForegroundColor: richBlack.withValues(alpha: 0.55),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          minimumSize: const Size(0, 48),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accentSoft,
          foregroundColor: richBlack,
          disabledBackgroundColor: isDark
              ? const Color(0xFF8FC9B8)
              : const Color(0xFFC8EADF),
          disabledForegroundColor: richBlack.withValues(alpha: 0.55),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          minimumSize: const Size(0, 48),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: inkColor,
          side: BorderSide(
            color: isDark
                ? mountainMeadow
                : bangladeshGreen.withValues(alpha: 0.35),
          ),
          disabledForegroundColor: inkColor.withValues(alpha: 0.45),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          minimumSize: const Size(0, 48),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? darkGreen : bangladeshGreen,
          disabledForegroundColor: mutedColor.withValues(alpha: 0.45),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          minimumSize: const Size(0, 42),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: inkColor,
          disabledForegroundColor: mutedColor.withValues(alpha: 0.45),
          minimumSize: const Size(40, 40),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: richBlack,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: isDark
            ? const Color(0xFF1A4E48)
            : const Color(0xFFDFF4EC),
        labelStyle: TextStyle(color: inkColor),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
