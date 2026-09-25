import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Stessi colori usati in index.html / storico.html / ai.html / report.html
class HydroColors {
  static const bg = Color(0xFF0F1410);
  static const bg2 = Color(0xFF161D17);
  static const bg3 = Color(0xFF1E2A1F);
  static const border = Color(0xFF2A3B2C);
  static const text = Color(0xFFE8F0E9);
  static const text2 = Color(0xFF7FA882);
  static const accent = Color(0xFF4AB964);
  static const accent2 = Color(0xFF2D7A45);
  static const danger = Color(0xFFE05A5A);
  static const warn = Color(0xFFE0A84A);
}

ThemeData hydroDarkTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: HydroColors.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: HydroColors.accent,
      secondary: HydroColors.accent2,
      surface: HydroColors.bg2,
      error: HydroColors.danger,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: HydroColors.bg,
      elevation: 0,
      titleTextStyle: GoogleFonts.syne(
        color: HydroColors.accent,
        fontWeight: FontWeight.w700,
        fontSize: 18,
      ),
      iconTheme: const IconThemeData(color: HydroColors.text2),
    ),
    textTheme: GoogleFonts.dmMonoTextTheme(
      base.textTheme,
    ).apply(bodyColor: HydroColors.text, displayColor: HydroColors.text),
    cardColor: HydroColors.bg2,
    dividerColor: HydroColors.border,
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: HydroColors.bg2,
      selectedItemColor: HydroColors.accent,
      unselectedItemColor: HydroColors.text2,
      type: BottomNavigationBarType.fixed,
    ),
  );
}

TextStyle sectionTitleStyle() => GoogleFonts.syne(
  color: HydroColors.text2,
  fontWeight: FontWeight.w600,
  fontSize: 12,
  letterSpacing: 0.8,
);

TextStyle metricLabelStyle() => GoogleFonts.syne(
  color: HydroColors.text2,
  fontWeight: FontWeight.w600,
  fontSize: 11,
  letterSpacing: 0.6,
);

const metricValueStyle = TextStyle(
  color: HydroColors.text,
  fontWeight: FontWeight.w500,
  fontSize: 26,
);
