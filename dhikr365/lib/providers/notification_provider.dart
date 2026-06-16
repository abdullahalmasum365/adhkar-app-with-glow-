// ============================================================================
// lib/providers/notification_provider.dart
//
// Bridge between SettingsScreen toggles and NotificationService calls.
// All state is persisted in SharedPreferences.
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';
import 'user_provider.dart';

class NotificationProvider extends ChangeNotifier {
  // ── Toggle state ──────────────────────────────────────────────────────────
  bool _morningEnabled       = true;
  bool _eveningEnabled       = true;
  bool _specialTimesEnabled  = true;
  bool _prayerAlertsEnabled  = true;

  // Individual prayer toggles
  bool _fajrEnabled    = true;
  bool _sunriseEnabled = true;
  bool _dhuhrEnabled   = true;
  bool _asrEnabled     = true;
  bool _maghribEnabled = true;
  bool _ishaEnabled    = true;

  // ── Getters ───────────────────────────────────────────────────────────────
  bool get morningEnabled      => _morningEnabled;
  bool get eveningEnabled      => _eveningEnabled;
  bool get specialTimesEnabled => _specialTimesEnabled;
  bool get prayerAlertsEnabled => _prayerAlertsEnabled;

  bool get fajrEnabled    => _fajrEnabled;
  bool get sunriseEnabled => _sunriseEnabled;
  bool get dhuhrEnabled   => _dhuhrEnabled;
  bool get asrEnabled     => _asrEnabled;
  bool get maghribEnabled => _maghribEnabled;
  bool get ishaEnabled    => _ishaEnabled;

  // ── Constructor ───────────────────────────────────────────────────────────
  NotificationProvider() {
    _loadSettings();
  }

  final _loadCompleter = Completer<void>();
  Future<void> get loadFuture => _loadCompleter.future;

  // ── Persistence ───────────────────────────────────────────────────────────
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _morningEnabled      = prefs.getBool('notif_morning')        ?? true;
    _eveningEnabled      = prefs.getBool('notif_evening')        ?? true;
    _specialTimesEnabled = prefs.getBool('notif_special')        ?? true;
    _prayerAlertsEnabled = prefs.getBool('notif_prayer_alerts')  ?? true;

    _fajrEnabled    = prefs.getBool('notif_fajr')    ?? true;
    _sunriseEnabled = prefs.getBool('notif_sunrise') ?? true;
    _dhuhrEnabled   = prefs.getBool('notif_dhuhr')   ?? true;
    _asrEnabled     = prefs.getBool('notif_asr')     ?? true;
    _maghribEnabled = prefs.getBool('notif_maghrib') ?? true;
    _ishaEnabled    = prefs.getBool('notif_isha')    ?? true;

    _loadCompleter.complete();
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_morning',       _morningEnabled);
    await prefs.setBool('notif_evening',       _eveningEnabled);
    await prefs.setBool('notif_special',       _specialTimesEnabled);
    await prefs.setBool('notif_prayer_alerts', _prayerAlertsEnabled);

