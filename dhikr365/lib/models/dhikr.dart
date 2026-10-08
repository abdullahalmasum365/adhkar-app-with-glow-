import 'package:flutter/material.dart';
import 'dua_timestamp.dart';
import '../services/dua_timestamp_registry.dart';

enum DhikrCategory { morning, evening, protection, focus, parents, graveyard, food, afterSalah, beforeSleep, travel, shifa, distress }

extension DhikrCategoryMeta on DhikrCategory {
  String get titleKey {
    switch (this) {
      case DhikrCategory.morning:
        return 'morning_adhkar';
      case DhikrCategory.evening:
        return 'evening_adhkar';
      case DhikrCategory.afterSalah:
        return 'after_salah';
      case DhikrCategory.protection:
        return 'protection';
      case DhikrCategory.focus:
        return 'focus';
      case DhikrCategory.food:
        return 'food_eating';
      case DhikrCategory.parents:
        return 'parents';
      case DhikrCategory.graveyard:
        return 'graveyard';
      case DhikrCategory.beforeSleep:
        return 'before_sleep';
      case DhikrCategory.travel:
        return 'travel';
      case DhikrCategory.shifa:
        return 'shifa';
      case DhikrCategory.distress:
        return 'distress';
    }
  }

  IconData get icon {
    switch (this) {
      case DhikrCategory.morning:
        return Icons.wb_sunny_outlined;
      case DhikrCategory.evening:
        return Icons.nights_stay_outlined;
      case DhikrCategory.afterSalah:
        return Icons.mosque_outlined;
      case DhikrCategory.protection:
        return Icons.shield_outlined;
      case DhikrCategory.focus:
        return Icons.filter_center_focus;
      case DhikrCategory.food:
        return Icons.restaurant_outlined;
      case DhikrCategory.parents:
        return Icons.family_restroom_outlined;
      case DhikrCategory.graveyard:
        return Icons.landscape_outlined;
      case DhikrCategory.beforeSleep:
        return Icons.bedtime_outlined;
      case DhikrCategory.travel:
        return Icons.flight_takeoff_rounded;
      case DhikrCategory.shifa:
        return Icons.healing_rounded;
      case DhikrCategory.distress:
        return Icons.favorite_rounded;
    }
  }

  Color get color {
    switch (this) {
      case DhikrCategory.morning:
        return const Color(0xFFEC7F13);
      case DhikrCategory.evening:
        return const Color(0xFF6366F1);
      case DhikrCategory.afterSalah:
        return const Color(0xFF14B8A6);
      case DhikrCategory.protection:
        return const Color(0xFFEF4444);
      case DhikrCategory.focus:
        return const Color(0xFF10B981);
      case DhikrCategory.food:
        return const Color(0xFFF59E0B);
      case DhikrCategory.parents:
        return const Color(0xFFEC4899);
      case DhikrCategory.graveyard:
        return const Color(0xFF64748B);
      case DhikrCategory.beforeSleep:
        return const Color(0xFF6366F1);
      case DhikrCategory.travel:
        return const Color(0xFF0EA5E9);
      case DhikrCategory.shifa:
        return const Color(0xFF059669);
      case DhikrCategory.distress:
        return const Color(0xFF8B5CF6);
    }
  }
}

class Dhikr {
  final String id;
  final String title;
  final String arabicText;
  final String translation;
  final String? transliteration;
  final String? audioPath;   // nullable — fixed crash in DhikrFocusScreen
  final String? benefit;
  final String? reference;
  final int targetCount;
  final DhikrCategory category;
  int currentCount;
  final bool isBookmarked;
  final List<DuaSegment>? timestamps;

  Dhikr({
    required this.id,
    required this.title,
    required this.arabicText,
    required this.translation,
    this.transliteration,
    this.audioPath,
    this.benefit,
    this.reference,
    required this.targetCount,
    required this.category,
    this.currentCount = 0,
    this.isBookmarked = false,
    this.timestamps,
  });

  bool get isCompleted => currentCount >= targetCount;

  bool get hasAudio => audioPath != null && audioPath!.isNotEmpty;

  /// True if time-synced phrase timestamps exist for this dhikr.
  /// (True for explicit timestamps, handcrafted registry, or dynamically for all audio duas)
  bool get hasTimestamps =>
      (timestamps != null && timestamps!.isNotEmpty) ||
      DuaTimestampRegistry.hasTimestamps(id) ||
      (hasAudio && arabicText.isNotEmpty);

  List<DuaSegment>? _cachedSegments;

  /// Resolved segments:
  /// 1. Explicit timestamps (if provided)
  /// 2. Handcrafted registry templates (if mapped)
  /// 3. Intelligent proportional auto-segmentation (for all other audio duas)
  List<DuaSegment>? get resolvedTimestamps {
    if (_cachedSegments != null) return _cachedSegments;
    if (timestamps != null && timestamps!.isNotEmpty) {
      _cachedSegments = timestamps;
    } else {
      final fromRegistry = DuaTimestampRegistry.getSegments(id);
      if (fromRegistry != null) {
        _cachedSegments = fromRegistry;
      } else if (hasAudio && arabicText.isNotEmpty) {
        _cachedSegments = DuaTimestampRegistry.generateProportionalSegments(
          arabicText: arabicText,
          translation: translation,
          transliteration: transliteration,
        );
      }
    }
    return _cachedSegments;
  }

  double get progress =>
      targetCount > 0 ? (currentCount / targetCount).clamp(0.0, 1.0) : 0.0;

  Dhikr copyWith({
    int? currentCount,
    String? title,
    String? translation,
    String? transliteration,
    String? benefit,
    String? reference,
    bool? isBookmarked,
    List<DuaSegment>? timestamps,
  }) => Dhikr(
        id: id,
        title: title ?? this.title,
        arabicText: arabicText,
        translation: translation ?? this.translation,
        transliteration: transliteration ?? this.transliteration,
        audioPath: audioPath,
        benefit: benefit ?? this.benefit,
        reference: reference ?? this.reference,
        targetCount: targetCount,
        category: category,
        currentCount: currentCount ?? this.currentCount,
        isBookmarked: isBookmarked ?? this.isBookmarked,
        timestamps: timestamps ?? this.timestamps,
      );
}
