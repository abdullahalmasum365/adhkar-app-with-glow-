import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_theme.dart';
import '../services/widget_service.dart';

class ThemeProvider extends ChangeNotifier {
  static const _paletteKey = 'app_palette';

  ThemeMode _themeMode = ThemeMode.dark;
  bool _showTransliteration = true;
  bool _showHabitTracker = true;
  String _paletteId = AppPalettes.emeraldNight.id;
  String? _uid;
  bool _isPro = false;

  ThemeMode get themeMode => _themeMode;

  /// Active palette id — 'emerald' (default dark green) or 'royal' (white
  /// & purple). The palette itself is applied globally via [AppColors].
  String get paletteId => _paletteId;
  AppPalette get palette => AppPalettes.byId(_paletteId);
  AppPalette get activePalette => palette;

  /// When false, the Latin-script phonetic line is hidden on every dhikr card.
  bool get showTransliteration => _showTransliteration;

  /// When false, habit tracking charts, rings, and streak metrics are hidden in ProgressScreen.
  bool get showHabitTracker => _showHabitTracker;

  /// Whether the user holds verified Pro status (Lifetime or active unexpired subscription).
  bool get isPro => _isPro;

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

  Future<void>? _loadFuture;

  /// Completes when the initial preferences and palette have loaded.
  Future<void> get initialized => _loadFuture ?? Future.value();

  ThemeProvider() {
    _loadFuture = _load();
  }

  /// Helper to check if user has active Pro entitlement cached in local preferences.
  static bool checkIsProInPrefs(SharedPreferences prefs) {
    final hasLifetime = prefs.getBool('has_lifetime_pro') ?? false;
    final activeSub = prefs.getString('active_subscription_id');
    final expiryMs = prefs.getInt('subscription_expiry_ms');
    bool hasActiveSub = false;
    if (activeSub != null && activeSub.isNotEmpty) {
      if (expiryMs != null) {
        hasActiveSub = DateTime.now().millisecondsSinceEpoch <= expiryMs;
      } else {
        hasActiveSub = true;
      }
    }
    return hasLifetime || hasActiveSub;
  }

