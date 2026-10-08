// ============================================================================
// test/bookmark_test.dart
//
// Unit and Integration Tests for Quick Bookmark & Favorites System:
// 1. Dhikr Model Bookmark field & copyWith
// 2. DhikrCategoryMeta extension completeness (all 12 categories)
// 3. DhikrProvider bookmark toggle, persistence, and filtering
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dhikr365/models/dhikr.dart';
import 'package:dhikr365/providers/dhikr_provider.dart';

import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'),
            (MethodCall methodCall) async {
      return true;
    });
  });

  group('Dhikr Model Bookmark Field', () {
    test('Default isBookmarked is false', () {
      final dhikr = Dhikr(
        id: 'test_1',
        title: 'SubhanAllah',
        arabicText: 'سُبْحَانَ اللَّهِ',
        translation: 'Glory be to Allah',
        targetCount: 33,
        category: DhikrCategory.morning,
      );

      expect(dhikr.isBookmarked, isFalse);
    });

    test('copyWith preserves or updates isBookmarked accurately', () {
      final dhikr = Dhikr(
        id: 'test_1',
        title: 'SubhanAllah',
        arabicText: 'سُبْحَانَ اللَّهِ',
        translation: 'Glory be to Allah',
        targetCount: 33,
        category: DhikrCategory.morning,
        isBookmarked: false,
      );

      final bookmarked = dhikr.copyWith(isBookmarked: true);
      expect(bookmarked.isBookmarked, isTrue);
      expect(bookmarked.id, equals('test_1'));
      expect(bookmarked.title, equals('SubhanAllah'));

      final unbookmarked = bookmarked.copyWith(isBookmarked: false);
      expect(unbookmarked.isBookmarked, isFalse);
    });
  });

  group('DhikrCategoryMeta Extension Completeness', () {
    test('All 12 categories have titleKey, icon, and color defined', () {
      for (final cat in DhikrCategory.values) {
        expect(cat.titleKey.isNotEmpty, isTrue,
            reason: 'Missing titleKey for $cat');
        expect(cat.icon, isA<IconData>(),
            reason: 'Missing icon for $cat');
        expect(cat.color, isA<Color>(),
            reason: 'Missing color for $cat');
      }
    });
  });

  group('DhikrProvider Bookmark Operations', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'bookmark_morning_1': true,
      });
    });

    test('toggleBookmark toggles state and persists to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = DhikrProvider();

      // Wait briefly for provider initialization
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final dhikrs = provider.dhikrs;
      if (dhikrs.isNotEmpty) {
        final targetId = dhikrs.first.id;
        expect(provider.isBookmarked(targetId), isFalse);

        // Toggle ON
        await provider.toggleBookmark(targetId);
        expect(provider.isBookmarked(targetId), isTrue);
        expect(provider.bookmarkedDhikrs.any((d) => d.id == targetId), isTrue);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('bookmark_$targetId'), isTrue);

        // Toggle OFF
        await provider.toggleBookmark(targetId);
        expect(provider.isBookmarked(targetId), isFalse);
        expect(provider.bookmarkedDhikrs.any((d) => d.id == targetId), isFalse);
        expect(prefs.getBool('bookmark_$targetId'), isFalse);
      }
    });

    test('bookmarkedDhikrs getter filters only bookmarked items', () async {
      final provider = DhikrProvider();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      for (final d in provider.bookmarkedDhikrs) {
        expect(d.isBookmarked, isTrue);
      }
    });
  });
}
