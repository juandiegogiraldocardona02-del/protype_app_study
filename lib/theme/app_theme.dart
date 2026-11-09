import 'package:flutter/material.dart';

const _seed = Color(0xFF4F46E5);
const _surface = Color(0xFF0F172A);
const _surfaceVariant = Color(0xFF1E293B);
const _onSurface = Color(0xFFF8FAFC);
const _primary = Color(0xFF6366F1);
const _secondary = Color(0xFF818CF8);
const _tertiary = Color(0xFFF472B6);
const _error = Color(0xFFF87171);

const List<Color> subjectColors = [
  Color(0xFF4F46E5),
  Color(0xFF059669),
  Color(0xFFDC2626),
  Color(0xFFD97706),
  Color(0xFF7C3AED),
  Color(0xFF0891B2),
  Color(0xFFBE185D),
  Color(0xFF84CC16),
];

ThemeData buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: brightness,
    primary: _primary,
    secondary: _secondary,
    tertiary: _tertiary,
    error: _error,
    surface: isDark ? _surface : const Color(0xFFFAFAFA),
    onSurface: isDark ? _onSurface : const Color(0xFF020617),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    brightness: brightness,
    visualDensity: VisualDensity.comfortable,
    scaffoldBackgroundColor: isDark
        ? const Color(0xFF020617)
        : const Color(0xFFFAFAFA),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? _surfaceVariant : const Color(0xFFF1F5F9),
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
        borderSide: BorderSide(color: _primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? _surfaceVariant : const Color(0xFFE2E8F0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      contentTextStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: _primary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        elevation: 0,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
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
