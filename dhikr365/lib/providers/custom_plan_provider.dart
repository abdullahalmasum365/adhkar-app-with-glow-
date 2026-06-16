import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomPlanProvider extends ChangeNotifier {
  Set<String> _enabledDhikrIds = {};
  bool _useCustomPlan = false;

  Set<String> get enabledDhikrIds => _enabledDhikrIds;
  bool get useCustomPlan => _useCustomPlan;

  CustomPlanProvider() { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _useCustomPlan   = prefs.getBool('use_custom_plan') ?? false;
    final saved      = prefs.getStringList('enabled_dhikr_ids') ?? [];
    _enabledDhikrIds = saved.toSet();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_custom_plan', _useCustomPlan);
    await prefs.setStringList('enabled_dhikr_ids', _enabledDhikrIds.toList());
  }

  void setUseCustomPlan(bool value) {
    _useCustomPlan = value;
    _save();
    notifyListeners();
  }

  // FIX: accepts optional [forceTo] bool so CustomizePlanScreen
  // can explicitly set enabled/disabled without toggling blindly.
  void toggleDhikr(String id, [bool? forceTo]) {
    if (forceTo != null) {
      forceTo ? _enabledDhikrIds.add(id) : _enabledDhikrIds.remove(id);
    } else {
      _enabledDhikrIds.contains(id)
          ? _enabledDhikrIds.remove(id)
          : _enabledDhikrIds.add(id);
    }
    _save();
    notifyListeners();
  }

  bool isDhikrEnabled(String id) {
    if (!_useCustomPlan) return true;
    return _enabledDhikrIds.contains(id);
  }
}
