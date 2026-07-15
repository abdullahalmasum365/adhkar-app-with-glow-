import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adhan/adhan.dart';
import '../utils/prayer_calculation_helper.dart';

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
  bool _hasCompletedOnboarding = false;

  String? get userName => _userName;
  String get madhab => _madhab;
  CalculationMethod get calculationMethod => _calculationMethod;
  String? get city => _city;
  String? get country => _country;
  double? get lat => _lat;
  double? get lng => _lng;
  String? get timezone => _timezone;
  bool get hasDonated => _hasDonated;
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;

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
      _hasCompletedOnboarding = prefs.getBool('onboarding_done') ?? false;
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
}
