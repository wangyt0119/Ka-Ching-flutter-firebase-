import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static const String _isDarkModeKey = 'isDarkMode';
  static const String _fontSizeKey = 'fontSize';

  final SharedPreferences _prefs;

  ThemeService(this._prefs);

  bool get isDarkMode => _prefs.getBool(_isDarkModeKey) ?? false;
  double get fontSize =>
      _prefs.getDouble(_fontSizeKey) ?? 1.0; // 1.0 is default scale

  Future<void> toggleDarkMode() async {
    await _prefs.setBool(_isDarkModeKey, !isDarkMode);
    notifyListeners();
  }

  Future<void> setFontSize(double scale) async {
    await _prefs.setDouble(_fontSizeKey, scale);
    notifyListeners();
  }

  ThemeData getTheme() {
    return isDarkMode
        ? ThemeData.dark().copyWith(
          primaryColor: const Color(0xFFF5A9C1),
          scaffoldBackgroundColor: const Color.fromARGB(
            255,
            70,
            70,
            70,
          ), // Softer dark gray instead of near-black
          cardColor: const Color.fromARGB(
            255,
            67,
            67,
            67,
          ), // Slightly lighter than background
          colorScheme: const ColorScheme.dark().copyWith(
            primary: Color(0xFFF5A9C1),
            secondary: Color(0xFFB19CD9),
            surface: Color.fromARGB(255, 65, 63, 63),
            background: Color.fromARGB(255, 58, 58, 58),
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onBackground: Color(
              0xFFECECEC,
            ), // Softer white for better readability
            onSurface: Color(0xFFECECEC),
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: Color(0xFF303030),
            elevation: 0,
          ),
          textTheme: ThemeData.dark().textTheme.apply(
            bodyColor: Color(0xFFECECEC),
            displayColor: Color(0xFFECECEC),
          ),
          dividerColor: Color(0xFF424242),
          shadowColor: const Color.fromARGB(115, 58, 58, 58),
        )
        : ThemeData.light().copyWith(
          primaryColor: const Color(0xFFF5A9C1),
          colorScheme: const ColorScheme.light().copyWith(
            primary: Color(0xFFF5A9C1),
            secondary: Color.fromARGB(255, 147, 57, 211),
          ),
        );
  }

  TextTheme getTextTheme(BuildContext context) {
    final baseTheme = Theme.of(context).textTheme;
    return baseTheme.apply(
      fontSizeFactor: fontSize,
      bodyColor: isDarkMode ? const Color(0xFFECECEC) : null,
      displayColor: isDarkMode ? const Color(0xFFECECEC) : null,
    );
  }
}
