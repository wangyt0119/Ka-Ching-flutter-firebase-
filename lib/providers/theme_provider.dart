import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;
  double _fontSize = 14.0;
  final List<double> fontSizes = [12.0, 14.0, 16.0, 18.0, 20.0];

  bool get isDarkMode => _isDarkMode;
  double get fontSize => _fontSize;

  ThemeProvider() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    _fontSize = prefs.getDouble('fontSize') ?? 14.0;
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
    notifyListeners();
  }

  Future<void> setFontSize(double size) async {
    _fontSize = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fontSize', size);
    notifyListeners();
  }

  TextTheme get _textTheme {
    // All text styles use the dynamic font size and appropriate color
    final baseColor = _isDarkMode ? Colors.white : Colors.black;
    final secondaryColor = _isDarkMode ? Colors.white70 : Colors.black87;
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: _fontSize + 12,
        color: baseColor,
        fontWeight: FontWeight.bold,
      ),
      displayMedium: TextStyle(
        fontSize: _fontSize + 8,
        color: baseColor,
        fontWeight: FontWeight.bold,
      ),
      displaySmall: TextStyle(fontSize: _fontSize + 4, color: baseColor),
      headlineLarge: TextStyle(
        fontSize: _fontSize + 6,
        color: baseColor,
        fontWeight: FontWeight.bold,
      ),
      headlineMedium: TextStyle(
        fontSize: _fontSize + 2,
        color: baseColor,
        fontWeight: FontWeight.bold,
      ),
      headlineSmall: TextStyle(
        fontSize: _fontSize,
        color: baseColor,
        fontWeight: FontWeight.bold,
      ),
      titleLarge: TextStyle(
        fontSize: _fontSize,
        color: baseColor,
        fontWeight: FontWeight.bold,
      ),
      titleMedium: TextStyle(fontSize: _fontSize, color: baseColor),
      titleSmall: TextStyle(fontSize: _fontSize - 1, color: secondaryColor),
      bodyLarge: TextStyle(fontSize: _fontSize, color: baseColor),
      bodyMedium: TextStyle(fontSize: _fontSize, color: secondaryColor),
      bodySmall: TextStyle(fontSize: _fontSize - 2, color: secondaryColor),
      labelLarge: TextStyle(fontSize: _fontSize, color: baseColor),
      labelMedium: TextStyle(fontSize: _fontSize - 1, color: secondaryColor),
      labelSmall: TextStyle(fontSize: _fontSize - 2, color: secondaryColor),
    );
  }

  final ThemeData _lightTheme = ThemeData(
    primaryColor: const Color(0xFFF5A9C1),
    colorScheme: ColorScheme.light(
      primary: const Color(0xFFF5A9C1),
      secondary: const Color(0xFF6A0DAD),
      background: Colors.white,
      surface: Colors.white,
      onBackground: Colors.black,
      onSurface: Colors.black,
    ),
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF5A9C1),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardColor: Colors.white,
    dividerColor: Colors.grey[300],
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStatePropertyAll(Color(0xFFF5A9C1)),
      trackColor: MaterialStatePropertyAll(Color(0xFF6A0DAD)),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: Color(0xFF6A0DAD),
      thumbColor: Color(0xFFF5A9C1),
      overlayColor: Color(0x296A0DAD),
      inactiveTrackColor: Colors.grey[400],
    ),
  );

  final ThemeData _darkTheme = ThemeData(
    primaryColor: const Color(0xFFF5A9C1),
    colorScheme: ColorScheme.dark(
      primary: const Color(0xFFF5A9C1),
      secondary: const Color(0xFFB388FF), // Brighter purple accent
      background: const Color(0xFF181A20), // Softer dark background
      surface: const Color(0xFF23272F), // Card/surface color
      onBackground: Colors.white,
      onSurface: Colors.white,
    ),
    scaffoldBackgroundColor: const Color(0xFF181A20),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF5A9C1),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardColor: const Color(0xFF23272F),
    dividerColor: Colors.grey,
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStatePropertyAll(Color(0xFFF5A9C1)),
      trackColor: MaterialStatePropertyAll(Color(0xFFB388FF)),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: Color(0xFFB388FF),
      thumbColor: Color(0xFFF5A9C1),
      overlayColor: Color(0x29B388FF),
      inactiveTrackColor: Colors.grey,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF23272F),
      selectedItemColor: Color(0xFFF5A9C1),
      unselectedItemColor: Colors.white70,
      showUnselectedLabels: true,
    ),
  );

  ThemeData getTheme() {
    final baseTheme = _isDarkMode ? _darkTheme : _lightTheme;
    return baseTheme.copyWith(textTheme: _textTheme);
  }
}
