import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  Color _selectedThemeColor = const Color(0xFF36a4da);

  Color get selectedThemeColor => _selectedThemeColor;

  ThemeProvider() {
    _loadThemeColor();
  }

  Future<void> _loadThemeColor() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt('theme_color');
    if (colorValue != null) {
      _selectedThemeColor = Color(colorValue);
      notifyListeners();
    }
  }

  Future<void> setThemeColor(Color color) async {
    _selectedThemeColor = color;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_color', color.toARGB32());
  }
}
