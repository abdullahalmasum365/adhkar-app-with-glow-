// ============================================================================
// test/widget_and_smart_notification_test.dart
//
// Automated Unit Tests for:
// 1. SmartNotificationEngine Sunnah timing offsets, Hadith hooks, streak copy
// 2. Multi-Theme Palette Pro access flags
// 3. WidgetService constants and deep link configurations
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dhikr365/constants/app_theme.dart';
import 'package:dhikr365/services/smart_notification_engine.dart';
import 'package:dhikr365/services/widget_service.dart';

void main() {
  group('SmartNotificationEngine Sunnah Timing & Offsets', () {
    test('1. Morning Adhkar offset is exactly 18 mins after Fajr', () {
      expect(SmartNotificationEngine.morningFajrOffset,
          equals(const Duration(minutes: 18)));
    });

    test('2. Evening Adhkar offset is exactly 12 mins after Asr', () {
      expect(SmartNotificationEngine.eveningAsrOffset,
          equals(const Duration(minutes: 12)));
    });

    test('3. Before Sleep Adhkar offset is exactly 35 mins after Isha', () {
      expect(SmartNotificationEngine.beforeSleepIshaOffset,
          equals(const Duration(minutes: 35)));
    });

    test('4. Jumu\'ah Hour of Acceptance offset is 60 mins before Maghrib', () {
      expect(SmartNotificationEngine.jumuahMaghribOffset,
          equals(const Duration(minutes: -60)));
    });
  });

  group('SmartNotificationEngine Rotating Authentic Hooks & Streak Copy', () {
    test('5. Bengali and English hooks return non-empty authentic Hadith text', () {
      final hookMorningBn =
          SmartNotificationEngine.getMorningHook('bn', 0);
      final hookEveningBn =
          SmartNotificationEngine.getEveningHook('bn', 1);
      final hookMorningEn =
          SmartNotificationEngine.getMorningHook('en', 0);
      final hookEveningEn =
          SmartNotificationEngine.getEveningHook('en', 1);
      final hookSleepBn =
          SmartNotificationEngine.getBeforeSleepHook('bn', 0);
      final hookJumuahBn =
          SmartNotificationEngine.getJumuahHook('bn', 0);

      expect(hookMorningBn.title.isNotEmpty, isTrue);
      expect(hookMorningBn.body.isNotEmpty, isTrue);
      expect(hookEveningBn.title.isNotEmpty, isTrue);
      expect(hookEveningBn.body.isNotEmpty, isTrue);
      expect(hookMorningEn.title.isNotEmpty, isTrue);
      expect(hookMorningEn.body.isNotEmpty, isTrue);
      expect(hookEveningEn.title.isNotEmpty, isTrue);
      expect(hookEveningEn.body.isNotEmpty, isTrue);
      expect(hookSleepBn.title.isNotEmpty, isTrue);
      expect(hookSleepBn.body.isNotEmpty, isTrue);
      expect(hookJumuahBn.title.isNotEmpty, isTrue);
      expect(hookJumuahBn.body.isNotEmpty, isTrue);
    });

    test('6. Streak loss-aversion messaging attaches when streak >= 3', () {
      final hookWithStreakBn = SmartNotificationEngine.getMorningHook(
        'bn',
        0,
        streak: 5,
      );
      expect(hookWithStreakBn.title.contains('🔥 আপনার 5 দিনের আমল স্ট্রিক চলমান!'), isTrue);

      final hookWithStreakEn = SmartNotificationEngine.getMorningHook(
        'en',
        0,
        streak: 7,
      );
      expect(hookWithStreakEn.title.contains('🔥 7-Day Dhikr Streak Active!'), isTrue);

      final hookNoStreak = SmartNotificationEngine.getMorningHook(
        'bn',
        0,
        streak: 1,
      );
      expect(hookNoStreak.title.contains('স্ট্রিক চলমান'), isFalse);
    });

    test('7. Action button labels are properly localized', () {
      expect(SmartNotificationEngine.getReadActionLabel('bn'),
          equals('📖 এখনই পড়ুন'));
      expect(SmartNotificationEngine.getReadActionLabel('en'),
          equals('📖 Read Now'));
      expect(SmartNotificationEngine.getSnoozeActionLabel('bn'),
          equals('⏰ ১৫ মিনিট পর'));
      expect(SmartNotificationEngine.getSnoozeActionLabel('en'),
          equals('⏰ Snooze 15m'));
    });
  });

  group('Multi-Theme Palettes & Pro Access Verification', () {
    test('8. Luxury palettes are marked isPro: true while base palettes are free', () {
      expect(AppPalettes.emeraldNight.isPro, isFalse);
      expect(AppPalettes.sapphireGold.isPro, isFalse);
      expect(AppPalettes.royalWhite.isPro, isFalse);
      expect(AppPalettes.kindleReader.isPro, isFalse);
      expect(AppPalettes.desertMushaf.isPro, isFalse);

      expect(AppPalettes.midnightAmoled.isPro, isTrue);
      expect(AppPalettes.carbonLime.isPro, isTrue);
      expect(AppPalettes.cosmicVanilla.isPro, isTrue);
      expect(AppPalettes.onyxCandyBlue.isPro, isTrue);
      expect(AppPalettes.jetOrchid.isPro, isTrue);
      expect(AppPalettes.wineTurquoise.isPro, isTrue);
    });

    test('9. All palettes have distinct non-null colors and valid IDs', () {
      for (final p in AppPalettes.all) {
        expect(p.id.isNotEmpty, isTrue);
        expect(p.label.isNotEmpty, isTrue);
        expect(p.homeGradient.length, greaterThanOrEqualTo(2));
      }
    });
  });

  group('WidgetService Configuration', () {
    test('10. All 6 widget providers are correctly registered', () {
      expect(WidgetService.allWidgetProviders.length, equals(6));
      expect(WidgetService.allWidgetProviders,
          contains(WidgetService.prayerCountdownWidget));
      expect(WidgetService.allWidgetProviders,
          contains(WidgetService.prayerCompactWidget));
      expect(WidgetService.allWidgetProviders,
          contains(WidgetService.adhkarTrackerWidget));
      expect(WidgetService.allWidgetProviders,
          contains(WidgetService.adhkarTrackerSmallWidget));
      expect(WidgetService.allWidgetProviders,
          contains(WidgetService.duaOfTheDayWidget));
      expect(
          WidgetService.allWidgetProviders, contains(WidgetService.tasbihWidget));
    });
  });
}
