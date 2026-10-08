// ============================================================================
// lib/services/notification_service.dart
//
// LOCAL NOTIFICATION SYSTEM — Adhkaar 365
//
// Handles:
//   [LOCAL]  Morning Adhkar  → scheduled at Sunrise  (adhan package)
//   [LOCAL]  Evening Adhkar  → scheduled at Maghrib  (adhan package)
//   [LOCAL]  Prayer time alerts → Fajr/Dhuhr/Asr/Maghrib/Isha (7-day rolling)
//
// Architecture: Singleton — NotificationService()
// ============================================================================

import 'dart:io';

import 'package:adhan/adhan.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_theme.dart';
import '../models/dhikr.dart';
import '../screens/dhikr_list_screen.dart';
import '../utils/app_navigator.dart';
import 'smart_notification_engine.dart';
import 'widget_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Notification ID Registry
// Keep these stable — changing IDs breaks existing scheduled notifications.
// ─────────────────────────────────────────────────────────────────────────────
class _IDs {
  // Adhkar reminders
  static const int morning     = 1000; // 1000–1009
  static const int evening     = 1100; // 1100–1109, safe gap
  static const int beforeSleep = 1200; // 1200–1209
  static const int jumuah      = 1300; // 1300–1309
  static const int snooze      = 1400; // 1400–1409

  // Prayer-time alerts — one slot per day in the rolling window.
  // Bases are 10 apart, so kDaysAhead must never exceed 10.
  static const int fajrBase = 2000; // 2000–2009
  static const int sunriseBase = 2010; // 2010–2019
  static const int dhuhrBase = 2020; // 2020–2029
  static const int asrBase = 2030; // 2030–2039
  static const int maghribBase = 2040; // 2040–2049
  static const int ishaBase = 2050; // 2050–2059

  // Channel IDs — v2 forces fresh channel creation on install.
  // Android ignores createNotificationChannel() if the ID already exists,
  // so old corrupted channels (from the previous ic_notification crash) are
  // bypassed permanently. User MUST uninstall old app before installing this.
  static const String adhkarChannelId = 'adhkaar_adhkar_v2';
  static const String prayerChannelId = 'adhkaar_prayer_v2';
}

// ─────────────────────────────────────────────────────────────────────────────
// NotificationService — Singleton
// ─────────────────────────────────────────────────────────────────────────────
class NotificationService {
  // Singleton boilerplate
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  /// Rolling scheduling window. Capped at 10 by the notification ID layout
  /// (prayer ID bases are 10 apart — see [_IDs]).
  static const int kDaysAhead = 10;

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Cached result of canScheduleExactNotifications() — avoids calling it once
  // per notification in a loop (10 days × 8 prayers = 80 async calls otherwise).
  bool? _cachedCanExact;

  /// Whether the most recent scheduling session used exact (alarmClock) mode.
  /// Compared against the live permission on app resume: if the user granted
  /// "Alarms & Reminders" while we were backgrounded, everything must be
  /// rescheduled in exact mode.
  bool? lastScheduleUsedExact;

  // ── Public: called once from main() ────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;

    // 1. Timezone database setup with multi-tier resilient fallback
    try {
      tz_data.initializeTimeZones();
      String? timeZoneName;
      try {
        timeZoneName = await FlutterTimezone.getLocalTimezone();
      } catch (e) {
        debugPrint('[NotificationService] Failed to get local timezone name: $e');
      }
      final loc = _resolveLocation(timeZoneName);
      tz.setLocalLocation(loc);
      debugPrint('[NotificationService] Timezone set to: ${loc.name}');
    } catch (e) {
      debugPrint('[NotificationService] Critical timezone init error: $e');
      try {
        tz.setLocalLocation(tz.getLocation('UTC'));
      } catch (_) {}
    }

