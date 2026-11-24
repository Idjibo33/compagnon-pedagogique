import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Palette de couleurs EdTech Lumineux & Direct
  static const Color scaffoldBackground = Color(0xFFF7F9FC);
  static const Color cardSurface = Color(0xFFFFFFFF);
  static const Color primaryRoyalBlue = Color(0xFF1A6FEE);
  static const Color primaryRoyalBlueLight = Color(0xFFE8F1FD);
  static const Color textDarkSlate = Color(0xFF0F172A);
  static const Color textMutedSlate = Color(0xFF64748B);
  static const Color statusOfflineGreen = Color(0xFF16A34A);
  static const Color statusOfflineGreenLight = Color(0xFFDCFCE7);
  static const Color dividerColor = Color(0xFFE2E8F0);
  static const Color errorRed = Color(0xFFDC2626);

  // Palette Mode Plein Soleil (Contraste maximal WCAG AAA pour forte luminosité)
  static const Color pleinSoleilScaffold = Color(0xFFFFFFFF);
  static const Color pleinSoleilCard = Color(0xFFFFFFFF);
  static const Color pleinSoleilText = Color(0xFF000000);
  static const Color pleinSoleilPrimary = Color(0xFF0D47A1);
  static const Color pleinSoleilBorder = Color(0xFF000000);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: scaffoldBackground,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: primaryRoyalBlue,
        onPrimary: Colors.white,
        primaryContainer: primaryRoyalBlueLight,
        onPrimaryContainer: primaryRoyalBlue,
        secondary: statusOfflineGreen,
        onSecondary: Colors.white,
        secondaryContainer: statusOfflineGreenLight,
        onSecondaryContainer: statusOfflineGreen,
        surface: cardSurface,
        onSurface: textDarkSlate,
        error: errorRed,
        onError: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: cardSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: dividerColor, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: cardSurface,
        foregroundColor: textDarkSlate,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textDarkSlate,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: textDarkSlate,
          fontSize: 26,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          color: textDarkSlate,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.3,
        ),
        titleLarge: TextStyle(
          color: textDarkSlate,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: textDarkSlate,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: textDarkSlate,
          fontSize: 15,
          fontWeight: FontWeight.normal,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          color: textDarkSlate,
          fontSize: 14,
          fontWeight: FontWeight.normal,
          height: 1.45,
        ),
        bodySmall: TextStyle(
          color: textMutedSlate,
          fontSize: 12,
          fontWeight: FontWeight.normal,
        ),
        labelLarge: TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryRoyalBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryRoyalBlue,
          side: const BorderSide(color: primaryRoyalBlue, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardSurface,
        hintStyle: const TextStyle(color: textMutedSlate, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryRoyalBlue, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  /// Thème contrasté Plein Soleil (WCAG AAA) : fond blanc pur, typographie noire foncée,
  /// bordures nettes et lisibilité optimale en extérieur sous forte luminosité.
  static ThemeData get pleinSoleilTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: pleinSoleilScaffold,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: pleinSoleilPrimary,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFE3F2FD),
        onPrimaryContainer: pleinSoleilPrimary,
        secondary: Color(0xFF1B5E20),
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFFC8E6C9),
        onSecondaryContainer: Color(0xFF1B5E20),
        surface: pleinSoleilCard,
        onSurface: pleinSoleilText,
        error: errorRed,
        onError: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: pleinSoleilCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: pleinSoleilBorder, width: 2),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: pleinSoleilScaffold,
        foregroundColor: pleinSoleilText,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: pleinSoleilText,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: pleinSoleilText,
          fontSize: 26,
          fontWeight: FontWeight.w900,
        ),
        headlineMedium: TextStyle(
          color: pleinSoleilText,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        titleLarge: TextStyle(
          color: pleinSoleilText,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
        titleMedium: TextStyle(
          color: pleinSoleilText,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(
          color: pleinSoleilText,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          color: pleinSoleilText,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.45,
        ),
        bodySmall: TextStyle(
          color: pleinSoleilText,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        labelLarge: TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: pleinSoleilPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: pleinSoleilBorder, width: 1.5),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: pleinSoleilPrimary,
          side: const BorderSide(color: pleinSoleilBorder, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: pleinSoleilCard,
        hintStyle: const TextStyle(
            color: Color(0xFF333333),
            fontSize: 14,
            fontWeight: FontWeight.w500),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: pleinSoleilBorder, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: pleinSoleilBorder, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: pleinSoleilPrimary, width: 2.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