    await prefs.setBool('notif_fajr',    _fajrEnabled);
    await prefs.setBool('notif_sunrise', _sunriseEnabled);
    await prefs.setBool('notif_dhuhr',   _dhuhrEnabled);
    await prefs.setBool('notif_asr',     _asrEnabled);
    await prefs.setBool('notif_maghrib', _maghribEnabled);
    await prefs.setBool('notif_isha',    _ishaEnabled);
  }

  // ── Public toggles — called directly from SettingsScreen ─────────────────

  Future<void> toggleMorning(bool value, UserProvider up) async {
    _morningEnabled = value;
    await _saveSettings();
    notifyListeners();
    if (value) {
      // Re-schedule morning only if we have coordinates
      if (up.hasSavedCoordinates) {
        await NotificationService()
            .scheduleAdhkarReminders(up.lat!, up.lng!, 
              calculationMethod: up.calculationMethod,
              madhab: up.madhab,
            );
        // If evening is off, cancel it again after bulk schedule
        if (!_eveningEnabled) {
          await NotificationService().cancelEveningNotification();
        }
      }
    } else {
      await NotificationService().cancelMorningNotification();
    }
  }

  Future<void> toggleEvening(bool value, UserProvider up) async {
    _eveningEnabled = value;
    await _saveSettings();
    notifyListeners();
    if (value) {
      if (up.hasSavedCoordinates) {
        await NotificationService()
            .scheduleAdhkarReminders(up.lat!, up.lng!,
              calculationMethod: up.calculationMethod,
              madhab: up.madhab,
            );
        if (!_morningEnabled) {
          await NotificationService().cancelMorningNotification();
        }
      }
    } else {
      await NotificationService().cancelEveningNotification();
    }
  }

  Future<void> toggleSpecialTimes(bool value) async {
    _specialTimesEnabled = value;
    await _saveSettings();
    notifyListeners();
    // Special times (e.g. last third of night) — extend here as needed
  }

  Future<void> togglePrayerAlerts(bool value, UserProvider up) async {
    _prayerAlertsEnabled = value;
    await _saveSettings();
    notifyListeners();
    if (value) {
      await _schedulePrayerAlertsIfReady(up);
    } else {
      await NotificationService().cancelAllPrayerNotifications();
    }
  }

  Future<void> toggleSpecificPrayer(
    String prayerName,
    bool value,
    UserProvider up,
  ) async {
    switch (prayerName) {
      case 'Fajr':    _fajrEnabled    = value; break;
      case 'Sunrise': _sunriseEnabled = value; break;
      case 'Dhuhr':   _dhuhrEnabled   = value; break;
      case 'Asr':     _asrEnabled     = value; break;
      case 'Maghrib': _maghribEnabled = value; break;
      case 'Isha':    _ishaEnabled    = value; break;
    }
    await _saveSettings();
    notifyListeners();

    if (value) {
      // Re-schedule everything so the newly enabled prayer is included
      await _schedulePrayerAlertsIfReady(up);
    } else {
      // Cancel just this prayer — more efficient than cancelling all
      await NotificationService().cancelSpecificPrayer(prayerName);
    }
  }

  bool isPrayerEnabled(String prayerName) {
    switch (prayerName) {
      case 'Fajr':    return _fajrEnabled;
      case 'Sunrise': return _sunriseEnabled;
      case 'Dhuhr':   return _dhuhrEnabled;
      case 'Asr':     return _asrEnabled;
      case 'Maghrib': return _maghribEnabled;
      case 'Isha':    return _ishaEnabled;
      default:        return true;
    }
  }

  // ── Called from SplashScreen on every cold start ──────────────────────────
  /// Refreshes all scheduled notifications based on current settings.
  /// Call this whenever location changes or app restarts.
  Future<void> refreshAllSchedules(UserProvider up) async {
    if (!up.hasSavedCoordinates) return;

    final svc = NotificationService();

    // Clear everything first to avoid duplicates
    await svc.cancelMorningNotification();
    await svc.cancelEveningNotification();
    await svc.cancelAllPrayerNotifications();

    // Adhkar reminders
    if (_morningEnabled || _eveningEnabled) {
      await svc.scheduleAdhkarReminders(up.lat!, up.lng!,
        calculationMethod: up.calculationMethod,
        madhab: up.madhab,
      );
      if (!_morningEnabled) await svc.cancelMorningNotification();
      if (!_eveningEnabled) await svc.cancelEveningNotification();
    }

    // Prayer alerts
    if (_prayerAlertsEnabled) {
      await _schedulePrayerAlertsIfReady(up);
    }
  }

  // ── Private helper ────────────────────────────────────────────────────────
  Future<void> _schedulePrayerAlertsIfReady(UserProvider up) async {
    if (!up.hasSavedCoordinates) return;
    await NotificationService().schedulePrayerTimes(
      up.lat!,
      up.lng!,
      enabledPrayers: {
        'Fajr'    : _fajrEnabled,
        'Sunrise' : _sunriseEnabled,
        'Dhuhr'   : _dhuhrEnabled,
        'Asr'     : _asrEnabled,
        'Maghrib' : _maghribEnabled,
        'Isha'    : _ishaEnabled,
      },
      calculationMethod: up.calculationMethod,
      madhab: up.madhab,
    );
  }
}
