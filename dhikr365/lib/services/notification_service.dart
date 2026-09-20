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

import '../constants/app_theme.dart';
import '../models/dhikr.dart';
import '../screens/dhikr_list_screen.dart';
import '../utils/app_navigator.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Notification ID Registry
// Keep these stable — changing IDs breaks existing scheduled notifications.
// ─────────────────────────────────────────────────────────────────────────────
class _IDs {
  // Adhkar reminders
  static const int morning = 1000; // 1000–1009
  static const int evening = 1100; // 1100–1109, safe gap

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
    // '@drawable/ic_stat_notification' is a monochrome white crescent/star.
    // Android 5+ REQUIRES status-bar icons to be white-only — a full-colour
    // launcher icon renders as a white rectangle blob. This dedicated white
    // drawable is the correct approach used by Muslim Pro and all major apps.
    const android = AndroidInitializationSettings('@drawable/ic_stat_notification');

    // ── iOS / macOS settings ──
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(android: android, iOS: darwin);

    await _local.initialize(
      settings,
      // Called when user taps a local notification while app is open
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
      // Called when user taps a background notification (Android)
      onDidReceiveBackgroundNotificationResponse:
          _onBackgroundLocalNotificationTap,
    );

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
    debugPrint('[Local] Tapped: id=${response.id}, payload=$payload');
    _routeForPayload(payload);
  }

  // ── Notification tap handler (background) — must be top-level ─────────────
  @pragma('vm:entry-point')
  static void _onBackgroundLocalNotificationTap(NotificationResponse response) {
    final payload = response.payload ?? '';
    debugPrint('[Local BG] Tapped: id=${response.id}, payload=$payload');
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
    }
    // Other prayer alerts (Dhuhr, Isha) just bring the app to foreground —
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
  }) async {
    // Cancel existing before rescheduling to avoid duplicates
    await cancelMorningNotification();
    await cancelEveningNotification();

    final coords = Coordinates(lat, lng);
    final params = calculationMethod.getParameters()
      ..madhab =
          madhab.toLowerCase() == 'hanafi' ? Madhab.hanafi : Madhab.shafi;

    for (int i = 0; i < daysAhead; i++) {
      final day = DateTime.now().add(Duration(days: i));
      final dateComp = DateComponents.from(day);
      final times = PrayerTimes(coords, dateComp, params);

      // Morning adhkar starts at Fajr — the prescribed time begins at dawn.
      // Evening adhkar starts at Asr — scholars agree the evening period
      // begins from Asr until sunset.
      final fajr = times.fajr.toLocal();
      final asr  = times.asr.toLocal();

      // Only schedule future times (skip if already passed today)
      final now = DateTime.now();
      if (fajr.isAfter(now)) {
        await _scheduleLocalNotification(
          id: _IDs.morning + i, // 1000–1009
          title: '🌄 أذكار الصباح • Morning Adhkar',
          body: 'Fajr has begun — read your morning adhkar now. '
              '"وَسَبِّحْ بِحَمْدِ رَبِّكَ قَبْلَ طُلُوعِ الشَّمْسِ"',
          scheduledTime: fajr,
          channelId: _IDs.adhkarChannelId,
          channelName: 'Adhkar Reminders',
          payload: 'morning',
          sound: null,
          subText: 'Morning Adhkar',
        );
      }

      if (asr.isAfter(now)) {
        await _scheduleLocalNotification(
          id: _IDs.evening + i, // 1100–1109
          title: '🌆 أذكار المساء • Evening Adhkar',
          body: 'Asr time — the evening adhkar period has begun. '
              '"وَسَبِّحْ بِحَمْدِهِ قَبْلَ غُرُوبِهَا"',
          scheduledTime: asr,
          channelId: _IDs.adhkarChannelId,
          channelName: 'Adhkar Reminders',
          payload: 'evening',
          sound: null,
          subText: 'Evening Adhkar',
        );
      }
    }

    debugPrint('[Scheduler] Adhkar reminders scheduled for $daysAhead days');
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
  }) async {
    await cancelAllPrayerNotifications();

    final coords = Coordinates(lat, lng);
    final params = calculationMethod.getParameters()
      ..madhab =
          madhab.toLowerCase() == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
    final now = DateTime.now();

    final prayerConfig = [
      const _PrayerConfig('Fajr', _IDs.fajrBase,
          '🌄 الفجر • Fajr Prayer',
          'Rise and pray Fajr — "الصَّلَاةُ خَيْرٌ مِنَ النَّوْمِ" Prayer is better than sleep.'),
      const _PrayerConfig('Sunrise', _IDs.sunriseBase,
          '🌅 الشروق • Sunrise',
          'The sun has risen. Open Adhkaar 365 for your morning supplications.'),
      const _PrayerConfig('Dhuhr', _IDs.dhuhrBase,
          '☀️ الظهر • Dhuhr Prayer',
          'Midday prayer time. Take a moment to stand before Allah.'),
      const _PrayerConfig('Asr', _IDs.asrBase,
          '🌤 العصر • Asr Prayer',
          'Asr time has begun. "وَالْعَصْرِ ۙ إِنَّ الْإِنسَانَ لَفِي خُسْرٍ"'),
      const _PrayerConfig('Maghrib', _IDs.maghribBase,
          '🌇 المغرب • Maghrib Prayer',
          'Sunset — pray Maghrib and open your evening adhkar.'),
      const _PrayerConfig('Isha', _IDs.ishaBase,
          '🌙 العشاء • Isha Prayer',
          'Night has come. End your day in the remembrance of Allah.'),
    ];

    for (int i = 0; i < daysAhead; i++) {
      final day = now.add(Duration(days: i));
      final dateComp = DateComponents.from(day);
      final times = PrayerTimes(coords, dateComp, params);

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
            subText: 'Prayer Time',
          );
        }
      }
    }

    debugPrint('[Scheduler] Prayer times scheduled for $daysAhead days');
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
  }) async {
    // Convert to TZDateTime — required by flutter_local_notifications
    final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.max,
      priority: Priority.max,
      // Status-bar small icon MUST be monochrome white (Android 5+ rule).
      // Full-colour launcher icons appear as a grey blob on the status bar.
      icon: '@drawable/ic_stat_notification',
      // Full-colour app logo shown on the RIGHT side of the notification panel —
      // this is the "large icon" slot which DOES accept colour. Makes the
      // notification instantly recognisable as Adhkaar 365.
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
      // Small category label in the notification header (next to app name),
      // e.g. "Prayer Time" / "Adhkar Reminder".
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
        summaryText: 'Adhkaar 365 ☪',
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

    // Standard Android alarm mode used by top prayer apps (Muslim Pro / Pillars).
    // exactAllowWhileIdle fires precisely even when the device is in deep Doze / locked.
    // If not granted, falls back to inexactAllowWhileIdle.
    AndroidScheduleMode scheduleMode;
    if (Platform.isAndroid) {
      final canExact = await isExactAlarmGranted();
      lastScheduleUsedExact = canExact;
      scheduleMode = canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
    } else {
      scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
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
      // If exact scheduling fails for ANY reason (permission revoked, OEM security policy, etc.),
      // fall back to inexactAllowWhileIdle so the user never loses the reminder.
      if (scheduleMode != AndroidScheduleMode.inexactAllowWhileIdle) {
        _cachedCanExact = false;
        lastScheduleUsedExact = false;
        try {
          await doSchedule(AndroidScheduleMode.inexactAllowWhileIdle);
          debugPrint('[Scheduler] OK id=$id "$title" (fallback inexactAllowWhileIdle)');
        } catch (e2) {
          debugPrint('[Scheduler] FAILED id=$id "$title": $e2');
        }
      } else {
        debugPrint('[Scheduler] FAILED id=$id "$title": $e');
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
  Future<void> showInstantTestNotification() async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _IDs.adhkarChannelId,
        'Adhkar Reminders',
        importance: Importance.max,
        priority: Priority.max,
        icon: '@drawable/ic_stat_notification',
        largeIcon:
            const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
        subText: 'Test',
        playSound: true,
        enableVibration: true,
        color: AppColors.primary,
        styleInformation: const BigTextStyleInformation(
          'ইনস্ট্যান্ট নোটিফিকেশন সফল! ১০ সেকেন্ডের মধ্যে পরবর্তী শিডিউল অ্যালার্ম পরীক্ষা সম্পন্ন হবে।\nInstant delivery works! Checking 10-second scheduled alarm…',
          contentTitle: '☪️ Adhkaar 365 — টেস্ট নোটিফিকেশন সফল',
          summaryText: 'Adhkaar 365 ☪',
        ),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    // 1. Instant notification
    await _local.show(
      999,
      '☪️ Adhkaar 365 — টেস্ট নোটিফিকেশন সফল',
      'ইনস্ট্যান্ট নোটিফিকেশন সফল! ১০ সেকেন্ডের মধ্যে পরবর্তী শিডিউল অ্যালার্ম পরীক্ষা সম্পন্ন হবে।',
      details,
    );

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
