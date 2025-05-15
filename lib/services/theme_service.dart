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
          colorScheme: const ColorScheme.dark().copyWith(
            primary: Color(0xFFF5A9C1),
            secondary: Color(0xFF6A0DAD),
          ),
        )
        : ThemeData.light().copyWith(
          primaryColor: const Color(0xFFF5A9C1),
          colorScheme: const ColorScheme.light().copyWith(
            primary: Color(0xFFF5A9C1),
            secondary: Color(0xFF6A0DAD),
          ),
        );
  }

  TextTheme getTextTheme(BuildContext context) {
    final baseTheme = Theme.of(context).textTheme;
    return baseTheme.apply(fontSizeFactor: fontSize);
  }
}
