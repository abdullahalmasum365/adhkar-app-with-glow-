import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dhikr.dart';
import '../services/audio_service.dart';
import '../services/widget_service.dart';

/// Milestone categories for tasbih counting and haptic/animation feedback.
enum MilestoneType {
  none,
  thirtyThree,
  sixtySix,
  hundred,
  target,
}

class DhikrProvider extends ChangeNotifier {
  List<Dhikr> _dhikrs = [];
  String _currentLanguageCode = 'en';
  final Map<String, List<int>> _weeklyData = {}; // date-string -> [counts]
  String? _uid;

  List<Dhikr> get dhikrs => _dhikrs;
  String get currentLanguageCode => _currentLanguageCode;

  // Categories fully completed today (all dhikrs in each reached targetCount).
  // Used to: (a) update streak only on real completion, (b) trigger celebration.
  final Set<DhikrCategory> _completedToday = {};

  /// True when every dhikr in [cat] has been tapped to completion today.
  bool isCategoryCompleted(DhikrCategory cat) => _completedToday.contains(cat);

  void setAppLanguage(String code) {
    _currentLanguageCode = code;
    notifyListeners();
  }

  // ── Stats getters used by ProgressScreen ──
  int get totalDhikrCount => _dhikrs.fold(0, (acc, d) => acc + d.currentCount);

  int get completedSets => _dhikrs
      .where((d) => d.targetCount > 0 && d.currentCount >= d.targetCount)
      .length;

  int get streakDays {
    final prefsStreak = _cachedStreak;
    return prefsStreak;
  }

  int _cachedStreak = 0;
  bool _earlyBirdBadge = false;
  bool _nightPrayerBadge = false;

  bool get earlyBirdBadge => _earlyBirdBadge;
  bool get nightPrayerBadge => _nightPrayerBadge;

  Map<int, int> _monthlyActivity = {};
  Map<int, int> get monthlyActivity => _monthlyActivity;

  int getCategoryCompletedCount(DhikrCategory cat) =>
      _dhikrs.where((d) => d.category == cat && d.targetCount > 0 && d.currentCount >= d.targetCount).length;

  int getCategoryTotalCount(DhikrCategory cat) =>
      _dhikrs.where((d) => d.category == cat).length;

  double getCategoryProgress(DhikrCategory cat) {
    final total = getCategoryTotalCount(cat);
    if (total == 0) return 0.0;
    return (getCategoryCompletedCount(cat) / total).clamp(0.0, 1.0);
  }

  /// Last 7 days activity (count per day, oldest→newest)
  List<int> get weeklyActivity {
    final result = <int>[];
    for (int i = 6; i >= 0; i--) {
      final day = _dateKey(DateTime.now().subtract(Duration(days: i)));
      result.add((_weeklyData[day] ?? []).fold(0, (a, b) => a + b));
    }
    return result;
  }

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  DhikrProvider() {
    _loadDhikrs();
  }

  Future<void> _loadDhikrs() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedStreak = prefs.getInt('streak_days') ?? 0;
    _earlyBirdBadge = prefs.getBool('badge_early_bird') ?? false;
    _nightPrayerBadge = prefs.getBool('badge_night_prayer') ?? false;

    // Load weekly data
    for (int i = 0; i < 7; i++) {
      final key = _dateKey(DateTime.now().subtract(Duration(days: i)));
      final val = prefs.getInt('daily_$key') ?? 0;
      _weeklyData[key] = [val];
    }

    // Load monthly activity for current month
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final activity = <int, int>{};
    for (int day = 1; day <= daysInMonth; day++) {
      final key = '${now.year}-${now.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
      activity[day] = prefs.getInt('daily_$key') ?? 0;
    }
    _monthlyActivity = activity;

    final savedUiLang = prefs.getString('language_code') ?? 'en';
    final savedTransLang = prefs.getString('translation_language') ?? savedUiLang;
    final savedTranslitLang = prefs.getString('transliteration_language') ?? savedTransLang;

