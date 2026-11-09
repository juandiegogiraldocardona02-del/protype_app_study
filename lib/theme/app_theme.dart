import 'package:flutter/material.dart';

const Color seed = Color(0xFF1E3A8A);
const Color surfaceDark = Color(0xFF0B1120);
const Color surfaceCard = Color(0xFF111827);
const Color onSurfaceDark = Color(0xFFF1F5F9);
const Color bluePrimary = Color(0xFF2563EB);
const Color blueLight = Color(0xFF93C5FD);
const Color accentCyan = Color(0xFF22D3EE);
const Color accentAmber = Color(0xFFFBBF24);
const Color errorRed = Color(0xFFF87171);

const List<Color> subjectColors = [
  Color(0xFF1E3A8A), // azul académico
  Color(0xFF047857), // verde esmeralda
  Color(0xFFB91C1C), // rojo intenso
  Color(0xFFD97706), // naranja ámbar
  Color(0xFF6D28D9), // púrpura
  Color(0xFF0891B2), // cian
  Color(0xFFBE185D), // rosa
  Color(0xFF65A30D), // lima
];

ThemeData buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final Color surface = isDark ? surfaceCard : const Color(0xFFFAFAFA);
  final Color scaffold = isDark ? surfaceDark : const Color(0xFFF8FAFC);
  final Color onSurface = isDark ? onSurfaceDark : const Color(0xFF0F172A);
  final Color surfaceVariant = isDark
      ? const Color(0xFF1F2937)
      : const Color(0xFFF1F5F9);

  final ColorScheme colorScheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
    primary: bluePrimary,
    secondary: blueLight,
    tertiary: accentCyan,
    error: errorRed,
    surface: surface,
    onSurface: onSurface,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    brightness: brightness,
    visualDensity: VisualDensity.comfortable,
    scaffoldBackgroundColor: scaffold,
    cardTheme: CardThemeData(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: bluePrimary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? surfaceVariant : const Color(0xFFE2E8F0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      contentTextStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: bluePrimary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: bluePrimary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        elevation: 0,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: bluePrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
      ),
      headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
      ),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
    ),
  );
}
