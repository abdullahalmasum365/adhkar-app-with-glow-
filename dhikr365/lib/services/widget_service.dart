// ============================================================================
// lib/services/widget_service.dart
//
// UNIVERSAL MULTI-THEME HOME SCREEN WIDGET ENGINE
//
// Bridges Flutter state (Palettes, Prayer Times, Adhkar Streaks, Tasbih)
// to Android AppWidgetProvider & iOS WidgetKit via home_widget.
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_theme.dart';
import '../models/dhikr.dart';
import '../screens/dhikr_list_screen.dart';
import '../screens/prayer_times_screen.dart';
import '../screens/progress_screen.dart';
import '../screens/dua_screen.dart';
import '../utils/app_navigator.dart';

// ── Top-level background callback for interactive widget clicks ─────────────
@pragma('vm:entry-point')
Future<void> widgetBackgroundCallback(Uri? uri) async {
  if (uri == null) return;
  if (uri.host == 'tasbih_increment' || uri.path.contains('tasbih_increment')) {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt('tasbih_widget_count') ?? 33;
    final next = current + 1;
    await prefs.setInt('tasbih_widget_count', next);

    await HomeWidget.saveWidgetData<int>('tasbih_count', next);
    await HomeWidget.updateWidget(
      androidName: 'TasbihWidgetProvider',
      name: 'TasbihWidgetProvider',
    );
  }
}

class WidgetService {
  static final WidgetService _instance = WidgetService._internal();
  factory WidgetService() => _instance;
  WidgetService._internal();

  bool _initialized = false;
  StreamSubscription<Uri?>? _widgetClickSub;
  Uri? _pendingLaunchUri;

  // Widget Provider Class Names
  static const String prayerCountdownWidget = 'PrayerCountdownWidgetProvider';
  static const String prayerCompactWidget = 'PrayerCompactWidgetProvider';
  static const String adhkarTrackerWidget = 'AdhkarTrackerWidgetProvider';
  static const String adhkarTrackerSmallWidget = 'AdhkarTrackerSmallWidgetProvider';
  static const String duaOfTheDayWidget = 'DuaOfTheDayWidgetProvider';
  static const String tasbihWidget = 'TasbihWidgetProvider';

  static const List<String> allWidgetProviders = [
    prayerCountdownWidget,
    prayerCompactWidget,
    adhkarTrackerWidget,
    adhkarTrackerSmallWidget,
    duaOfTheDayWidget,
    tasbihWidget,
  ];

