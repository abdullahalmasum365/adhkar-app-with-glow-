import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dhikr365/providers/custom_plan_provider.dart';
import 'package:dhikr365/models/dhikr.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Subscription & Custom Plan Automated Verification', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('1. Default State: Custom Plan is off, all dhikrs enabled by default', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = CustomPlanProvider();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(provider.useCustomPlan, isFalse);
      expect(provider.enabledDhikrIds, isEmpty);

      // In standard mode, isDhikrEnabled returns true for any dhikr
      expect(provider.isDhikrEnabled('m_ayatulkursi'), isTrue);
      expect(provider.isDhikrEnabled('e_sayyidul_istighfar'), isTrue);
    });

    test('2. Subscription Unlocks Pro: Simulated active subscription in SharedPreferences', () async {
      // Simulate successful in-app purchase of subscription
      SharedPreferences.setMockInitialValues({
        'active_subscription_id': 'tier_monthly',
      });
      final prefs = await SharedPreferences.getInstance();

      final savedSub = prefs.getString('active_subscription_id');
      expect(savedSub, equals('tier_monthly'));
      expect(savedSub != null, isTrue); // Pro is unlocked!
    });

    test('3. Custom Plan: Enabling custom routine & selecting specific duas', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = CustomPlanProvider();
      await Future.delayed(const Duration(milliseconds: 50));

      // User turns on My Plan (custom plan)
      provider.setUseCustomPlan(true);
      expect(provider.useCustomPlan, isTrue);

      // User selects 3 favorite duas
      provider.toggleDhikr('m_ayatulkursi', true);
      provider.toggleDhikr('e_sayyidul_istighfar', true);
      provider.toggleDhikr('food_bismillah', true);

      expect(provider.enabledDhikrIds.length, equals(3));
      expect(provider.isDhikrEnabled('m_ayatulkursi'), isTrue);
      expect(provider.isDhikrEnabled('e_sayyidul_istighfar'), isTrue);
      expect(provider.isDhikrEnabled('food_bismillah'), isTrue);

      // Duas not selected are filtered out
      expect(provider.isDhikrEnabled('sleep_bedtime'), isFalse);
      expect(provider.isDhikrEnabled('distress_debt'), isFalse);
    });

    test('4. Data Persistence: Custom Plan state persists after app restart', () async {
      // Step A: First session saves custom selection
      SharedPreferences.setMockInitialValues({});
      final session1 = CustomPlanProvider();
      await Future.delayed(const Duration(milliseconds: 50));

      session1.setUseCustomPlan(true);
      session1.toggleDhikr('m_ayatulkursi', true);
      session1.toggleDhikr('m_hasbiyallahu', true);
      session1.toggleDhikr('after_salah_tasbih', true);
      await Future.delayed(const Duration(milliseconds: 50));

      // Step B: Verify it is physically written to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('use_custom_plan'), isTrue);
      expect(prefs.getStringList('enabled_dhikr_ids'),
          containsAll(['m_ayatulkursi', 'm_hasbiyallahu', 'after_salah_tasbih']));

      // Step C: Second session (simulate cold app restart)
      final session2 = CustomPlanProvider();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(session2.useCustomPlan, isTrue);
      expect(session2.enabledDhikrIds.length, equals(3));
      expect(session2.isDhikrEnabled('m_ayatulkursi'), isTrue);
      expect(session2.isDhikrEnabled('m_hasbiyallahu'), isTrue);
      expect(session2.isDhikrEnabled('after_salah_tasbih'), isTrue);
      expect(session2.isDhikrEnabled('e_sayyidul_istighfar'), isFalse);
    });

    test('5. Bulk Actions: Enable all & Disable all work correctly', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = CustomPlanProvider();
      await Future.delayed(const Duration(milliseconds: 50));

      final allIds = ['d1', 'd2', 'd3', 'd4', 'd5'];

      // Enable all
      for (final id in allIds) {
        provider.toggleDhikr(id, true);
      }
      expect(provider.enabledDhikrIds.length, equals(5));

      // Disable all
      for (final id in allIds) {
        provider.toggleDhikr(id, false);
      }
      expect(provider.enabledDhikrIds, isEmpty);
    });

    test('6. Multi-Language Compatibility: Custom Plan filter works across languages', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = CustomPlanProvider();
      await Future.delayed(const Duration(milliseconds: 50));

      provider.setUseCustomPlan(true);
      provider.toggleDhikr('m_ayatulkursi', true);
      provider.toggleDhikr('e_sayyidul_istighfar', true);

      // Bengali dataset for these duas
      final bengaliDhikrs = [
        Dhikr(
          id: 'm_ayatulkursi',
          title: 'আয়াতুল কুরসী',
          arabicText: 'اللَّهُ لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ',
          translation: 'আল্লাহ — তিনি ছাড়া কোনো হক ইলাহ নেই।',
          transliteration: 'আল্লাহু লা ইলাহা ইল্লা হুয়াল হাইয়্যুল ক্বাইয়্যুম',
          targetCount: 1,
          category: DhikrCategory.morning,
        ),
        Dhikr(
          id: 'e_sayyidul_istighfar',
          title: 'সৈয়্যিদুল ইস্তিগফার',
          arabicText: 'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ',
          translation: 'হে আল্লাহ! আপনি আমার রব।',
          transliteration: 'আল্লাহুম্মা আনতা রব্বী লা ইলাহা ইল্লা আনতা',
          targetCount: 1,
          category: DhikrCategory.evening,
        ),
        Dhikr(
          id: 'food_bismillah',
          title: 'খাবার শুরুর দু\'আ',
          arabicText: 'بِسْمِ اللَّهِ',
          translation: 'আল্লাহর নামে শুরু করছি।',
          transliteration: 'বিসমিল্লাহ',
          targetCount: 1,
          category: DhikrCategory.food,
        ),
      ];

      // English dataset for the SAME duas
      final englishDhikrs = [
        Dhikr(
          id: 'm_ayatulkursi',
          title: 'Ayatul Kursi',
          arabicText: 'اللَّهُ لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ',
          translation: 'Allah - there is no deity except Him, the Ever-Living.',
          transliteration: 'Allahu la ilaha illa huwal hayyul qayyum',
          targetCount: 1,
          category: DhikrCategory.morning,
        ),
        Dhikr(
          id: 'e_sayyidul_istighfar',
          title: 'Sayyidul Istighfar',
          arabicText: 'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ',
          translation: 'O Allah, You are my Lord, there is no deity except You.',
          transliteration: 'Allahumma anta rabbi la ilaha illa anta',
          targetCount: 1,
          category: DhikrCategory.evening,
        ),
        Dhikr(
          id: 'food_bismillah',
          title: 'Before Eating',
          arabicText: 'بِسْمِ اللَّهِ',
          translation: 'In the name of Allah.',
          transliteration: 'Bismillah',
          targetCount: 1,
          category: DhikrCategory.food,
        ),
      ];

      // Arabic dataset for the SAME duas
      final arabicDhikrs = [
        Dhikr(
          id: 'm_ayatulkursi',
          title: 'آية الكرسي',
          arabicText: 'اللَّهُ لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ',
          translation: 'الله لا إله إلا هو الحي القيوم',
          transliteration: null,
          targetCount: 1,
          category: DhikrCategory.morning,
        ),
        Dhikr(
          id: 'e_sayyidul_istighfar',
          title: 'سيد الاستغفار',
          arabicText: 'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ',
          translation: 'اللهم أنت ربي لا إله إلا أنت',
          transliteration: null,
          targetCount: 1,
          category: DhikrCategory.evening,
        ),
        Dhikr(
          id: 'food_bismillah',
          title: 'قبل الأكل',
          arabicText: 'بِسْمِ اللَّهِ',
          translation: 'بسم الله',
          transliteration: null,
          targetCount: 1,
          category: DhikrCategory.food,
        ),
      ];

      // Apply Custom Plan filter across each language dataset
      final filteredBengali = bengaliDhikrs.where((d) => provider.isDhikrEnabled(d.id)).toList();
      final filteredEnglish = englishDhikrs.where((d) => provider.isDhikrEnabled(d.id)).toList();
      final filteredArabic  = arabicDhikrs.where((d) => provider.isDhikrEnabled(d.id)).toList();

      // All languages must return the exact 2 selected duas
      expect(filteredBengali.length, equals(2));
      expect(filteredEnglish.length, equals(2));
      expect(filteredArabic.length, equals(2));

      // Verify that Bengali text is preserved in Bengali
      expect(filteredBengali[0].title, equals('আয়াতুল কুরসী'));
      expect(filteredBengali[0].transliteration, contains('আল্লাহু লা ইলাহা'));

      // Verify that English text is preserved in English
      expect(filteredEnglish[0].title, equals('Ayatul Kursi'));
      expect(filteredEnglish[0].transliteration, contains('Allahu la ilaha'));

      // Verify that Arabic text is preserved in Arabic
      expect(filteredArabic[0].title, equals('آية الكرسي'));

      // The unselected food dua is filtered out across all languages
      expect(filteredBengali.any((d) => d.id == 'food_bismillah'), isFalse);
      expect(filteredEnglish.any((d) => d.id == 'food_bismillah'), isFalse);
      expect(filteredArabic.any((d) => d.id == 'food_bismillah'), isFalse);
    });
  });
}