  /// Reads the saved palette and applies it to [AppColors]. Called from
  /// main() before runApp so the very first frame already uses the saved
  /// theme (no dark→light flash for Royal White users).
  static Future<void> applySavedPalette() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_paletteKey) ?? AppPalettes.emeraldNight.id;
      final candidate = AppPalettes.byId(id);
      final isProUser = checkIsProInPrefs(prefs);

      // Entitlement check: If saved palette is Pro but user lacks Pro entitlement, revert to free default
      if (candidate.isPro && !isProUser) {
        await prefs.setString(_paletteKey, AppPalettes.emeraldNight.id);
        AppColors.apply(AppPalettes.emeraldNight);
      } else {
        AppColors.apply(candidate);
      }
    } catch (_) {
      AppColors.apply(AppPalettes.emeraldNight);
    }
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _isPro = checkIsProInPrefs(prefs);
    final savedId = prefs.getString(_paletteKey) ?? AppPalettes.emeraldNight.id;
    final candidate = AppPalettes.byId(savedId);

    // Guard against Pro palette if user does not hold verified Pro
    if (candidate.isPro && !_isPro) {
      _paletteId = AppPalettes.emeraldNight.id;
      await prefs.setString(_paletteKey, _paletteId);
    } else {
      _paletteId = candidate.id;
    }

    AppColors.apply(AppPalettes.byId(_paletteId));
    _themeMode = palette.isDark ? ThemeMode.dark : ThemeMode.light;
    _showTransliteration = prefs.getBool('show_transliteration') ?? true;
    _showHabitTracker = prefs.getBool('show_habit_tracker') ?? true;
    notifyListeners();
    WidgetService().updateTheme(palette);
  }

  /// Called from main ChangeNotifierProxyProvider2 when Auth or Purchase state updates.
  Future<void> updateAuthAndPro(String? uid, bool isPro, {bool isPurchaseLoaded = true}) async {
    // Race-condition guard: If PurchaseProvider has not yet loaded its cached
    // entitlement from SharedPreferences on startup, do not prematurely revert Pro theme!
    if (!isPurchaseLoaded) {
      if (uid != _uid) {
        await attachUser(uid);
      }
      return;
    }

    final proStatusChanged = _isPro != isPro;
    _isPro = isPro;

    // Entitlement Enforcement:
    // If Pro subscription expired, cancelled, or refunded, and active theme is Pro,
    // immediately revert to default free palette:
    if (proStatusChanged && !_isPro && palette.isPro) {
      debugPrint('[ThemeProvider] Pro subscription ended/cancelled. Reverting Pro palette "$_paletteId" to default.');
      await setPalette(AppPalettes.emeraldNight.id);
    }

    if (uid != _uid) {
      await attachUser(uid);
    }
  }

  /// Switches the whole app to palette [id], persists the choice, and
  /// repaints EVERY screen instantly.
  Future<void> setPalette(String id) async {
    final target = AppPalettes.byId(id);

    // Security Guard: Pro themes strictly require verified Pro entitlement
    if (target.isPro && !_isPro) {
      debugPrint('[ThemeProvider] Access denied: Palette "${target.label}" requires Pro subscription.');
      return;
    }

    if (id == _paletteId) return;
    _paletteId = target.id;
    AppColors.apply(target);
    _themeMode = palette.isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    _rebuildWholeApp();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_paletteKey, target.id);
    await WidgetService().updateTheme(palette);
    if (_uid != null) unawaited(_pushToCloud());
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
    if (_uid != null) unawaited(_pushToCloud());
  }

  Future<void> toggleHabitTracker(bool value) async {
    _showHabitTracker = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_habit_tracker', value);
    notifyListeners();
    if (_uid != null) unawaited(_pushToCloud());
  }

  // ── Cloud Firestore Sync ──────────────────────────────────────────────────

  DocumentReference<Map<String, dynamic>>? get _cloudDoc {
    if (_uid == null || Firebase.apps.isEmpty) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('settings')
        .doc('theme');
  }

  /// Called whenever the signed-in user changes. Restores saved theme and
  /// aids from Cloud Firestore, with strict validation and Pro entitlement checks.
  Future<void> attachUser(String? uid) async {
    if (uid == _uid && uid != null) return;
    _uid = uid;
    if (uid == null || Firebase.apps.isEmpty) return;

    try {
      final doc = _cloudDoc;
      if (doc == null) return;
      final snap = await doc.get();

      if (snap.exists) {
        final data = snap.data()!;
        final cloudPalette = data['paletteId'] as String?;
        final cloudTranslit = data['showTransliteration'] as bool?;
        final cloudHabit = data['showHabitTracker'] as bool?;

        if (cloudPalette != null && cloudPalette.isNotEmpty) {
          final isValid = AppPalettes.all.any((p) => p.id == cloudPalette);
          if (!isValid) {
            // Invalid / unrecognized palette ID from cloud
            debugPrint('[ThemeProvider] Cloud palette "$cloudPalette" is unrecognized. Reverting to default.');
            if (_paletteId != AppPalettes.emeraldNight.id) {
              await setPalette(AppPalettes.emeraldNight.id);
            } else {
              await _pushToCloud();
            }
          } else {
            final targetPalette = AppPalettes.byId(cloudPalette);
            if (targetPalette.isPro && !_isPro) {
              // Pro Bypass Prevention: Free user cannot adopt Pro theme from Firestore
              debugPrint('[ThemeProvider] Cloud theme "$cloudPalette" is Pro, but user is not Pro. Reverting to default.');
              if (_paletteId != AppPalettes.emeraldNight.id) {
                await setPalette(AppPalettes.emeraldNight.id);
              } else {
                await _pushToCloud();
              }
            } else if (cloudPalette != _paletteId) {
              await setPalette(cloudPalette);
            }
          }
        }
        if (cloudTranslit != null && cloudTranslit != _showTransliteration) {
          await toggleTransliteration(cloudTranslit);
        }
        if (cloudHabit != null && cloudHabit != _showHabitTracker) {
          await toggleHabitTracker(cloudHabit);
        }
      } else {
        await _pushToCloud();
      }
    } catch (e) {
      debugPrint('[ThemeProvider] cloud sync on sign-in failed: $e');
    }
  }

  Future<void> _pushToCloud() async {
    final doc = _cloudDoc;
    if (doc == null) return;
    try {
      final currentAuthUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentAuthUid == null || currentAuthUid != _uid) return;

      await doc.set({
        'paletteId': _paletteId,
        'showTransliteration': _showTransliteration,
        'showHabitTracker': _showHabitTracker,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[ThemeProvider] cloud push failed: $e');
    }
  }

  Gradient getBackgroundGradient() => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          palette.bgDark,
          palette.bgDeep,
        ],
      );
}
