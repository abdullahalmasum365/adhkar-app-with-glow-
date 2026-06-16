import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  bool _showTransliteration = true;

  ThemeMode get themeMode => _themeMode;

  /// When false, the Latin-script phonetic line is hidden on every dhikr card.
  bool get showTransliteration => _showTransliteration;

  // Legacy color constants kept for DhikrCard / widgets that still reference them
  static const Color etherealSage  = Color(0xFF4CAF7D);
  static const Color divineAmber   = Color(0xFFEC7F13);
  static const Color deepOlive     = Color(0xFF0A1212);
  static const Color pearlWhite    = Colors.white;
  static const Color cream         = Color(0xFFFDFCF0);
  static const Color brandDark     = Color(0xFF020617);
  static const Color deepTeal      = Color(0xFF042F2E);

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('dark_mode') ?? true;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    _showTransliteration = prefs.getBool('show_transliteration') ?? true;
    notifyListeners();
  }

  Future<void> toggleTheme(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', mode == ThemeMode.dark);
    notifyListeners();
  }

  Future<void> toggleTransliteration(bool value) async {
    _showTransliteration = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_transliteration', value);
    notifyListeners();
  }

  Gradient getBackgroundGradient() => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0A1A1A), Color(0xFF050806)],
      );
}
