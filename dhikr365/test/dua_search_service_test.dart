import 'package:flutter_test/flutter_test.dart';
import 'package:dhikr365/models/dhikr.dart';
import 'package:dhikr365/services/dua_search_service.dart';

void main() {
  group('DuaSearchService Unit Tests', () {
    final sampleDhikrs = [
      Dhikr(
        id: 'm_ayatulkursi',
        title: 'আয়াতুল কুরসী (আরশের আয়াত)',
        arabicText: 'اللَّهُ لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ',
        translation: 'আল্লাহ — তিনি ছাড়া কোনো হক ইলাহ নেই। তিনি চিরঞ্জীব, সর্বসত্তার ধারক। তাঁর কুরসী আসমানসমূহ ও যমীনকে পরিব্যাপ্ত করে আছে।',
        transliteration: 'Allahu la ilaha illa huwal hayyul qayyum',
        benefit: 'যে ব্যক্তি সকাল-সন্ধ্যায় এটি পড়বে সে সারা দিন-রাত জিন ও শয়তান থেকে রক্ষা পাবে।',
        reference: 'Surah Al-Baqarah: 255',
        targetCount: 1,
        category: DhikrCategory.morning,
      ),
      Dhikr(
        id: 'e_sayyidul_istighfar',
        title: 'সৈয়্যিদুল ইস্তিগফার (তওবার শ্রেষ্ঠ দু\'আ)',
        arabicText: 'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ خَلَقْتَنِي',
        translation: 'হে আল্লাহ! আপনি আমার রব, আপনি ছাড়া কোনো সত্য উপাস্য নেই। আমি আমার গুনাহের ক্ষমা চাচ্ছি।',
        transliteration: 'Allahumma anta rabbi la ilaha illa anta',
        benefit: 'যে ব্যক্তি সন্ধ্যার সময় দৃঢ় বিশ্বাসের সাথে এটি পড়বে এবং সে রাতে মারা যাবে, সে জান্নাতীদের অন্তর্ভুক্ত হবে।',
        reference: 'Sahih Bukhari: 6306',
        targetCount: 1,
        category: DhikrCategory.evening,
      ),
      Dhikr(
        id: 'food_bismillah',
        title: 'খাবার শুরুর দু\'আ',
        arabicText: 'بِسْمِ اللَّهِ',
        translation: 'আল্লাহর নামে শুরু করছি।',
        transliteration: 'Bismillah',
        benefit: 'খাবার খাওয়ার পূর্বে পাঠ করতে হয়।',
        reference: 'Abu Dawud: 3767',
        targetCount: 1,
        category: DhikrCategory.food,
      ),
      Dhikr(
        id: 'distress_debt',
        title: 'পাহাড়সমান ঋণ মুক্তির দু\'আ',
        arabicText: 'اللَّهُمَّ اكْفِنِي بِحَلَالِكَ عَنْ حَرَامِكَ',
        translation: 'হে আল্লাহ! আমাকে আপনার হালাল রিজিক দিয়ে তৃপ্ত করুন এবং ঋণ পরিশোধের তৌফিক দিন।',
        transliteration: 'Allahummak-fini bihalalika an haramik',
        benefit: 'পাহাড় সমান ঋণ থাকলেও আল্লাহ তা পরিশোধের ব্যবস্থা করে দেন।',
        reference: 'Tirmidhi: 3563',
        targetCount: 1,
        category: DhikrCategory.distress,
      ),
      Dhikr(
        id: 'sleep_bedtime',
        title: 'ঘুমানোর দু\'আ',
        arabicText: 'بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا',
        translation: 'হে আল্লাহ! আপনারই নামে আমি মৃত্যুবরণ করছি (ঘুমাচ্ছি) এবং জীবিত হচ্ছি।',
        transliteration: 'Bismikallahumma amutu wa ahya',
        benefit: 'রাত্রে বিছানায় ঘুমানোর পূর্বে পাঠ করার সুন্নাত।',
        reference: 'Sahih Bukhari: 6324',
        targetCount: 1,
        category: DhikrCategory.beforeSleep,
      ),
    ];

    test('Searches by Bengali title: আয়াতুল কুরসী', () {
      final res = DuaSearchService.search(allDhikrs: sampleDhikrs, query: 'আয়াতুল কুরসী');
      expect(res.isNotEmpty, isTrue);
      expect(res.first.dhikr.id, 'm_ayatulkursi');
    });

    test('Searches by English transliteration alias: ayatul kursi', () {
      final res = DuaSearchService.search(allDhikrs: sampleDhikrs, query: 'ayatul kursi');
      expect(res.isNotEmpty, isTrue);
      expect(res.first.dhikr.id, 'm_ayatulkursi');
    });

    test('Searches by unvocalized Arabic: لا اله الا الله', () {
      final res = DuaSearchService.search(allDhikrs: sampleDhikrs, query: 'لا اله الا الله');
      expect(res.isNotEmpty, isTrue);
      expect(res.any((r) => r.dhikr.id == 'm_ayatulkursi'), isTrue);
    });

    test('Searches by topic/meaning: ঋণ (debt)', () {
      final res = DuaSearchService.search(allDhikrs: sampleDhikrs, query: 'ঋণ');
      expect(res.isNotEmpty, isTrue);
      expect(res.first.dhikr.id, 'distress_debt');
    });

    test('Searches by English keyword alias: debt', () {
      final res = DuaSearchService.search(allDhikrs: sampleDhikrs, query: 'debt');
      expect(res.isNotEmpty, isTrue);
      expect(res.first.dhikr.id, 'distress_debt');
    });

    test('Searches by concept: ক্ষমা (forgiveness)', () {
      final res = DuaSearchService.search(allDhikrs: sampleDhikrs, query: 'ক্ষমা');
      expect(res.isNotEmpty, isTrue);
      expect(res.first.dhikr.id, 'e_sayyidul_istighfar');
    });

    test('Searches by English alias: forgiveness', () {
      final res = DuaSearchService.search(allDhikrs: sampleDhikrs, query: 'forgiveness');
      expect(res.isNotEmpty, isTrue);
      expect(res.first.dhikr.id, 'e_sayyidul_istighfar');
    });

    test('Searches by occasion: ঘুম (sleep)', () {
      final res = DuaSearchService.search(allDhikrs: sampleDhikrs, query: 'ঘুম');
      expect(res.isNotEmpty, isTrue);
      expect(res.first.dhikr.id, 'sleep_bedtime');
    });

    test('Searches by English alias: sleep', () {
      final res = DuaSearchService.search(allDhikrs: sampleDhikrs, query: 'sleep');
      expect(res.isNotEmpty, isTrue);
      expect(res.first.dhikr.id, 'sleep_bedtime');
    });

    test('Searches by food: খাবার', () {
      final res = DuaSearchService.search(allDhikrs: sampleDhikrs, query: 'খাবার');
      expect(res.isNotEmpty, isTrue);
      expect(res.first.dhikr.id, 'food_bismillah');
    });

    test('Searches by Hadith reference: 255', () {
      final res = DuaSearchService.search(allDhikrs: sampleDhikrs, query: '255');
      expect(res.isNotEmpty, isTrue);
      expect(res.first.dhikr.id, 'm_ayatulkursi');
    });
  });
}
