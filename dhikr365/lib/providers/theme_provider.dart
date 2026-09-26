import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  static const _paletteKey = 'app_palette';

  ThemeMode _themeMode = ThemeMode.dark;
  bool _showTransliteration = true;
  bool _showHabitTracker = true;
  String _paletteId = AppPalettes.emeraldNight.id;

  ThemeMode get themeMode => _themeMode;

  /// Active palette id — 'emerald' (default dark green) or 'royal' (white
  /// & purple). The palette itself is applied globally via [AppColors].
  String get paletteId => _paletteId;
  AppPalette get palette => AppPalettes.byId(_paletteId);

  /// When false, the Latin-script phonetic line is hidden on every dhikr card.
  bool get showTransliteration => _showTransliteration;

  /// When false, habit tracking charts, rings, and streak metrics are hidden in ProgressScreen.
  bool get showHabitTracker => _showHabitTracker;

  // Legacy names kept for DhikrCard / widgets that still reference them —
  // now palette-backed so they follow the active theme.
  static Color get etherealSage =>
      AppColors.isDark ? const Color(0xFF4CAF7D) : const Color(0xFFA78BFA);
  static Color get divineAmber => AppColors.primary;
  static Color get deepOlive => AppColors.bgDark;
  static Color get pearlWhite => AppColors.textPrimary;
  static Color get cream =>
      AppColors.isDark ? const Color(0xFFFDFCF0) : const Color(0xFF2E1065);
  static Color get brandDark => AppColors.onAccent;
  static Color get deepTeal => AppColors.playerSurface;

  ThemeProvider() {
    _load();
  }

  /// Reads the saved palette and applies it to [AppColors]. Called from
  /// main() before runApp so the very first frame already uses the saved
  /// theme (no dark→light flash for Royal White users).
  static Future<void> applySavedPalette() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_paletteKey) ?? AppPalettes.emeraldNight.id;
      AppColors.apply(AppPalettes.byId(id));
    } catch (_) {
      AppColors.apply(AppPalettes.emeraldNight);
    }
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _paletteId = prefs.getString(_paletteKey) ?? AppPalettes.emeraldNight.id;
    AppColors.apply(AppPalettes.byId(_paletteId));
    _themeMode = palette.isDark ? ThemeMode.dark : ThemeMode.light;
    _showTransliteration = prefs.getBool('show_transliteration') ?? true;
    _showHabitTracker = prefs.getBool('show_habit_tracker') ?? true;
    notifyListeners();
  }

  /// Switches the whole app to palette [id], persists the choice, and
  /// repaints EVERY screen instantly.
  ///
  /// notifyListeners alone is not enough: screens read AppColors statically
  /// at build time, and routes retained in the Navigator stack are never
  /// rebuilt by a provider they don't watch — they'd keep the old colors
  /// until revisited (or the app restarted). [_rebuildWholeApp] marks the
  /// entire element tree dirty so the very next frame renders the new
  /// palette everywhere — same mechanism a hot-reload uses.
  Future<void> setPalette(String id) async {
    if (id == _paletteId) return;
    _paletteId = id;
    AppColors.apply(AppPalettes.byId(id));
    _themeMode = palette.isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    _rebuildWholeApp();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_paletteKey, id);
  }

  /// Marks every element in the app dirty so all screens — including routes
  /// parked behind the current one and open dialogs/sheets — rebuild with
  /// the new palette on the next frame.
  static void _rebuildWholeApp() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final root = WidgetsBinding.instance.rootElement;
      if (root == null) return;
      void rebuild(Element el) {
        el.markNeedsBuild();
        el.visitChildren(rebuild);
      }

      try {
        rebuild(root);
      } catch (e) {
        debugPrint('[Theme] full rebuild failed: $e');
      }
    });
  }

  Future<void> toggleTransliteration(bool value) async {
    _showTransliteration = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_transliteration', value);
    notifyListeners();
  }

  Future<void> toggleHabitTracker(bool value) async {
    _showHabitTracker = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_habit_tracker', value);
    notifyListeners();
  }

  Gradient getBackgroundGradient() => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: AppColors.isDark
            ? const [Color(0xFF0A1A1A), Color(0xFF050806)]
            : const [Color(0xFFF3EFFB), Color(0xFFFFFFFF)],
      );
}
