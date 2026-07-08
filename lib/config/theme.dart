import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EaColors {
  static const primary = Color(0xFF5271FF);
  static const accent = Color(0xFF00D4AA);
  static const danger = Color(0xFFFF4757);
  static const warning = Color(0xFFFFD700);
  static const surface = Color(0xFF1A1D23);
  static const card = Color(0xFF22262E);
  static const cardLight = Color(0xFFF8F9FA);
  static const textPrimary = Color(0xFFE8EAED);
  static const textSecondary = Color(0xFF9AA0A6);
  static const success = Color(0xFF2ECC71);
}

class EaTheme {
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: EaColors.primary,
        secondary: EaColors.accent,
        surface: EaColors.surface,
        error: EaColors.danger,
      ),
      scaffoldBackgroundColor: const Color(0xFF0F1117),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      cardTheme: CardTheme(
        color: EaColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: EaColors.surface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: EaColors.textPrimary,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: EaColors.surface,
        indicatorColor: EaColors.primary.withOpacity(0.2),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: EaColors.surface,
        indicatorColor: EaColors.primary.withOpacity(0.2),
        selectedIconTheme: const IconThemeData(color: EaColors.primary),
        unselectedIconTheme: const IconThemeData(color: EaColors.textSecondary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: EaColors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: EaColors.primary, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: EaColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: EaColors.primary,
        secondary: EaColors.accent,
        surface: Colors.white,
        error: EaColors.danger,
      ),
      scaffoldBackgroundColor: const Color(0xFFF0F2F5),
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
      cardTheme: CardTheme(
        color: EaColors.cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
