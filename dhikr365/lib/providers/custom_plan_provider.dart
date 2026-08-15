import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The user's custom dua plan (which dhikrs are enabled) and favorites.
/// Always readable/writable locally (SharedPreferences) so the app works
/// fully offline and for users who never sign in. When a Firebase account
/// is signed in (see AuthProvider), the same data is also mirrored to
/// Cloud Firestore under users/{uid}/plan/data — so signing in on a new
/// phone restores the exact same plan instead of starting from empty.
class CustomPlanProvider extends ChangeNotifier {
  Set<String> _enabledDhikrIds = {};
  bool _useCustomPlan = false;
  String? _uid;

  Set<String> get enabledDhikrIds => _enabledDhikrIds;
  bool get useCustomPlan => _useCustomPlan;
  bool get isSyncing => _uid != null;

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
    if (_uid != null) unawaited(_pushToCloud());
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

  // ── Cloud sync ────────────────────────────────────────────────────────

  DocumentReference<Map<String, dynamic>>? get _cloudDoc {
    if (_uid == null || Firebase.apps.isEmpty) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('plan')
        .doc('data');
  }

  /// Called whenever the signed-in account changes (AuthProvider listener
  /// wired in main.dart). Merges cloud + local so neither side's edits are
  /// silently dropped, then keeps both in sync going forward. Passing null
  /// (sign-out) just stops pushing further changes — local data is kept.
  Future<void> attachUser(String? uid) async {
    if (uid == _uid) return; // no-op: already synced to this account/state
    _uid = uid;
    if (uid == null || Firebase.apps.isEmpty) return;

    try {
      final doc = _cloudDoc;
      if (doc == null) return;
      final snap = await doc.get();

      if (snap.exists) {
        final data = snap.data()!;
        final cloudIds = (data['enabledDhikrIds'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toSet();
        final cloudUseCustom = data['useCustomPlan'] as bool?;

        // Union of local + cloud so an edit made offline on this device
        // right before signing in is never silently lost.
        _enabledDhikrIds = _enabledDhikrIds.union(cloudIds);
        _useCustomPlan = cloudUseCustom ?? _useCustomPlan;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('use_custom_plan', _useCustomPlan);
        await prefs.setStringList(
            'enabled_dhikr_ids', _enabledDhikrIds.toList());
        notifyListeners();
      }

      // Push the merged result so the cloud doc reflects it too.
      await _pushToCloud();
    } catch (e) {
      debugPrint('[CustomPlanProvider] cloud sync on sign-in failed: $e');
    }
  }

  Future<void> _pushToCloud() async {
    final doc = _cloudDoc;
    if (doc == null) return;
    try {
      await doc.set({
        'enabledDhikrIds': _enabledDhikrIds.toList(),
        'useCustomPlan': _useCustomPlan,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[CustomPlanProvider] cloud push failed: $e');
    }
  }
}