    // 2. Local notifications setup — must always execute
    try {
      await _initLocalNotifications();
      _initialized = true;
      debugPrint('[NotificationService] Local notifications initialized successfully');
    } catch (e) {
      debugPrint('[NotificationService] _initLocalNotifications failed: $e');
    }
  }

  /// Resilient timezone location resolver:
  /// 1. Tries direct lookup: tz.getLocation(timeZoneName)
  /// 2. If fails, checks known aliases (e.g. Asia/Dacca, Asia/Calcutta, etc.)
  /// 3. If still fails (e.g. "GMT+06:00" or raw offset), finds a timezone in
  ///    tz.timeZoneDatabase whose current offset matches the device clock's offset.
  /// 4. Fallback to UTC if all else fails.
  static tz.Location _resolveLocation(String? timeZoneName) {
    if (timeZoneName != null && timeZoneName.isNotEmpty) {
      try {
        return tz.getLocation(timeZoneName);
      } catch (_) {}

      final alias = _knownTimezoneAliases[timeZoneName];
      if (alias != null) {
        try {
          return tz.getLocation(alias);
        } catch (_) {}
      }
    }

    // Fallback: match by actual device clock offset
    final currentOffsetMs = DateTime.now().timeZoneOffset.inMilliseconds;
    for (final loc in tz.timeZoneDatabase.locations.values) {
      if (loc.currentTimeZone.offset == currentOffsetMs) {
        return loc;
      }
    }

    // Ultimate fallback
    return tz.getLocation('UTC');
  }

  static const Map<String, String> _knownTimezoneAliases = {
    'Asia/Dacca': 'Asia/Dhaka',
    'Asia/Calcutta': 'Asia/Kolkata',
    'Asia/Katmandu': 'Asia/Kathmandu',
    'Asia/Saigon': 'Asia/Ho_Chi_Minh',
    'Asia/Rangoon': 'Asia/Yangon',
    'Asia/Ulan_Bator': 'Asia/Ulaanbaatar',
    'Asia/Macao': 'Asia/Macau',
    'Asia/Thimbu': 'Asia/Thimphu',
    'US/Eastern': 'America/New_York',
    'US/Central': 'America/Chicago',
    'US/Mountain': 'America/Denver',
    'US/Pacific': 'America/Los_Angeles',
  };

  // ══════════════════════════════════════════════════════════════════════════
  // LOCAL NOTIFICATIONS — Setup
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _initLocalNotifications() async {
    // ── iOS / macOS settings ──
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Multi-tier icon fallback for Android:
    // 1. 'ic_stat_notification' — dedicated monochrome white PNG (in all res/drawable-* folders)
    // 2. 'launcher_icon' — PNG in res/drawable-*
    // 3. '@mipmap/launcher_icon' — Android standard mipmap launcher icon
    // NOTE: Android requires the resource NAME without '@drawable/' prefix.
    bool initialized = false;
    for (final iconName in ['ic_stat_notification', 'launcher_icon', '@mipmap/launcher_icon']) {
      try {
        final android = AndroidInitializationSettings(iconName);
        final settings = InitializationSettings(android: android, iOS: darwin);
        await _local.initialize(
          settings,
          onDidReceiveNotificationResponse: _onLocalNotificationTap,
          onDidReceiveBackgroundNotificationResponse:
              _onBackgroundLocalNotificationTap,
        );
        debugPrint('[NotificationService] Local notifications initialized with icon: $iconName');
        initialized = true;
        break;
      } catch (e) {
        debugPrint('[NotificationService] Failed to init with icon $iconName: $e');
      }
    }

    if (!initialized) {
      debugPrint('[NotificationService] CRITICAL: Fallback initialize without specific icon');
      try {
        const android = AndroidInitializationSettings('@mipmap/launcher_icon');
        await _local.initialize(
          const InitializationSettings(android: android, iOS: darwin),
          onDidReceiveNotificationResponse: _onLocalNotificationTap,
          onDidReceiveBackgroundNotificationResponse:
              _onBackgroundLocalNotificationTap,
        );
      } catch (e) {
        debugPrint('[NotificationService] Emergency init error: $e');
      }
    }

    // Create Android notification channels
    await _createChannels();
  }

  Future<void> _createChannels() async {
    if (!Platform.isAndroid) return;

    final androidPlugin = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    // Adhkar reminders channel — max importance, heads-up banner, custom sound
    await androidPlugin?.createNotificationChannel(
      AndroidNotificationChannel(
        _IDs.adhkarChannelId,
        'Adhkar Reminders',
        description: 'Morning and Evening Adhkar reminders',
        importance: Importance.max,
        playSound: true,
        sound: null,
        enableVibration: true,
        enableLights: true,
        ledColor: AppColors.primary, // follows the active theme
      ),
    );

    // Prayer alerts channel — max importance
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _IDs.prayerChannelId,
        'Prayer Time Alerts',
        description: 'Alerts for each prayer time',
        importance: Importance.max,
        playSound: true,
        sound: null,
        enableVibration: true,
      ),
    );

  }

  // ── Notification tap handler (foreground) ──────────────────────────────────
  static void _onLocalNotificationTap(NotificationResponse response) {
    final payload = response.payload ?? '';
    debugPrint('[Local] Tapped: id=${response.id}, actionId=${response.actionId}, payload=$payload');
    if (response.actionId == SmartNotificationEngine.actionSnooze) {
      NotificationService().scheduleSnooze(payload);
      return;
    }
    _routeForPayload(payload);
  }

  // ── Notification tap handler (background) — must be top-level ─────────────
  @pragma('vm:entry-point')
  static void _onBackgroundLocalNotificationTap(NotificationResponse response) {
    final payload = response.payload ?? '';
    debugPrint('[Local BG] Tapped: id=${response.id}, actionId=${response.actionId}, payload=$payload');
    if (response.actionId == SmartNotificationEngine.actionSnooze) {
      NotificationService().scheduleSnooze(payload);
      return;
    }
    _routeForPayload(payload);
  }

  // ── Shared routing logic ───────────────────────────────────────────────────
  /// Pushes the appropriate screen for a given notification payload.
  /// Safe to call from any context — uses the global [appNavigatorKey].
  static void _routeForPayload(String payload) {
    final nav = appNavigatorKey.currentState;
    if (nav == null) return; // app not ready yet

    if (payload == 'morning' ||
        payload == 'prayer:fajr' ||
        payload == 'prayer:sunrise') {
      // Morning adhkar period (Fajr → sunrise) → open Morning Adhkar screen
      nav.push(MaterialPageRoute(
        builder: (_) => const DhikrListScreen(category: DhikrCategory.morning),
      ));
    } else if (payload == 'evening' ||
        payload == 'prayer:asr' ||
        payload == 'prayer:maghrib') {
      // Evening adhkar period (Asr → Maghrib) → open Evening Adhkar screen
      nav.push(MaterialPageRoute(
        builder: (_) => const DhikrListScreen(category: DhikrCategory.evening),
      ));
    } else if (payload == 'sleep' || payload == 'prayer:isha') {
      // Before sleep period → open Before Sleep Adhkar screen
      nav.push(MaterialPageRoute(
        builder: (_) => const DhikrListScreen(category: DhikrCategory.beforeSleep),
      ));
    } else if (payload == 'jumuah') {
      // Jumu'ah Hour of Acceptance → open Protection / General Adhkar
      nav.push(MaterialPageRoute(
        builder: (_) => const DhikrListScreen(category: DhikrCategory.protection),
      ));
    }
    // Other prayer alerts (Dhuhr) just bring the app to foreground —
    // the Dashboard already shows all prayer times.
  }

  // ── Cold-start: payload from the notification that launched the app ────────
  /// Returns the payload string if the app was opened by tapping a notification
  /// while it was completely closed. Returns null otherwise.
  Future<String?> getLaunchPayload() async {
    final details = await _local.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse?.payload;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PERMISSIONS
  // ══════════════════════════════════════════════════════════════════════════

  static const _batteryChannel = MethodChannel('dhikr365/battery');

  /// Returns true if the device can schedule exact (alarm-clock) notifications.
  /// Result is cached after the first call — call [invalidateExactAlarmCache]
  /// after the user returns from the Settings page to force a re-check.
  Future<bool> isExactAlarmGranted() async {
    if (!Platform.isAndroid) return true;
    if (_cachedCanExact != null) return _cachedCanExact!;
    try {
      final plugin = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      _cachedCanExact = await plugin?.canScheduleExactNotifications() ?? false;
    } catch (_) {
      _cachedCanExact = false;
    }
    debugPrint('[Permissions] canScheduleExactNotifications=$_cachedCanExact');
    return _cachedCanExact!;
  }

  /// Opens the Android "Alarms & Reminders" special-access settings page so
  /// the user can grant SCHEDULE_EXACT_ALARM permission manually.
  Future<void> openExactAlarmSettings() async {
    if (!Platform.isAndroid) return;
    _cachedCanExact = null; // invalidate so next schedule re-checks
    try {
      final plugin = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await plugin?.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('[Permissions] openExactAlarmSettings error: $e');
    }
  }

  /// Opens the system Notification settings page for this app so user
  /// can turn notifications back ON if they tapped "Don't allow" earlier.
  Future<void> openNotificationSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _batteryChannel.invokeMethod('openNotificationSettings');
    } catch (e) {
      debugPrint('[Permissions] openNotificationSettings error: $e');
    }
  }

  /// Call after the user returns from Settings to force a fresh permission check.
  void invalidateExactAlarmCache() => _cachedCanExact = null;

  /// Returns true if app notifications are enabled in system settings.
  Future<bool> areNotificationsEnabled() async {
    if (!Platform.isAndroid) return true;
    try {
      final androidPlugin = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await androidPlugin?.areNotificationsEnabled() ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<bool> requestPermissions() async {
    _cachedCanExact = null; // always re-check after a permission request cycle
    final androidPlugin = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      // NOTE: do NOT call requestExactAlarmsPermission() or
      // requestBatteryOptimizationExemption() here. Both fire a raw system
      // Settings intent immediately with zero explanation, racing the
      // POST_NOTIFICATIONS prompt and confusing users. Both flows are owned
      // by explainer dialogs in SplashScreen (shown one after another, each
      // explained in plain language before the system popup appears) — the
      // same pattern Muslim Pro and other prayer apps use.
      debugPrint('[Permissions] Android notification permissions requested');
      return true;
    }

    // iOS — request via flutter_local_notifications
    final iosPlugin = _local.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final granted = await iosPlugin?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        false;
    debugPrint('[Permissions] iOS notifications granted: $granted');
    return granted;
  }

  /// Asks Android to exclude this app from battery optimization.
  /// Without this, the OS can kill scheduled alarms on Samsung/Xiaomi/Oppo
  /// devices — exactly what Muslim Pro requests on first launch.
  Future<void> requestBatteryOptimizationExemption() async {
    if (!Platform.isAndroid) return;
    try {
      final bool alreadyExempt = await isIgnoringBatteryOptimizations();
      if (!alreadyExempt) {
        await _batteryChannel.invokeMethod('requestIgnoreBatteryOptimizations');
        debugPrint('[Battery] Requested battery optimization exemption');
      } else {
        debugPrint('[Battery] Already exempt from battery optimization');
      }
    } catch (e) {
      debugPrint('[Battery] Could not request battery optimization: $e');
    }
  }

  /// True when this app is already whitelisted from Android's Doze/App
  /// Standby battery optimization. Used by the explainer dialog to skip
  /// itself entirely when there's nothing left to ask for.
  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _batteryChannel
              .invokeMethod<bool>('isIgnoringBatteryOptimizations') ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Returns 'xiaomi' / 'oppo' / 'vivo' / 'huawei' / 'honor' if this device's
  /// manufacturer ships its own aggressive app-killer that standard Android's
  /// battery-optimization whitelist does NOT reliably stop — these need a
  /// separate manual "Autostart" toggle in the OEM's own settings. Returns
  /// null on Pixel/most Samsung/OnePlus devices, where nothing extra is needed.
  Future<String?> getAutostartBrand() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _batteryChannel.invokeMethod<String>('getAutostartBrand');
    } catch (_) {
      return null;
    }
  }

  /// Opens the manufacturer's own Autostart/Startup-manager screen so the
  /// user can manually allow this app to run in the background. Falls back
  /// to the app's system Settings page if no known screen is found.
  Future<void> openAutostartSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _batteryChannel.invokeMethod('openAutostartSettings');
    } catch (e) {
      debugPrint('[Battery] openAutostartSettings error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SCHEDULING — Morning & Evening Adhkar
  // ══════════════════════════════════════════════════════════════════════════

  /// Main entry point called from NotificationProvider.
  /// Schedules Morning (Sunrise) and Evening (Maghrib) reminders
  /// for the next [daysAhead] days using real adhan calculations.
  Future<void> scheduleAdhkarReminders(
    double lat,
    double lng, {
    int daysAhead = kDaysAhead,
    CalculationMethod calculationMethod = CalculationMethod.muslim_world_league,
    String madhab = 'shafii',
    String? langCode,
  }) async {
    // Cancel existing before rescheduling to avoid duplicates
    await cancelMorningNotification();
    await cancelEveningNotification();
    await cancelBeforeSleepNotification();
    await cancelJumuahNotification();

    final prefs = await SharedPreferences.getInstance();
    final lang = langCode ?? prefs.getString('language_code') ?? 'en';
    final streak = prefs.getInt('streak_days') ?? 0;

    final coords = Coordinates(lat, lng);
    final params = calculationMethod.getParameters()
      ..madhab =
          madhab.toLowerCase() == 'hanafi' ? Madhab.hanafi : Madhab.shafi;

    final now = DateTime.now();

    final actions = [
      AndroidNotificationAction(
        SmartNotificationEngine.actionRead,
        SmartNotificationEngine.getReadActionLabel(lang),
        showsUserInterface: true,
      ),
      AndroidNotificationAction(
        SmartNotificationEngine.actionSnooze,
        SmartNotificationEngine.getSnoozeActionLabel(lang),
        showsUserInterface: false,
      ),
    ];

    for (int i = 0; i < daysAhead; i++) {
      final day = now.add(Duration(days: i));
      final dateComp = DateComponents.from(day);
      final times = PrayerTimes(coords, dateComp, params);

      // 1. Morning Adhkar: 18 mins after Fajr (prime Sunnah window before sunrise)
      final morningTime = times.fajr.toLocal().add(SmartNotificationEngine.morningFajrOffset);
      final morningHook = SmartNotificationEngine.getMorningHook(lang, i, streak: streak);

      if (morningTime.isAfter(now)) {
        await _scheduleLocalNotification(
          id: _IDs.morning + i, // 1000–1009
          title: morningHook.title,
          body: morningHook.body,
          scheduledTime: morningTime,
          channelId: _IDs.adhkarChannelId,
          channelName: 'Adhkar Reminders',
          payload: 'morning',
          sound: null,
          subText: null,
          actions: actions,
        );
      }

      // 2. Evening Adhkar: 12 mins after Asr (prime Sunnah window before Maghrib)
      final eveningTime = times.asr.toLocal().add(SmartNotificationEngine.eveningAsrOffset);
      final eveningHook = SmartNotificationEngine.getEveningHook(lang, i, streak: streak);

      if (eveningTime.isAfter(now)) {
        await _scheduleLocalNotification(
          id: _IDs.evening + i, // 1100–1109
          title: eveningHook.title,
          body: eveningHook.body,
          scheduledTime: eveningTime,
          channelId: _IDs.adhkarChannelId,
          channelName: 'Adhkar Reminders',
          payload: 'evening',
          sound: null,
          subText: null,
          actions: actions,
        );
      }

      // 3. Before Sleep Adhkar: 35 mins after Isha
      final sleepTime = times.isha.toLocal().add(SmartNotificationEngine.beforeSleepIshaOffset);
      final sleepHook = SmartNotificationEngine.getBeforeSleepHook(lang, i);

      if (sleepTime.isAfter(now)) {
        await _scheduleLocalNotification(
          id: _IDs.beforeSleep + i, // 1200–1209
          title: sleepHook.title,
          body: sleepHook.body,
          scheduledTime: sleepTime,
          channelId: _IDs.adhkarChannelId,
          channelName: 'Adhkar Reminders',
          payload: 'sleep',
          sound: null,
          subText: null,
          actions: actions,
        );
      }

      // 4. Jumu'ah Hour of Acceptance: Fridays 60 mins before Maghrib
      if (day.weekday == DateTime.friday) {
        final jumuahTime = times.maghrib.toLocal().add(SmartNotificationEngine.jumuahMaghribOffset);
        final jumuahHook = SmartNotificationEngine.getJumuahHook(lang, i);

        if (jumuahTime.isAfter(now)) {
          await _scheduleLocalNotification(
            id: _IDs.jumuah + i, // 1300–1309
            title: jumuahHook.title,
            body: jumuahHook.body,
            scheduledTime: jumuahTime,
            channelId: _IDs.adhkarChannelId,
            channelName: 'Adhkar Reminders',
            payload: 'jumuah',
            sound: null,
            subText: null,
            actions: actions,
          );
        }
      }
    }

    debugPrint('[Scheduler] Smart Sunnah Adhkar reminders scheduled for $daysAhead days (lang: $lang)');
  }

  Future<void> cancelBeforeSleepNotification() async {
    for (int i = 0; i < kDaysAhead; i++) {
      await _local.cancel(_IDs.beforeSleep + i);
    }
  }

  Future<void> cancelJumuahNotification() async {
    for (int i = 0; i < kDaysAhead; i++) {
      await _local.cancel(_IDs.jumuah + i);
    }
  }

  Future<void> scheduleSnooze(String payload) async {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString('language_code') ?? 'en';
    final isBn = lang == 'bn';
    final snoozeTime = DateTime.now().add(const Duration(minutes: 15));

    String title;
    String body;
    if (payload.contains('morning')) {
      title = isBn ? '⏰ সকালের আযকার রিমাইন্ডার' : '⏰ Morning Adhkar Reminder';
      body = isBn
          ? '১৫ মিনিট অতিক্রান্ত হয়েছে। সকালের বরকতময় আযকার পাঠ করে দিনটি শুরু করুন।'
          : '15 minutes have passed. Start your day with the blessed Morning Adhkar.';
    } else if (payload.contains('evening')) {
      title = isBn ? '⏰ সন্ধ্যার আযকার রিমাইন্ডার' : '⏰ Evening Adhkar Reminder';
      body = isBn
          ? '১৫ মিনিট অতিক্রান্ত হয়েছে। মাগরিবের পূর্বেই সন্ধ্যার আযকার পড়ে নিন।'
          : '15 minutes have passed. Complete your Evening Adhkar before sunset.';
    } else if (payload.contains('sleep')) {
      title = isBn ? '⏰ ঘুমের আগের আযকার' : '⏰ Before Sleep Adhkar';
      body = isBn
          ? 'ঘুমের পূর্বে দোয়া ও সূরাগুলো পাঠ করে অন্তরে প্রশান্তি আনুন।'
          : 'Recite your bedtime duas and surahs for peaceful sleep.';
    } else {
      title = isBn ? '⏰ আযকার রিমাইন্ডার' : '⏰ Adhkar Reminder';
      body = isBn ? 'আপনার দৈনিক জিকির সম্পন্ন করুন।' : 'Complete your daily remembrance.';
    }

    final actions = [
      AndroidNotificationAction(
        SmartNotificationEngine.actionRead,
        SmartNotificationEngine.getReadActionLabel(lang),
        showsUserInterface: true,
      ),
    ];

    await _scheduleLocalNotification(
      id: _IDs.snooze,
      title: title,
      body: body,
      scheduledTime: snoozeTime,
      channelId: _IDs.adhkarChannelId,
      channelName: 'Adhkar Reminders',
      payload: payload,
      actions: actions,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SCHEDULING — Prayer Time Alerts
  // ══════════════════════════════════════════════════════════════════════════

  /// Schedule each prayer time alert for the next 7 days.
  /// [enabledPrayers] map lets SettingsScreen toggle individual prayers.
  Future<void> schedulePrayerTimes(
    double lat,
    double lng, {
    Map<String, bool> enabledPrayers = const {
      'Fajr': true,
      'Sunrise': true,
      'Dhuhr': true,
      'Asr': true,
      'Maghrib': true,
      'Isha': true,
    },
    int daysAhead = kDaysAhead,
    CalculationMethod calculationMethod = CalculationMethod.muslim_world_league,
    String madhab = 'shafii',
    String? langCode,
  }) async {
    await cancelAllPrayerNotifications();

    final prefs = await SharedPreferences.getInstance();
    final lang = langCode ?? prefs.getString('language_code') ?? 'en';

    final coords = Coordinates(lat, lng);
    final params = calculationMethod.getParameters()
      ..madhab =
          madhab.toLowerCase() == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
    final now = DateTime.now();

    const prayerBases = {
      'Fajr': _IDs.fajrBase,
      'Sunrise': _IDs.sunriseBase,
      'Dhuhr': _IDs.dhuhrBase,
      'Asr': _IDs.asrBase,
      'Maghrib': _IDs.maghribBase,
      'Isha': _IDs.ishaBase,
    };

    final prayerConfig = prayerBases.entries.map((e) {
      final text = _NotificationLocale.getPrayer(e.key, lang);
      return _PrayerConfig(e.key, e.value, text.title, text.body);
    }).toList();

    for (int i = 0; i < daysAhead; i++) {
      final day = now.add(Duration(days: i));
      final dateComp = DateComponents.from(day);
      final times = PrayerTimes(coords, dateComp, params);

      if (i == 0) {
        // Sync today's prayer times to Home Screen Widgets
        try {
          final fmt = DateFormat('hh:mm a');
          final city = prefs.getString('saved_city');
          final country = prefs.getString('saved_country');
          final locationName = (city != null && city.isNotEmpty)
              ? (country != null && country.isNotEmpty ? '$city, $country' : city)
              : 'Prayer Times';

          String nextPrayer = 'Fajr';
          DateTime nextTime = times.fajr;
          String currentWaqt = 'Isha';

          if (now.isBefore(times.fajr)) {
            nextPrayer = 'Fajr';
            nextTime = times.fajr;
            currentWaqt = 'Tahajjud';
          } else if (now.isBefore(times.dhuhr)) {
            nextPrayer = 'Dhuhr';
            nextTime = times.dhuhr;
            currentWaqt = now.isBefore(times.sunrise) ? 'Fajr' : 'Duha';
          } else if (now.isBefore(times.asr)) {
            nextPrayer = 'Asr';
            nextTime = times.asr;
            currentWaqt = 'Dhuhr';
          } else if (now.isBefore(times.maghrib)) {
            nextPrayer = 'Maghrib';
            nextTime = times.maghrib;
            currentWaqt = 'Asr';
          } else if (now.isBefore(times.isha)) {
            nextPrayer = 'Isha';
            nextTime = times.isha;
            currentWaqt = 'Maghrib';
          } else {
            nextPrayer = 'Fajr';
            nextTime = times.fajr.add(const Duration(days: 1));
            currentWaqt = 'Isha';
          }

          final diff = nextTime.difference(now);
          final h = diff.inHours;
          final m = diff.inMinutes % 60;
          final countdown = h > 0 ? 'in ${h}h ${m}m' : 'in ${m}m';

          WidgetService().updatePrayerData(
            location: locationName,
            currentWaqt: '$currentWaqt Waqt',
            nextPrayerName: nextPrayer,
            nextPrayerTime: fmt.format(nextTime.toLocal()),
            countdownText: countdown,
            progressPercent: 50,
            fajrTime: fmt.format(times.fajr.toLocal()),
            dhuhrTime: fmt.format(times.dhuhr.toLocal()),
            asrTime: fmt.format(times.asr.toLocal()),
            maghribTime: fmt.format(times.maghrib.toLocal()),
            ishaTime: fmt.format(times.isha.toLocal()),
          );
        } catch (e) {
          debugPrint('[NotificationService] WidgetService.updatePrayerData error: $e');
        }
      }

      for (final cfg in prayerConfig) {
        if (!(enabledPrayers[cfg.name] ?? true)) continue;

        final prayerTime = _getPrayerTime(times, cfg.name).toLocal();
        if (prayerTime.isAfter(now)) {
          await _scheduleLocalNotification(
            id: cfg.baseId + i,
            title: cfg.title,
            body: cfg.body,
            scheduledTime: prayerTime,
            channelId: _IDs.prayerChannelId,
            channelName: 'Prayer Alerts',
            payload: 'prayer:${cfg.name.toLowerCase()}',
            sound: null,
            subText: null,
          );
        }
      }
    }

    debugPrint('[Scheduler] Prayer times scheduled for $daysAhead days (lang: $lang)');
  }

  DateTime _getPrayerTime(PrayerTimes times, String name) {
    switch (name) {
      case 'Fajr':
        return times.fajr;
      case 'Sunrise':
        return times.sunrise;
      case 'Dhuhr':
        return times.dhuhr;
      case 'Asr':
        return times.asr;
      case 'Maghrib':
        return times.maghrib;
      case 'Isha':
        return times.isha;
      default:
        return times.fajr;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CORE — Schedule a single local notification at an exact time
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _scheduleLocalNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required String channelId,
    required String channelName,
    required String payload,
    String? sound,
    String? subText,
    List<AndroidNotificationAction>? actions,
  }) async {
    // Convert to TZDateTime — required by flutter_local_notifications
    final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.max,
      priority: Priority.max,
      actions: actions,
      // Status-bar small icon: monochrome white PNG in res/drawable-*
      icon: 'ic_stat_notification',
      subText: subText,
      // Custom Islamic tone — file must be in android/app/src/main/res/raw/
      sound: sound != null ? RawResourceAndroidNotificationSound(sound) : null,
      playSound: true,
      enableVibration: true,
      // Show heads-up notification even when screen is off
      fullScreenIntent: false,
      // Marks these as time-critical reminders — OEM battery managers
      // (Samsung/Xiaomi/OPPO) deprioritize uncategorized notifications.
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      ticker: title,
      // Accent follows the active theme (amber, purple, gold, rose…).
      // Baked in at schedule time — ThemeProvider triggers a reschedule
      // on theme change so pending notifications adopt the new color.
      color: AppColors.primary,
      ledColor: AppColors.primary,
      ledOnMs: 1000,
      ledOffMs: 500,
      // Plain text, NOT html-formatted: Android's Html.fromHtml drops or
      // mangles emoji (🌇 🌄 ☀️) and mixed Arabic on many devices. Titles
      // are bold by default anyway, so HTML bought nothing and broke emoji.
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
      ),
    );

    final iosDetails = DarwinNotificationDetails(
      // Custom sound file must be in iOS/Runner/Resources/adhan_tone.aiff
      sound: sound != null ? '$sound.aiff' : null,
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    // Top-tier Android alarm mode: alarmClock.
    // Uses AlarmManager.setAlarmClock — the most authoritative wake-from-deep-Doze
    // mechanism in Android OS. Critical on Samsung One UI, Xiaomi MIUI, and Oppo,
    // which otherwise throttle exactAllowWhileIdle alarms.
    AndroidScheduleMode scheduleMode;
    if (Platform.isAndroid) {
      final canExact = await isExactAlarmGranted();
      lastScheduleUsedExact = canExact;
      scheduleMode = canExact
          ? AndroidScheduleMode.alarmClock
          : AndroidScheduleMode.inexactAllowWhileIdle;
    } else {
      scheduleMode = AndroidScheduleMode.alarmClock;
    }

    Future<void> doSchedule(AndroidScheduleMode mode) {
      return _local.zonedSchedule(
        id,
        title,
        body,
        tzTime,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    }

    try {
      await doSchedule(scheduleMode);
      debugPrint('[Scheduler] OK id=$id "$title" at $scheduledTime ($scheduleMode)');
    } catch (e) {
      debugPrint('[Scheduler] Primary schedule mode ($scheduleMode) failed: $e. Trying fallback...');
      if (scheduleMode == AndroidScheduleMode.alarmClock) {
        try {
          await doSchedule(AndroidScheduleMode.exactAllowWhileIdle);
          debugPrint('[Scheduler] OK id=$id "$title" (fallback exactAllowWhileIdle)');
          return;
        } catch (_) {}
      }
      _cachedCanExact = false;
      lastScheduleUsedExact = false;
      try {
        await doSchedule(AndroidScheduleMode.inexactAllowWhileIdle);
        debugPrint('[Scheduler] OK id=$id "$title" (fallback inexactAllowWhileIdle)');
      } catch (e3) {
        debugPrint('[Scheduler] FAILED ALL MODES id=$id "$title": $e3');
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CANCEL — Granular controls for SettingsScreen toggles
  // ══════════════════════════════════════════════════════════════════════════

  /// Cancel all morning adhkar reminders (whole rolling window)
  Future<void> cancelMorningNotification() async {
    for (int i = 0; i < kDaysAhead; i++) {
      try { await _local.cancel(_IDs.morning + i); } catch (_) {}
    }
    debugPrint('[Cancel] Morning notifications cancelled');
  }

  /// Cancel all evening adhkar reminders (whole rolling window)
  Future<void> cancelEveningNotification() async {
    for (int i = 0; i < kDaysAhead; i++) {
      try { await _local.cancel(_IDs.evening + i); } catch (_) {}
    }
    debugPrint('[Cancel] Evening notifications cancelled');
  }

  /// Cancel all prayer time alerts (all prayers, whole rolling window)
  Future<void> cancelAllPrayerNotifications() async {
    final bases = [
      _IDs.fajrBase,
      _IDs.sunriseBase,
      _IDs.dhuhrBase,
      _IDs.asrBase,
      _IDs.maghribBase,
      _IDs.ishaBase,
    ];
    for (final base in bases) {
      for (int i = 0; i < kDaysAhead; i++) {
        try { await _local.cancel(base + i); } catch (_) {}
      }
    }
    debugPrint('[Cancel] All prayer notifications cancelled');
  }

  /// Cancel a specific prayer's alerts (e.g. just Fajr)
  Future<void> cancelSpecificPrayer(String prayerName) async {
    final base = _prayerBase(prayerName);
    if (base == null) return;
    for (int i = 0; i < kDaysAhead; i++) {
      try { await _local.cancel(base + i); } catch (_) {}
    }
    debugPrint('[Cancel] $prayerName notifications cancelled');
  }

  /// Cancel absolutely everything — useful on logout
  Future<void> cancelAll() async {
    try { await _local.cancelAll(); } catch (_) {}
    debugPrint('[Cancel] ALL notifications cancelled');
  }

  int? _prayerBase(String name) {
    switch (name) {
      case 'Fajr':
        return _IDs.fajrBase;
      case 'Sunrise':
        return _IDs.sunriseBase;
      case 'Dhuhr':
        return _IDs.dhuhrBase;
      case 'Asr':
        return _IDs.asrBase;
      case 'Maghrib':
        return _IDs.maghribBase;
      case 'Isha':
        return _IDs.ishaBase;
      default:
        return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DEBUG — List all pending notifications
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> debugPrintPending() async {
    final pending = await _local.pendingNotificationRequests();
    debugPrint('[Debug] Pending notifications: ${pending.length}');
    for (final n in pending) {
      debugPrint('  id=${n.id}  title="${n.title}"  payload=${n.payload}');
    }
  }

  /// FOR TESTING: Fires one notification immediately + one scheduled in 10 seconds.
  /// Use this to verify both instant and scheduled delivery work on the device.
  Future<bool> showInstantTestNotification() async {
    try {
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          _IDs.adhkarChannelId,
          'Adhkar Reminders',
          importance: Importance.max,
          priority: Priority.max,
          icon: 'ic_stat_notification',
          playSound: true,
          enableVibration: true,
          color: AppColors.primary,
          styleInformation: const BigTextStyleInformation(
            'ইনস্ট্যান্ট নোটিফিকেশন সফল! ১০ সেকেন্ডের মধ্যে পরবর্তী শিডিউল অ্যালার্ম পরীক্ষা সম্পন্ন হবে।\nInstant delivery works! Checking 10-second scheduled alarm…',
            contentTitle: '☪️ Adhkaar 365 — টেস্ট নোটিফিকেশন সফল',
          ),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      // 1. Instant notification
      try {
        await _local.show(
          999,
          '☪️ Adhkaar 365 — টেস্ট নোটিফিকেশন সফল',
          'ইনস্ট্যান্ট নোটিফিকেশন সফল! ১০ সেকেন্ডের মধ্যে পরবর্তী শিডিউল অ্যালার্ম পরীক্ষা সম্পন্ন হবে।',
          details,
        );
      } catch (e) {
        debugPrint('[TestNotification] Detailed show failed ($e), retrying with basic fallback...');
        const fallbackDetails = NotificationDetails(
          android: AndroidNotificationDetails(
            _IDs.adhkarChannelId,
            'Adhkar Reminders',
            importance: Importance.max,
            priority: Priority.max,
            icon: 'ic_stat_notification',
          ),
        );
        await _local.show(
          999,
          '☪️ Adhkaar 365 — টেস্ট নোটিফিকেশন সফল',
          'ইনস্ট্যান্ট নোটিফিকেশন সফল! ১০ সেকেন্ডের মধ্যে পরবর্তী শিডিউল অ্যালার্ম পরীক্ষা সম্পন্ন হবে।',
          fallbackDetails,
        );
      }

      // 2. Scheduled notification 10 seconds from now — proves the alarm scheduler works
      await _scheduleLocalNotification(
        id: 998,
        title: '⏰ Adhkaar 365 — শিডিউল অ্যালার্ম সফল!',
        body: 'আলহামদুলিল্লাহ! শিডিউল অ্যালার্ম সফলভাবে কাজ করেছে। নামাজের ওয়াক্তে সময়মতো নোটিফিকেশন আসবে ইনশাআল্লাহ।',
        scheduledTime: DateTime.now().add(const Duration(seconds: 10)),
        channelId: _IDs.adhkarChannelId,
        channelName: 'Adhkar Reminders',
        payload: 'test',
        sound: null,
        subText: 'Schedule Test',
      );

      debugPrint('[Test] Instant sent. Scheduled test fires in 10 seconds.');
      return true;
    } catch (e) {
      debugPrint('[TestNotification] Failed completely: $e');
      return false;
    }
  }
}

// ── Helper data class ──────────────────────────────────────────────────────────
class _PrayerConfig {
  final String name;
  final int baseId;
  final String title;
  final String body;
  const _PrayerConfig(this.name, this.baseId, this.title, this.body);
}

class _NotifText {
  final String title;
  final String body;
  const _NotifText(this.title, this.body);
}

class _NotificationLocale {
  static _NotifText getPrayer(String name, String lang) {
    if (lang == 'bn') {
      switch (name) {
        case 'Fajr':
          return const _NotifText('ফজর নামাজ • الفجر 🌄', 'ফজরের ওয়াক্ত হয়েছে — "নামাজ ঘুমের চেয়ে উত্তম"');
        case 'Sunrise':
          return const _NotifText('সূর্যোদয় • الشروق 🌅', 'সূর্য উদিত হয়েছে — নতুন দিনের সূচনা। সকালের আযকার বাকি থাকলে সম্পন্ন করে নিন।');
        case 'Dhuhr':
          return const _NotifText('যোহর নামাজ • الظهر ☀️', 'দুপুরের নামাজের ওয়াক্ত হয়েছে — আল্লাহর সন্তুষ্টিতে নামাজ আদায় করুন।');
        case 'Asr':
          return const _NotifText('আসর নামাজ • العصر 🌤', 'আসরের ওয়াক্ত হয়েছে — "সময়ের শপথ! নিশ্চয়ই মানুষ ক্ষতিগ্রস্ত।"');
        case 'Maghrib':
          return const _NotifText('মাগরিব নামাজ • المغرب 🌇', 'সূর্যাস্ত হয়েছে — মাগরিব নামাজ আদায় করুন। সন্ধ্যার আযকার বাকি থাকলে পড়ে নিন।');
        case 'Isha':
          return const _NotifText('ইশা নামাজ • العشاء 🌙', 'রাতের আগমন — ইশার নামাজ আদায় করে দিনটি আল্লাহর স্মরণে সমাপ্ত করুন।');
      }
    } else if (lang == 'ar') {
      switch (name) {
        case 'Fajr':
          return const _NotifText('صلاة الفجر • الفجر 🌄', 'الصلاة خير من النوم — قوموا إلى صلاة الفجر.');
        case 'Sunrise':
          return const _NotifText('الشروق • الشروق 🌅', 'أشرقت الشمس — بداية يوم جديد. أتمم أذكار الصباح إن لم تكن قرأتها.');
        case 'Dhuhr':
          return const _NotifText('صلاة الظهر • الظهر ☀️', 'حان وقت صلاة الظهر — أقم الصلاة لذكر الله.');
        case 'Asr':
          return const _NotifText('صلاة العصر • العصر 🌤', 'حان وقت صلاة العصر — حافظوا على الصلوات والصلاة الوسطى.');
        case 'Maghrib':
          return const _NotifText('صلاة المغرب • المغرب 🌇', 'غربت الشمس — صلِّ المغرب وأتمم أذكار المساء إن لم تكن قرأتها.');
        case 'Isha':
          return const _NotifText('صلاة العشاء • العشاء 🌙', 'حان وقت صلاة العشاء — اختم يومك بذكر الله.');
      }
    } else if (lang == 'id' || lang == 'ms') {
      switch (name) {
        case 'Fajr':
          return const _NotifText('Salat Subuh • الفجر 🌄', 'As-shalatu khairum minan naum — Mari tunaikan salat Subuh.');
        case 'Sunrise':
          return const _NotifText('Syuruq • الشروق 🌅', 'Matahari telah terbit — awal hari baru. Selesaikan zikir pagi jika belum.');
        case 'Dhuhr':
          return const _NotifText('Salat Zuhur • الظهر ☀️', 'Waktu Zuhur telah tiba — luangkan waktu menghadap Allah.');
        case 'Asr':
          return const _NotifText('Salat Asar • العصر 🌤', 'Waktu Asar telah tiba — tunaikan salat.');
        case 'Maghrib':
          return const _NotifText('Salat Magrib • المغرب 🌇', 'Matahari telah terbenam — tunaikan salat Magrib dan selesaikan zikir petang.');
        case 'Isha':
          return const _NotifText('Salat Isya • العشاء 🌙', 'Malam telah tiba — akhiri harimu dengan mengingat Allah.');
      }
    } else if (lang == 'tr') {
      switch (name) {
        case 'Fajr':
          return const _NotifText('Sabah Namazı • الفجر 🌄', 'Namaz uykudan hayırlıdır — Haydin sabah namazına.');
        case 'Sunrise':
          return const _NotifText('Güneş Doğuşu • الشروق 🌅', 'Güneş doğdu — yeni bir gün başladı. Kalan sabah zikirlerinizi tamamlayın.');
        case 'Dhuhr':
          return const _NotifText('Öğle Namazı • الظهر ☀️', 'Öğle namazı vakti girdi — Allah\'ın huzuruna durma zamanı.');
        case 'Asr':
          return const _NotifText('İkindi Namazı • العصر 🌤', 'İkindi vakti girdi — namazınızı eda edin.');
        case 'Maghrib':
          return const _NotifText('Akşam Namazı • المغرب 🌇', 'Güneş battı — akşam namazını kılın ve kalan akşam zikirlerinizi okuyun.');
        case 'Isha':
          return const _NotifText('Yatsı Namazı • العشاء 🌙', 'Gece geldi — gününüzü Allah\'ı anarak tamamlayın.');
      }
    } else if (lang == 'ur') {
      switch (name) {
        case 'Fajr':
          return const _NotifText('نماز فجر • الفجر 🌄', 'الصلٰوۃ خیر من النوم — نماز نیند سے بہتر ہے۔');
        case 'Sunrise':
          return const _NotifText('طلوع آفتاب • الشروق 🌅', 'سورج طلوع ہو چکا ہے — نئے دن کا آغاز۔ اگر صبح کے اذکار باقی ہیں تو مکمل کر لیں۔');
        case 'Dhuhr':
          return const _NotifText('نماز ظہر • الظهر ☀️', 'ظہر کا وقت ہو چکا ہے — اللہ کے حضور سجدہ ریز ہوں۔');
        case 'Asr':
          return const _NotifText('نماز عصر • العصر 🌤', 'عصر کا وقت شروع ہو چکا ہے — نماز ادا کریں۔');
        case 'Maghrib':
          return const _NotifText('نماز مغرب • المغرب 🌇', 'غروب آفتاب ہو چکا ہے — نماز مغرب ادا کریں اور شام کے اذکار مکمل کریں۔');
        case 'Isha':
          return const _NotifText('نماز عشاء • العشاء 🌙', 'রাত ہو چکی ہے — اپنے دن کا اختتام اللہ کے ذکر کے ساتھ کریں۔');
      }
    }
    // Default English
    switch (name) {
      case 'Fajr':
        return const _NotifText('Fajr Prayer • الفجر 🌄', 'Rise and pray Fajr — "Prayer is better than sleep."');
      case 'Sunrise':
        return const _NotifText('Sunrise • الشروق 🌅', 'The sun has risen — a new day begins. Complete any remaining morning adhkar.');
      case 'Dhuhr':
        return const _NotifText('Dhuhr Prayer • الظهر ☀️', 'Midday prayer time. Take a moment to stand before Allah.');
      case 'Asr':
        return const _NotifText('Asr Prayer • العصر 🌤', 'Asr time has begun. "By time, indeed, mankind is in loss."');
      case 'Maghrib':
        return const _NotifText('Maghrib Prayer • المغرب 🌇', 'Sunset — pray Maghrib and complete your evening adhkar if remaining.');
      case 'Isha':
        return const _NotifText('Isha Prayer • العشاء 🌙', 'Night has come. End your day in the remembrance of Allah.');
      default:
        return _NotifText('$name Prayer', 'Time to pray $name.');
    }
  }
}
