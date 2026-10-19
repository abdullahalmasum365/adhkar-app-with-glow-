// ============================================================================
// lib/services/dua_correction_service.dart
//
// Enables Over-The-Air (OTA) corrections for any Dhikr / Dua text without
// requiring an app update on the Google Play Store.
//
// How it works:
// 1. App loads base dhikrs 100% offline from bundled JSON assets.
// 2. Applies any previously cached corrections instantly from SharedPreferences.
// 3. In the background (non-blocking, throttled to max once every 12 hours),
//    queries Firestore collection 'dua_corrections'.
// 4. If any correction exists (e.g. for typo in Arabic, translation, or reference),
//    it caches it locally and hot-patches the in-memory dhikr list.
//
// Zero-cost & Crash-proof:
// - Uses 0 Firestore reads if offline or throttled.
// - When collection is empty, costs 0 reads.
// - If Firebase is unreachable or misconfigured, fails silently to local assets.
// ============================================================================

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/dhikr.dart';

class DuaCorrectionService {
  static const String _prefCacheKey = 'cached_dua_corrections';
  static const String _prefTimestampKey = 'last_dua_correction_fetch';
  static const Duration _fetchInterval = Duration(hours: 12);

  DuaCorrectionService._();

  /// Loads locally cached corrections from [SharedPreferences] (fast & offline).
  static Map<String, Map<String, dynamic>> getCachedCorrections(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(_prefCacheKey);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return {};

      final Map<String, Map<String, dynamic>> result = {};
      decoded.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          result[key] = value;
        }
      });
      return result;
    } catch (e) {
      debugPrint('[DuaCorrectionService] Error reading cached corrections: $e');
      return {};
    }
  }

  /// Applies [corrections] to [dhikrs] for the active [langCode].
  /// Does NOT modify the original list in-place; returns a newly patched list.
  static List<Dhikr> applyCorrections(
    List<Dhikr> dhikrs,
    Map<String, Map<String, dynamic>> corrections, {
    required String langCode,
  }) {
    if (corrections.isEmpty) return dhikrs;

    return dhikrs.map((d) {
      final patch = corrections[d.id];
      if (patch == null || patch.isEmpty) return d;

      String? newArabic;
      String? newTitle;
      String? newTranslation;
      String? newTransliteration;
      String? newReference;
      String? newBenefit;

      // 1. Arabic text override (with harakat / full tajweed text)
      if (patch['arabicText'] is String && (patch['arabicText'] as String).trim().isNotEmpty) {
        newArabic = patch['arabicText'] as String;
      }

      // 2. Title override
      if (patch['title'] is String && (patch['title'] as String).trim().isNotEmpty) {
        newTitle = patch['title'] as String;
      }

      // 3. Transliteration override
      if (patch['transliteration'] is String && (patch['transliteration'] as String).trim().isNotEmpty) {
        newTransliteration = patch['transliteration'] as String;
      }

      // 4. Reference / Source override
      if (patch['reference'] is String && (patch['reference'] as String).trim().isNotEmpty) {
        newReference = patch['reference'] as String;
      }

      // 5. Benefit text override
      if (patch['benefit'] is String && (patch['benefit'] as String).trim().isNotEmpty) {
        newBenefit = patch['benefit'] as String;
      }

      // 6. Translation override:
      // Supports language-specific dictionary: e.g. "translations": {"bn": "...", "en": "..."}
      // Or language-specific key: e.g. "translation_bn": "..."
      // Or fallback generic key: e.g. "translation": "..."
      if (patch['translations'] is Map) {
        final transMap = patch['translations'] as Map;
        if (transMap[langCode] is String && (transMap[langCode] as String).trim().isNotEmpty) {
          newTranslation = transMap[langCode] as String;
        }
      }
      if (newTranslation == null && patch['translation_$langCode'] is String) {
        newTranslation = patch['translation_$langCode'] as String;
      }
      if (newTranslation == null && patch['translation'] is String && (patch['translation'] as String).trim().isNotEmpty) {
        newTranslation = patch['translation'] as String;
      }

      return d.copyWith(
        arabicText: newArabic,
        title: newTitle,
        translation: newTranslation,
        transliteration: newTransliteration,
        reference: newReference,
        benefit: newBenefit,
      );
    }).toList();
  }

  /// Fetches the latest corrections from Cloud Firestore 'dua_corrections' collection.
  /// Throttled to execute at most once every 12 hours unless [force] is true.
  ///
  /// Returns the latest Map of corrections if successfully fetched, or null if skipped/failed.
  static Future<Map<String, Map<String, dynamic>>?> syncFromCloud({
    bool force = false,
  }) async {
    if (Firebase.apps.isEmpty) return null;

    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      final lastFetch = prefs.getInt(_prefTimestampKey) ?? 0;

      if (!force && (now - lastFetch < _fetchInterval.inMilliseconds)) {
        // Throttled: use existing local cache to avoid redundant reads
        return null;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('dua_corrections')
          .get(const GetOptions(source: Source.serverAndCache));

      final Map<String, Map<String, dynamic>> corrections = {};
      for (final doc in snapshot.docs) {
        corrections[doc.id] = doc.data();
      }

      // Cache locally for offline availability
      await prefs.setString(_prefCacheKey, jsonEncode(corrections));
      await prefs.setInt(_prefTimestampKey, now);

      debugPrint('[DuaCorrectionService] Synced ${corrections.length} dua correction(s) from cloud');
      return corrections;
    } catch (e) {
      debugPrint('[DuaCorrectionService] Cloud sync skipped/failed: $e');
      return null;
    }
  }
}