    _currentLanguageCode = savedUiLang;
    final transLang = _resolveAssetLang(savedTransLang);
    _dhikrs = await _buildDhikrsFromAssets(langCode: transLang);

    if (savedTranslitLang != savedTransLang) {
      final transliLang = _resolveAssetLang(savedTranslitLang);
      final transliList = await _buildDhikrsFromAssets(langCode: transliLang);
      _dhikrs = _dhikrs.map((d) {
        final match = transliList.firstWhere(
          (t) => t.id == d.id, orElse: () => d);
        return d.copyWith(transliteration: match.transliteration);
      }).toList();
    }

    // ── FIX #5: Daily reset ───────────────────────────────────────────────────
    // If the date has changed since the last session, wipe all counts so every
    // new day starts fresh. Otherwise restore whatever the user had in progress.
    final today = _dateKey(DateTime.now());
    final lastResetDate = prefs.getString('last_reset_date') ?? '';

    if (lastResetDate != today) {
      // New day — reset all counts to zero
      _dhikrs = _dhikrs.map((d) {
        final isSaved = prefs.getBool('bookmark_${d.id}') ?? false;
        return d.copyWith(currentCount: 0, isBookmarked: isSaved);
      }).toList();
      await prefs.setString('last_reset_date', today);
      // Clear all saved per-dhikr counts
      for (final d in _dhikrs) {
        await prefs.remove('count_${d.id}');
      }
      // New day means nothing completed yet
      _completedToday.clear();
    } else {
      // Same day — restore in-progress counts
      _dhikrs = _dhikrs.map((d) {
        final saved = prefs.getInt('count_${d.id}') ?? 0;
        final isSaved = prefs.getBool('bookmark_${d.id}') ?? false;
        return d.copyWith(currentCount: saved, isBookmarked: isSaved);
      }).toList();
      // Re-derive which categories were already complete at last save
      for (final cat in DhikrCategory.values) {
        final catDhikrs = _dhikrs.where((d) => d.category == cat).toList();
        if (catDhikrs.isNotEmpty &&
            catDhikrs.every((d) => d.currentCount >= d.targetCount)) {
          _completedToday.add(cat);
        }
      }
    }
    // ─────────────────────────────────────────────────────────────────────────

