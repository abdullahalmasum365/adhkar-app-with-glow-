import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adhan/adhan.dart';
import '../models/sadaqah_dedication.dart';
import '../utils/prayer_calculation_helper.dart';
import 'purchase_provider.dart';

class UserProvider extends ChangeNotifier {
  String? _userName;
  String _madhab = 'shafii';
  CalculationMethod _calculationMethod = CalculationMethod.muslim_world_league;
  String? _city;
  String? _country;
  double? _lat;
  double? _lng;
  String? _timezone; // IANA name of the SELECTED location (e.g. "Asia/Dhaka")
  bool _hasDonated = false;
  String? _dedicationType;
  String? _dedicationRecipient;
  String? _dedicationTier;
  DateTime? _dedicationDate;
  bool _hasCompletedOnboarding = false;
  String? _onboardingGoal;
  String? _preferredDhikrTime;

  String? get userName => _userName;
  String get madhab => _madhab;
  CalculationMethod get calculationMethod => _calculationMethod;
  String? get city => _city;
  String? get country => _country;
  double? get lat => _lat;
  double? get lng => _lng;
  String? get timezone => _timezone;
  bool get hasDonated => _hasDonated;

  /// Returns true if user has donated or has active subscription sponsorship
  bool isMuhsin(PurchaseProvider pp) => pp.hasActiveDonation || _hasDonated;

  SadaqahDedication get savedDedication {
    DedicationType type = DedicationType.parents;
    if (_dedicationType != null) {
      try {
        type = DedicationType.values.firstWhere(
          (e) => e.name == _dedicationType,
          orElse: () => DedicationType.parents,
        );
      } catch (_) {}
    }
    return SadaqahDedication(
      type: type,
      recipientName: _dedicationRecipient,
      timestamp: _dedicationDate ?? DateTime.now(),
    );
  }

  String get savedTierName => _dedicationTier ?? 'Sadaqah Jariyah';

  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  String? get onboardingGoal => _onboardingGoal;
  String? get preferredDhikrTime => _preferredDhikrTime;

  bool get hasSavedCoordinates => _lat != null && _lng != null;

  UserProvider() {
    _load();
  }

  final _loadCompleter = Completer<void>();
  Future<void> get loadFuture => _loadCompleter.future;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userName = prefs.getString('user_name') ?? '';
      _madhab = prefs.getString('madhab') ?? 'shafii';
      final methodStr = prefs.getString('calc_method');
      if (methodStr != null) {
        _calculationMethod = CalculationMethod.values.firstWhere(
          (e) => e.name == methodStr,
          orElse: () => CalculationMethod.muslim_world_league,
        );
      }
      _city = prefs.getString('city') ?? '';
      _country = prefs.getString('country') ?? '';
      final latStr = prefs.getString('saved_lat');
      final lngStr = prefs.getString('saved_lng');
      _lat = latStr != null ? double.tryParse(latStr) : null;
      _lng = lngStr != null ? double.tryParse(lngStr) : null;
      _timezone = prefs.getString('saved_timezone');
      _hasDonated = prefs.getBool('has_donated') ?? false;
      _dedicationType = prefs.getString('dedication_type');
      _dedicationRecipient = prefs.getString('dedication_recipient');
      final dedMs = prefs.getInt('dedication_timestamp');
      if (dedMs != null) {
        _dedicationDate = DateTime.fromMillisecondsSinceEpoch(dedMs);
      }
      _dedicationTier = prefs.getString('dedication_tier');
      _hasCompletedOnboarding = prefs.getBool('onboarding_done') ?? false;
      _onboardingGoal = prefs.getString('onboarding_goal');
      _preferredDhikrTime = prefs.getString('preferred_dhikr_time');
    } catch (_) {
      // Unexpected error — proceed with defaults so the app isn't stuck.
    } finally {
      if (!_loadCompleter.isCompleted) _loadCompleter.complete();
      notifyListeners();
    }
  }

  Future<void> updateProfile({required String name}) async {
    _userName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    notifyListeners();
  }

  Future<void> setUserName(String name) async {
    _userName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    notifyListeners();
  }

  Future<void> setMadhab(String madhab) async {
    _madhab = madhab;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('madhab', madhab);
    notifyListeners();
  }

  Future<void> setLocation(String city, String country) async {
    _city = city;
    _country = country;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('city', city);
    await prefs.setString('country', country);

    // Auto-detect calculation method based on country if not explicitly set.
    if (!prefs.containsKey('calc_method')) {
      _calculationMethod = getMethodForCountry(country);
      await prefs.setString('calc_method', _calculationMethod.name);
    }

    notifyListeners();
  }

  Future<void> setCalculationMethod(CalculationMethod method) async {
    _calculationMethod = method;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('calc_method', method.name);
    notifyListeners();
  }

  Future<void> setCoordinates(double lat, double lng) async {
    _lat = lat;
    _lng = lng;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_lat', lat.toString());
    await prefs.setString('saved_lng', lng.toString());
    notifyListeners();
  }

  /// IANA timezone of the selected location. Set from the city database on
  /// manual selection, or from the device timezone when GPS is used.
  Future<void> setTimezone(String tz) async {
    _timezone = tz;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_timezone', tz);
    notifyListeners();
  }

  Future<void> clearCoordinates() async {
    _lat = null;
    _lng = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_lat');
    await prefs.remove('saved_lng');
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    _hasCompletedOnboarding = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    notifyListeners();
  }

  Future<void> setOnboardingGoal(String goal) async {
    _onboardingGoal = goal;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('onboarding_goal', goal);
    notifyListeners();
  }

  Future<void> setPreferredDhikrTime(String time) async {
    _preferredDhikrTime = time;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('preferred_dhikr_time', time);
    notifyListeners();
  }

  /// Clears only the user's display name. Used from the profile screen.
  Future<void> resetProfile() async {
    _userName = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_name');
    notifyListeners();
  }

  Future<void> setDonated(bool value) async {
    _hasDonated = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_donated', value);
    notifyListeners();
  }

  Future<void> saveSadaqahDedication({
    required SadaqahDedication dedication,
    required String tierName,
  }) async {
    _hasDonated = true;
    _dedicationType = dedication.type.name;
    _dedicationRecipient = dedication.recipientName;
    _dedicationDate = dedication.timestamp;
    _dedicationTier = tierName;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_donated', true);
    await prefs.setString('dedication_type', dedication.type.name);
    if (dedication.recipientName != null && dedication.recipientName!.isNotEmpty) {
      await prefs.setString('dedication_recipient', dedication.recipientName!);
    } else {
      await prefs.remove('dedication_recipient');
    }
    await prefs.setInt('dedication_timestamp', dedication.timestamp.millisecondsSinceEpoch);
    await prefs.setString('dedication_tier', tierName);
    notifyListeners();
  }
}
