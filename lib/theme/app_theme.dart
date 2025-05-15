import 'package:flutter/material.dart';

class AppTheme {
  // Updated color scheme with pink and purple palette
  // Refined Primary Colors (Pink Theme)
  static const Color primaryColor = Color(0xFFF3C4D6);       // Soft Pink
  static const Color primaryLightColor = Color(0xFFFBE4EF);  // Very Light Pink
  static const Color primaryDarkColor = Color(0xFFE295B5);   // Muted Rose

  // Refined Secondary Colors (Purple Theme)
  static const Color secondaryColor = Color(0xFFD1C4E9);       // Soft Lavender
  static const Color secondaryLightColor = Color(0xFFEDE7F6);  // Pale Lavender
  static const Color secondaryDarkColor = Color(0xFF9575CD);   // Medium Purple

  // Accent Colors (Balanced, Not Overly Saturated)
  static const Color accentColor = Color(0xFFF48FB1);       // Warm Pink
  static const Color accentLightColor = Color(0xFFFCE4EC);  // Blush Pink
  static const Color accentDarkColor = Color(0xFFC2185B);   // Deep Raspberry

  // Backgrounds and Surfaces
  static const Color backgroundColor = Color(0xFFFAF5FF); // Soft Lavender Background
  static const Color surfaceColor = Color(0xFFFFFFFF);    // Clean White

  // Text Colors (High Readability on Light Backgrounds)
  static const Color textPrimary = Color(0xFF4A148C);     // Deep Purple
  static const Color textSecondary = Color(0xFF7B1FA2);   // Muted Purple
  static const Color textLight = Color(0xFFBA68C8);       // Soft Lilac

  // Additional UI Colors
  static const Color errorColor = Color(0xFFFFCDD2);        // Soft Blush Error
  static const Color dividerColor = Color(0xFFE1BEE7);      // Pale Mauve Divider
  static const Color cardColor = Colors.white;
  static const Color positiveAmount = Color(0xFF4CAF50);    // Pleasant Green
  static const Color negativeAmount = Color(0xFFF44336);    // Calm Red
  static const Color settledColor = Color(0xFFBDBDBD);       // Muted Grey
   // Gray for settled

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        primaryContainer: primaryLightColor,
        onPrimary: Colors.white,
        secondary: secondaryColor,
        secondaryContainer: secondaryLightColor,
        onSecondary: Colors.white,
        error: errorColor,
        background: backgroundColor,
        surface: surfaceColor,
        onSurface: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        color: cardColor,
        elevation: 2,
        shadowColor: primaryColor.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          elevation: 1,
          shadowColor: accentColor.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: secondaryColor,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hoverColor: primaryLightColor.withOpacity(0.1),
        focusColor: primaryLightColor.withOpacity(0.2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: dividerColor, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: errorColor, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: TextStyle(color: textSecondary),
        hintStyle: TextStyle(color: textLight),
        prefixIconColor: primaryColor,
      ),
      dividerTheme: DividerThemeData(
        color: dividerColor,
        thickness: 1,
        space: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedIconTheme: IconThemeData(size: 24),
        unselectedIconTheme: IconThemeData(size: 22),
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryColor;
          }
          return null;
        }),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryColor;
          }
          return null;
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: primaryLightColor.withOpacity(0.2),
        selectedColor: primaryColor,
        secondarySelectedColor: secondaryColor,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        labelStyle: TextStyle(color: textPrimary),
        secondaryLabelStyle: TextStyle(color: Colors.white),
        brightness: Brightness.light,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 8,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accentColor,
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.bold,
        ),
        headlineSmall: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(color: textPrimary),
        bodyMedium: TextStyle(color: textPrimary),
        bodySmall: TextStyle(color: textSecondary),
      ),
    );
  }
} 