    notifyListeners();
    _syncHomeWidget();
  }

  void _syncHomeWidget() {
    try {
      final morningDone = getCategoryCompletedCount(DhikrCategory.morning);
      final morningTotal = getCategoryTotalCount(DhikrCategory.morning);
      final eveningDone = getCategoryCompletedCount(DhikrCategory.evening);
      final eveningTotal = getCategoryTotalCount(DhikrCategory.evening);

      WidgetService().updateAdhkarTrackerData(
        streakDays: streakDays,
        morningDone: morningDone,
        morningTotal: morningTotal,
        eveningDone: eveningDone,
        eveningTotal: eveningTotal,
      ).catchError((e) {
        debugPrint('[DhikrProvider] WidgetService update error: $e');
      });
    } catch (e) {
      debugPrint('[DhikrProvider] WidgetService update error: $e');
    }
  }

  Future<void> _saveCounts() async {
    final prefs = await SharedPreferences.getInstance();
    for (final d in _dhikrs) {
      await prefs.setInt('count_${d.id}', d.currentCount);
    }
    final today = _dateKey(DateTime.now());
    await prefs.setInt('daily_$today', totalDhikrCount);
    _weeklyData[today] = [totalDhikrCount];
    _monthlyActivity[DateTime.now().day] = totalDhikrCount;
    _syncHomeWidget();
  }

  /// Checks if [count] reached a tasbih milestone or the target count.
  /// - `target`: when `targetCount > 0 && count >= targetCount`
  /// - `hundred`: when `count == 100` (and not already target)
  /// - `sixtySix`: when `count == 66` (and not target)
  /// - `thirtyThree`: when `count == 33` or `(count > 0 && count % 33 == 0 && count <= 99)`
  /// - `none`: otherwise
  static MilestoneType checkMilestone({
    required int count,
    required int targetCount,
  }) {
    if (targetCount > 0 && count >= targetCount) {
      return MilestoneType.target;
    }
    if (count == 100) {
      return MilestoneType.hundred;
    }
    if (count == 66) {
      return MilestoneType.sixtySix;
    }
    if (count == 33 || (count > 0 && count % 33 == 0 && count <= 99)) {
      return MilestoneType.thirtyThree;
    }
    return MilestoneType.none;
  }

  /// Triggers tasbih milestone haptic patterns:
  /// - normal tap / none: single lightImpact
  /// - 33 / 66: double medium buzz with 120ms gap
  /// - 100 / target: triple heavy buzz with 100ms gaps
  static Future<void> triggerMilestoneHaptic(MilestoneType milestone) async {
    try {
      switch (milestone) {
        case MilestoneType.none:
          await HapticFeedback.lightImpact();
          break;
        case MilestoneType.thirtyThree:
        case MilestoneType.sixtySix:
          await HapticFeedback.mediumImpact();
          await Future.delayed(const Duration(milliseconds: 120));
          await HapticFeedback.mediumImpact();
          break;
        case MilestoneType.hundred:
        case MilestoneType.target:
          await HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 100));
          await HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 100));
          await HapticFeedback.heavyImpact();
          break;
      }
    } catch (_) {
      // Ignored gracefully on platforms/emulators without vibrator support
    }
  }

  /// Safely plays a completion chime if an asset exists; skips silently otherwise.
  static Future<void> playCompletionSound() async {
    try {
      const candidatePaths = [
        'assets/audio/chime.mp3',
        'assets/audio/ding.mp3',
        'assets/audio/completion_chime.mp3',
      ];
      String? foundAsset;
      for (final path in candidatePaths) {
        try {
          await rootBundle.load(path);
          foundAsset = path;
          break;
        } catch (_) {}
      }
      if (foundAsset != null) {
        final player = AudioPlayer();
        await player
            .play(AssetSource(foundAsset.replaceFirst('assets/', '')))
            .catchError((_) {});
      }
    } catch (_) {
      // Silently skip
    }
  }

  Future<MilestoneType> incrementDhikr(String id) async {
    final idx = _dhikrs.indexWhere((d) => d.id == id);
    if (idx == -1) return MilestoneType.none;
    final d = _dhikrs[idx];
    if (d.currentCount < d.targetCount || d.targetCount == 0) {
      final newCount = d.currentCount + 1;
      _dhikrs[idx] = d.copyWith(currentCount: newCount);
      notifyListeners();

      final milestone = checkMilestone(
        count: newCount,
        targetCount: d.targetCount,
      );

      // Only update the streak when the full category is completed, not on
      // every individual tap.  _checkCategoryCompletion is a no-op if the
      // category is already in _completedToday.
      await _checkCategoryCompletion(d.category);
      await _saveCounts();

      return milestone;
    }
    return MilestoneType.none;
  }

  /// Marks [category] as completed today and updates the streak the first time
  /// every dhikr in that category reaches its targetCount.
  Future<void> _checkCategoryCompletion(DhikrCategory category) async {
    if (_completedToday.contains(category)) return;
    final catDhikrs = _dhikrs.where((d) => d.category == category).toList();
    if (catDhikrs.isEmpty) return;
    if (catDhikrs.every((d) => d.currentCount >= d.targetCount)) {
      _completedToday.add(category);
      await _updateStreak();

      final prefs = await SharedPreferences.getInstance();
      final currentHour = DateTime.now().hour;

      if (category == DhikrCategory.morning && currentHour < 11) {
        if (!_earlyBirdBadge) {
          _earlyBirdBadge = true;
          await prefs.setBool('badge_early_bird', true);
        }
      }

      if (category == DhikrCategory.beforeSleep ||
          (category == DhikrCategory.evening && (currentHour >= 18 || currentHour < 5))) {
        if (!_nightPrayerBadge) {
          _nightPrayerBadge = true;
          await prefs.setBool('badge_night_prayer', true);
        }
      }

      if (_uid != null) unawaited(_pushToCloud());
      notifyListeners();
    }
  }

  void resetDhikr(String id) {
    final idx = _dhikrs.indexWhere((d) => d.id == id);
    if (idx == -1) return;
    _dhikrs[idx] = _dhikrs[idx].copyWith(currentCount: 0);
    _saveCounts();
    notifyListeners();
  }

  void resetAll() {
    _dhikrs = _dhikrs.map((d) => d.copyWith(currentCount: 0)).toList();
    // Clear completion state so celebrations can fire again if the user
    // re-completes the categories.  The streak itself is NOT cleared — it is
    // date-keyed and _updateStreak() guards against double-counting.
    _completedToday.clear();
    _saveCounts();
    notifyListeners();
  }

  // ── DEV / TEST ONLY: full progress wipe ──────────────────────────────────
  /// Resets EVERYTHING — counts, streak, badges, daily history, last_reset_date.
  /// Used by the hidden Dev Panel in Settings for clean-slate testing.
  Future<void> devResetAllProgress() async {
    final prefs = await SharedPreferences.getInstance();
    for (final d in _dhikrs) {
      await prefs.remove('count_${d.id}');
      await prefs.remove('bookmark_${d.id}');
    }
    await prefs.remove('streak_days');
    await prefs.remove('last_active_date');
    await prefs.remove('badge_early_bird');
    await prefs.remove('badge_night_prayer');
    await prefs.remove('last_reset_date');
    for (int i = 0; i < 31; i++) {
      final day = DateTime.now().subtract(Duration(days: i));
      await prefs.remove('daily_${_dateKey(day)}');
    }
    _dhikrs = _dhikrs.map((d) => d.copyWith(currentCount: 0, isBookmarked: false)).toList();
    _completedToday.clear();
    _cachedStreak = 0;
    _earlyBirdBadge = false;
    _nightPrayerBadge = false;
    _weeklyData.clear();
    _monthlyActivity.clear();
    notifyListeners();
    _syncHomeWidget();
  }
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _updateStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final lastActive = prefs.getString('last_active_date') ?? '';
    final today     = _dateKey(DateTime.now());
    final yesterday = _dateKey(DateTime.now().subtract(const Duration(days: 1)));

    // Already counted today — nothing to do.
    if (lastActive == today) return;

    // ── FIX #4: Read streak from prefs, not from _cachedStreak ───────────────
    // _cachedStreak may still be 0 if _loadDhikrs() hasn't finished yet
    // (race condition). Reading from prefs gives the authoritative value.
    final savedStreak = prefs.getInt('streak_days') ?? 0;

    if (lastActive == yesterday) {
      // Consecutive day — extend the streak.
      _cachedStreak = savedStreak + 1;
    } else {
      // Missed one or more days (or first ever tap) — restart from 1.
      _cachedStreak = 1;
    }
    // ─────────────────────────────────────────────────────────────────────────

    await prefs.setInt('streak_days', _cachedStreak);
    await prefs.setString('last_active_date', today);
    if (_uid != null) unawaited(_pushToCloud());
    notifyListeners(); // refresh streak stat immediately after first tap
  }

  // ── Cloud sync ────────────────────────────────────────────────────────

  DocumentReference<Map<String, dynamic>>? get _cloudDoc {
    if (_uid == null || Firebase.apps.isEmpty) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('progress')
        .doc('data');
  }

  /// Restores progress from Firestore when user logs in with Google/Apple,
  /// preserving whichever streak or badges are highest/achieved.
  Future<void> attachUser(String? uid) async {
    if (uid == _uid) return;
    _uid = uid;
    if (uid == null || Firebase.apps.isEmpty) return;

    try {
      final doc = _cloudDoc;
      if (doc == null) return;
      final snap = await doc.get();

      final prefs = await SharedPreferences.getInstance();

      if (snap.exists) {
        final data = snap.data()!;
        final cloudStreak = (data['streak_days'] as num?)?.toInt() ?? 0;
        final cloudEarlyBird = data['badge_early_bird'] as bool? ?? false;
        final cloudNightPrayer = data['badge_night_prayer'] as bool? ?? false;
        final cloudLastActive = data['last_active_date'] as String? ?? '';

        // Merge: keep highest streak and unlocked badges
        if (cloudStreak > _cachedStreak) {
          _cachedStreak = cloudStreak;
          await prefs.setInt('streak_days', _cachedStreak);
        }
        if (cloudEarlyBird && !_earlyBirdBadge) {
          _earlyBirdBadge = true;
          await prefs.setBool('badge_early_bird', true);
        }
        if (cloudNightPrayer && !_nightPrayerBadge) {
          _nightPrayerBadge = true;
          await prefs.setBool('badge_night_prayer', true);
        }
        if (cloudLastActive.isNotEmpty) {
          final localLastActive = prefs.getString('last_active_date') ?? '';
          if (localLastActive.isEmpty) {
            await prefs.setString('last_active_date', cloudLastActive);
          }
        }
        notifyListeners();
      }

      await _pushToCloud();
    } catch (e) {
      debugPrint('[DhikrProvider] cloud progress sync on sign-in failed: $e');
    }
  }

  Future<void> _pushToCloud() async {
    final doc = _cloudDoc;
    if (doc == null) return;
    try {
      final currentAuthUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentAuthUid == null || currentAuthUid != _uid) return;

      final prefs = await SharedPreferences.getInstance();
      final lastActive = prefs.getString('last_active_date') ?? '';

      await doc.set({
        'streak_days': _cachedStreak,
        'badge_early_bird': _earlyBirdBadge,
        'badge_night_prayer': _nightPrayerBadge,
        'last_active_date': lastActive,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[DhikrProvider] cloud progress push failed: $e');
    }
  }

  double calculateProgressFor(List<Dhikr> list) {
    if (list.isEmpty) return 0.0;
    final completed = list.where((d) => d.isCompleted).length;
    return completed / list.length;
  }

  List<Dhikr> getMorningDhikrs() =>
      _dhikrs.where((d) => d.category == DhikrCategory.morning).toList();

  List<Dhikr> getEveningDhikrs() =>
      _dhikrs.where((d) => d.category == DhikrCategory.evening).toList();

  List<Dhikr> getProtectionDhikrs() =>
      _dhikrs.where((d) => d.category == DhikrCategory.protection).toList();

  List<Dhikr> getFocusDhikrs() =>
      _dhikrs.where((d) => d.category == DhikrCategory.focus).toList();

  List<Dhikr> getParentsDhikrs() =>
      _dhikrs.where((d) => d.category == DhikrCategory.parents).toList();

  List<Dhikr> getGraveyardDhikrs() =>
      _dhikrs.where((d) => d.category == DhikrCategory.graveyard).toList();

  List<Dhikr> getFoodDhikrs() =>
      _dhikrs.where((d) => d.category == DhikrCategory.food).toList();

  List<Dhikr> getAfterSalahDhikrs() =>
      _dhikrs.where((d) => d.category == DhikrCategory.afterSalah).toList();

  List<Dhikr> getBeforeSleepDhikrs() =>
      _dhikrs.where((d) => d.category == DhikrCategory.beforeSleep).toList();

  List<Dhikr> getTravelDhikrs() =>
      _dhikrs.where((d) => d.category == DhikrCategory.travel).toList();

  List<Dhikr> getShifaDhikrs() =>
      _dhikrs.where((d) => d.category == DhikrCategory.shifa).toList();

  List<Dhikr> getDistressDhikrs() =>
      _dhikrs.where((d) => d.category == DhikrCategory.distress).toList();

  List<Dhikr> getDhikrsByCategory(DhikrCategory category) =>
      _dhikrs.where((d) => d.category == category).toList();

  /// All duas bookmarked/favorited by the user across all categories.
  List<Dhikr> get bookmarkedDhikrs =>
      _dhikrs.where((d) => d.isBookmarked).toList();

  /// Whether a specific dhikr is currently bookmarked.
  bool isBookmarked(String dhikrId) =>
      _dhikrs.any((d) => d.id == dhikrId && d.isBookmarked);

  /// Toggles the bookmark state for [dhikrId] and persists it with key `bookmark_<id>`.
  Future<void> toggleBookmark(String dhikrId) async {
    final idx = _dhikrs.indexWhere((d) => d.id == dhikrId);
    if (idx == -1) return;
    final updated = !_dhikrs[idx].isBookmarked;
    _dhikrs[idx] = _dhikrs[idx].copyWith(isBookmarked: updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bookmark_$dhikrId', updated);
    notifyListeners();
  }

  Future reloadDhikrs({
    required String uiLanguageCode,
    required String transliterationCode,
    required String translationCode,
  }) async {
    _currentLanguageCode = uiLanguageCode;
    final prefs = await SharedPreferences.getInstance();

    final transLang = _resolveAssetLang(translationCode);
    _dhikrs = await _buildDhikrsFromAssets(langCode: transLang);

    if (transliterationCode != translationCode) {
      final transliLang = _resolveAssetLang(transliterationCode);
      final transliList = await _buildDhikrsFromAssets(langCode: transliLang);
      _dhikrs = _dhikrs.map((d) {
        final match = transliList.firstWhere(
          (t) => t.id == d.id, orElse: () => d);
        return d.copyWith(transliteration: match.transliteration);
      }).toList();
    }

    _dhikrs = _dhikrs.map((d) {
      final saved = prefs.getInt('count_${d.id}') ?? 0;
      final isSaved = prefs.getBool('bookmark_${d.id}') ?? false;
      return d.copyWith(currentCount: saved, isBookmarked: isSaved);
    }).toList();

    notifyListeners();
  }

  /// Languages for which we have JSON translation files.
  static const _supportedLangs = {
    'ar', 'bn', 'de', 'en', 'es', 'fr', 'hi', 'id', 'it',
    'ja', 'ms', 'nl', 'pt', 'ru', 'ta', 'th', 'tr', 'ur', 'zh',
  };

  String _resolveAssetLang(String code) =>
      _supportedLangs.contains(code) ? code : 'en';

  // ── Build dhikrs by loading from JSON assets ──────────────────────────────

  // pubspec.yaml must have:
  // flutter:
  //   assets:
  //     - assets/translations/morning/
  //     - assets/translations/evening/
  Future<List<Dhikr>> _buildDhikrsFromAssets({String langCode = 'en'}) async {
    final lang = _resolveAssetLang(langCode);
    final List<Dhikr> result = [];

    // Load morning duas
    result.addAll(await _parseDhikrFile(
      assetPath: 'assets/translations/morning/$lang.json',
      category: DhikrCategory.morning,
      prefix: 'morning',
    ));

    // Load evening duas
    result.addAll(await _parseDhikrFile(
      assetPath: 'assets/translations/evening/$lang.json',
      category: DhikrCategory.evening,
      prefix: 'evening',
    ));

    // Load protection dhikrs from JSON
    result.addAll(await _parseDhikrFile(
      assetPath: 'assets/translations/protection/$lang.json',
      category: DhikrCategory.protection,
      prefix: '',
    ));

    // Load focus dhikrs from JSON
    result.addAll(await _parseDhikrFile(
      assetPath: 'assets/translations/focus/$lang.json',
      category: DhikrCategory.focus,
      prefix: '',
    ));

    // Load parents duas from JSON (keys already contain 'parents_' prefix)
    result.addAll(await _parseDhikrFile(
      assetPath: 'assets/translations/parents/$lang.json',
      category: DhikrCategory.parents,
      prefix: '',
    ));

    // Load food duas from JSON (keys already contain 'food_' prefix)
    result.addAll(await _parseDhikrFile(
      assetPath: 'assets/translations/food/$lang.json',
      category: DhikrCategory.food,
      prefix: '',
    ));

    // Load graveyard duas from JSON (keys carry 'grave_' prefix)
    result.addAll(await _parseDhikrFile(
      assetPath: 'assets/translations/graveyard/$lang.json',
      category: DhikrCategory.graveyard,
      prefix: '',
    ));

    // Load after-salah adhkar (Hisnul Muslim, "After salam" chapter;
    // keys carry 'salah_' prefix)
    result.addAll(await _parseDhikrFile(
      assetPath: 'assets/translations/after_salah/$lang.json',
      category: DhikrCategory.afterSalah,
      prefix: '',
    ));

    // Load before-sleep adhkar (Hisnul Muslim, "Before sleeping" chapter;
    // keys carry 'sleep_' prefix)
    result.addAll(await _parseDhikrFile(
      assetPath: 'assets/translations/before_sleep/$lang.json',
      category: DhikrCategory.beforeSleep,
      prefix: '',
    ));

    // Load travel duas from JSON
    result.addAll(await _parseDhikrFile(
      assetPath: 'assets/translations/travel/$lang.json',
      category: DhikrCategory.travel,
      prefix: '',
    ));

    // Load shifa/healing duas from JSON
    result.addAll(await _parseDhikrFile(
      assetPath: 'assets/translations/shifa/$lang.json',
      category: DhikrCategory.shifa,
      prefix: '',
    ));

    // Load distress/anxiety duas from JSON
    result.addAll(await _parseDhikrFile(
      assetPath: 'assets/translations/distress/$lang.json',
      category: DhikrCategory.distress,
      prefix: '',
    ));

    return result;
  }

  Future<List<Dhikr>> _parseDhikrFile({
    required String assetPath,
    required DhikrCategory category,
    required String prefix,
  }) async {
    try {
      final jsonString = await rootBundle.loadString(assetPath);
      final Map<String, dynamic> jsonData = jsonDecode(jsonString);
      final Map<String, dynamic> dhikrsMap =
          jsonData['dhikrs'] as Map<String, dynamic>? ?? {};

      final List<Dhikr> list = [];
      dhikrsMap.forEach((key, value) {
        final entry = value as Map<String, dynamic>;
        // When prefix is empty the key already contains the full ID (e.g.
      // parents_rabbir_hamhuma, food_bismillah).  Otherwise prepend the prefix.
      final id = prefix.isEmpty ? key : '${prefix}_$key';
        // audioPath: JSON audioPath wins if present; otherwise auto-resolves
        // to audio/{id}.mp3 if an audio file exists in assets/audio/.
        // If no recording exists, it remains null (so no play button is shown).
        final jsonAudioPath = entry['audioPath'] as String?;
        final audioPath = AudioService.resolveAudioPath(id, jsonAudioPath);

        list.add(Dhikr(
          id: id,
          title: entry['title'] as String? ?? '',
          arabicText: entry['arabicText'] as String? ?? '',
          translation: entry['translation'] as String? ?? '',
          transliteration: entry['transliteration'] as String?,
          audioPath: audioPath,
          benefit: entry['benefit'] as String?,
          reference: entry['reference'] as String?,
          targetCount: (entry['targetCount'] as num?)?.toInt() ?? 1,
          category: category,
        ));
      });
      return list;
    } catch (e) {
      debugPrint('DhikrProvider: failed to load $assetPath — $e');
      return [];
    }
  }

}