  /// Checks and launches any queued cold-start widget deep link once navigator is ready.
  void checkPendingLaunch() {
    if (_pendingLaunchUri != null) {
      final uri = _pendingLaunchUri!;
      _pendingLaunchUri = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        handleDeepLink(uri);
      });
    }
  }

  /// Initialize deep link listening and background interaction
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await HomeWidget.registerInteractivityCallback(widgetBackgroundCallback);
    } catch (e) {
      debugPrint('[WidgetService] registerInteractivityCallback error: $e');
    }

    // Handle launch from widget (cold start)
    try {
      final launchUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (launchUri != null) {
        if (launchUri.host == 'tasbih_increment' || launchUri.path.contains('tasbih_increment')) {
          // Handled by background callback, no UI navigation
        } else {
          _pendingLaunchUri = launchUri;
        }
      }
    } catch (e) {
      debugPrint('[WidgetService] initiallyLaunchedFromHomeWidget error: $e');
    }

    // Handle click while app is in background or foreground
    _widgetClickSub = HomeWidget.widgetClicked.listen((Uri? uri) {
      if (uri != null) {
        handleDeepLink(uri);
      }
    });

    await _seedInitialDataIfNeeded();
  }

  Future<void> _seedInitialDataIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSeeded = prefs.getBool('widget_data_seeded') ?? false;
      if (!hasSeeded) {
        await prefs.setBool('widget_data_seeded', true);
        await updateDuaOfDayData(
          title: 'DUA OF THE DAY',
          categoryBadge: 'FORGIVENESS',
          arabicText: 'رَبِّ اغْفِرْ لِي وَتُبْ عَلَيَّ',
          translationText:
              '“My Lord, forgive me and accept my repentance; surely You are the Accepter of repentance, the Merciful.”',
          referenceText: 'Sunan Abi Dawud 1516',
        );
        await updateTasbihData(
          title: 'سُبْحَانَ اللَّهِ',
          count: 33,
          target: 33,
        );
      }
    } catch (e) {
      debugPrint('[WidgetService] seedInitialData error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PART 1.2: UNIVERSAL COLOR ENGINE
  // Pushes active palette colors dynamically to all native widgets
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> updateTheme(AppPalette palette) async {
    final bgColor = palette.bgDark.toARGB32();
    final surfaceColor = palette.isDark
        ? palette.surfaceElevated.toARGB32()
        : palette.bgCard.toARGB32();
    final primaryColor = palette.primary.toARGB32();
    final accentColor = palette.accent.toARGB32();
    final textPrimary = palette.textPrimary.toARGB32();
    final textSecondary = palette.textSlate400.toARGB32();
    final borderColor = palette.glassBorder.toARGB32();

    await HomeWidget.saveWidgetData<int>('widget_bg_color', bgColor);
    await HomeWidget.saveWidgetData<int>('widget_surface_color', surfaceColor);
    await HomeWidget.saveWidgetData<int>('widget_primary_color', primaryColor);
    await HomeWidget.saveWidgetData<int>('widget_accent_color', accentColor);
    await HomeWidget.saveWidgetData<int>('widget_text_primary', textPrimary);
    await HomeWidget.saveWidgetData<int>('widget_text_secondary', textSecondary);
    await HomeWidget.saveWidgetData<int>('widget_border_color', borderColor);

    await updateAllWidgets();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PART 1.3: PRAYER & COUNTDOWN WIDGET DATA SYNC
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> updatePrayerData({
    required String location,
    required String currentWaqt,
    required String nextPrayerName,
    required String nextPrayerTime,
    required String countdownText,
    required int progressPercent,
    required String fajrTime,
    required String dhuhrTime,
    required String asrTime,
    required String maghribTime,
    required String ishaTime,
  }) async {
    // Medium 4x2
    await HomeWidget.saveWidgetData<String>('prayer_location', location);
    await HomeWidget.saveWidgetData<String>('prayer_current_waqt', currentWaqt);
    await HomeWidget.saveWidgetData<String>(
        'prayer_next_title', '$nextPrayerName $countdownText');
    await HomeWidget.saveWidgetData<String>(
        'prayer_next_subtitle', 'Next: $nextPrayerName at $nextPrayerTime');
    await HomeWidget.saveWidgetData<int>(
        'prayer_progress_percent', progressPercent.clamp(0, 100));

    await HomeWidget.saveWidgetData<String>('prayer_fajr_time', fajrTime);
    await HomeWidget.saveWidgetData<String>('prayer_dhuhr_time', dhuhrTime);
    await HomeWidget.saveWidgetData<String>('prayer_asr_time', asrTime);
    await HomeWidget.saveWidgetData<String>('prayer_maghrib_time', maghribTime);
    await HomeWidget.saveWidgetData<String>('prayer_isha_time', ishaTime);

    // Compact 2x2
    await HomeWidget.saveWidgetData<String>('prayer_compact_location', location);
    await HomeWidget.saveWidgetData<String>(
        'prayer_compact_name', nextPrayerName.toUpperCase());
    await HomeWidget.saveWidgetData<String>(
        'prayer_compact_time', nextPrayerTime);
    await HomeWidget.saveWidgetData<String>(
        'prayer_compact_countdown', countdownText);

    await HomeWidget.updateWidget(
      androidName: prayerCountdownWidget,
      name: prayerCountdownWidget,
    );
    await HomeWidget.updateWidget(
      androidName: prayerCompactWidget,
      name: prayerCompactWidget,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PART 1.3: DAILY ADHKAAR & HABIT TRACKER WIDGET DATA SYNC
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> updateAdhkarTrackerData({
    required int streakDays,
    required int morningDone,
    required int morningTotal,
    required int eveningDone,
    required int eveningTotal,
    String? headerTitle,
    String? footerQuote,
  }) async {
    final morningProgress = morningTotal > 0
        ? ((morningDone / morningTotal) * 100).round()
        : 0;
    final eveningProgress = eveningTotal > 0
        ? ((eveningDone / eveningTotal) * 100).round()
        : 0;

    final morningStatus = morningDone >= morningTotal && morningTotal > 0
        ? '✓ $morningDone/$morningTotal Done'
        : '$morningDone/$morningTotal Pending';

    final eveningStatus = eveningDone >= eveningTotal && eveningTotal > 0
        ? '✓ $eveningDone/$eveningTotal Done'
        : '$eveningDone/$eveningTotal Pending';

    await HomeWidget.saveWidgetData<String>(
        'adhkar_header_title', headerTitle ?? 'DAILY ADHKAAR');
    await HomeWidget.saveWidgetData<String>(
        'adhkar_streak_text', '🔥 $streakDays-DAY STREAK');

    await HomeWidget.saveWidgetData<String>('adhkar_morning_title', '🌅 Morning');
    await HomeWidget.saveWidgetData<String>(
        'adhkar_morning_status', morningStatus);
    await HomeWidget.saveWidgetData<int>(
        'adhkar_morning_progress', morningProgress);

    await HomeWidget.saveWidgetData<String>('adhkar_evening_title', '🌆 Evening');
    await HomeWidget.saveWidgetData<String>(
        'adhkar_evening_status', eveningStatus);
    await HomeWidget.saveWidgetData<int>(
        'adhkar_evening_progress', eveningProgress);

    if (footerQuote != null) {
      await HomeWidget.saveWidgetData<String>('adhkar_footer_text', footerQuote);
    }

    // Small 2x2 data
    await HomeWidget.saveWidgetData<int>('adhkar_small_streak_num', streakDays);
    await HomeWidget.saveWidgetData<String>(
        'adhkar_small_streak_label', 'DAYS STREAK');
    await HomeWidget.saveWidgetData<String>(
        'adhkar_small_morning', morningDone >= morningTotal ? '🌅 ✓' : '🌅 ○');
    await HomeWidget.saveWidgetData<String>(
        'adhkar_small_evening', eveningDone >= eveningTotal ? '🌆 ✓' : '🌆 ○');

    await HomeWidget.updateWidget(
      androidName: adhkarTrackerWidget,
      name: adhkarTrackerWidget,
    );
    await HomeWidget.updateWidget(
      androidName: adhkarTrackerSmallWidget,
      name: adhkarTrackerSmallWidget,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PART 1.3: DUA OF THE DAY WIDGET DATA SYNC
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> updateDuaOfDayData({
    required String title,
    required String categoryBadge,
    required String arabicText,
    required String translationText,
    required String referenceText,
  }) async {
    await HomeWidget.saveWidgetData<String>('dua_header_title', title);
    await HomeWidget.saveWidgetData<String>('dua_category_badge', categoryBadge);
    await HomeWidget.saveWidgetData<String>('dua_arabic_text', arabicText);
    await HomeWidget.saveWidgetData<String>(
        'dua_translation_text', translationText);
    await HomeWidget.saveWidgetData<String>(
        'dua_reference_text', referenceText);

    await HomeWidget.updateWidget(
      androidName: duaOfTheDayWidget,
      name: duaOfTheDayWidget,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PART 1.3: ONE-TAP TASBIH WIDGET DATA SYNC
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> updateTasbihData({
    required String title,
    required int count,
    required int target,
    String btnText = '➕ TAP',
  }) async {
    await HomeWidget.saveWidgetData<String>('tasbih_title', title);
    await HomeWidget.saveWidgetData<int>('tasbih_count', count);
    await HomeWidget.saveWidgetData<String>(
        'tasbih_target', 'Target: $target');
    await HomeWidget.saveWidgetData<String>('tasbih_btn_text', btnText);

    // Save in SharedPreferences for background receiver as well
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('tasbih_widget_count', count);

    await HomeWidget.updateWidget(
      androidName: tasbihWidget,
      name: tasbihWidget,
    );
  }

  /// Triggers a native repaint across all 6 widget providers
  Future<void> updateAllWidgets() async {
    for (final provider in allWidgetProviders) {
      try {
        await HomeWidget.updateWidget(
          androidName: provider,
          name: provider,
        );
      } catch (e) {
        debugPrint('[WidgetService] updateWidget($provider) error: $e');
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DEEP LINKING ROUTER
  // ══════════════════════════════════════════════════════════════════════════
  void handleDeepLink(Uri uri) {
    final target = '${uri.host}${uri.path}'.toLowerCase();
    if (target.contains('tasbih_increment')) {
      return;
    }
    final nav = appNavigatorKey.currentState;
    if (nav == null) {
      debugPrint('[WidgetService] appNavigatorKey.currentState is null, queuing pending launch: $uri');
      _pendingLaunchUri = uri;
      return;
    }

    debugPrint('[WidgetService] Deep link triggered: $uri (target: $target)');

    if (target.contains('prayer_times') || target.contains('prayer')) {
      nav.push(MaterialPageRoute(builder: (_) => const PrayerTimesScreen()));
    } else if (target.contains('morning')) {
      nav.push(MaterialPageRoute(
        builder: (_) => const DhikrListScreen(category: DhikrCategory.morning),
      ));
    } else if (target.contains('evening')) {
      nav.push(MaterialPageRoute(
        builder: (_) => const DhikrListScreen(category: DhikrCategory.evening),
      ));
    } else if (target.contains('before_sleep') || target.contains('sleep')) {
      nav.push(MaterialPageRoute(
        builder: (_) => const DhikrListScreen(category: DhikrCategory.beforeSleep),
      ));
    } else if (target.contains('progress') || target.contains('streak')) {
      nav.push(MaterialPageRoute(builder: (_) => const ProgressScreen()));
    } else if (target.contains('dua_of_day') || target.contains('dua')) {
      nav.push(MaterialPageRoute(builder: (_) => const DuaScreen()));
    } else if (target.contains('tasbih')) {
      nav.push(MaterialPageRoute(
        builder: (_) => const DhikrListScreen(category: DhikrCategory.focus),
      ));
    }
  }

  void dispose() {
    _widgetClickSub?.cancel();
  }
}
