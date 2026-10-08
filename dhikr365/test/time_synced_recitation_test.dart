import 'package:flutter_test/flutter_test.dart';
import 'package:dhikr365/models/dhikr.dart';
import 'package:dhikr365/models/dua_timestamp.dart';
import 'package:dhikr365/services/dua_timestamp_registry.dart';

void main() {
  group('Time-Synced Recitation Engine Tests', () {
    test('1. DuaSegment isActive calculates playback window accurately', () {
      const segment = DuaSegment(
        startMs: 1000,
        endMs: 3500,
        arabic: 'سُبْحَانَ اللَّهِ',
      );

      expect(segment.isActive(500), isFalse);
      expect(segment.isActive(1000), isTrue); // inclusive start
      expect(segment.isActive(2200), isTrue);
      expect(segment.isActive(3499), isTrue);
      expect(segment.isActive(3500), isFalse); // exclusive end
      expect(segment.isActive(4000), isFalse);
    });

    test('2. DuaTimestampRegistry returns valid segments for core duas', () {
      final ayatulKursi = DuaTimestampRegistry.getSegments('morning_m_ayatulkursi');
      expect(ayatulKursi, isNotNull);
      expect(ayatulKursi!.length, 9);
      expect(ayatulKursi.first.arabic.contains('اللَّهُ لَا إِلَٰهَ'), isTrue);

      final sayyidul = DuaTimestampRegistry.getSegments('m_sayyidul_istighfar');
      expect(sayyidul, isNotNull);
      expect(sayyidul!.length, 7);
      expect(sayyidul.first.arabic.contains('اللَّهُمَّ أَنْتَ رَبِّي'), isTrue);

      final ikhlas = DuaTimestampRegistry.getSegments('salah_ikhlas');
      expect(ikhlas, isNotNull);
      expect(ikhlas!.length, 4);

      final falaq = DuaTimestampRegistry.getSegments('evening_e_falaq');
      expect(falaq, isNotNull);
      expect(falaq!.length, 5);

      final nas = DuaTimestampRegistry.getSegments('sleep_nas');
      expect(nas, isNotNull);
      expect(nas!.length, 6);
    });

    test('3. Dhikr model resolves timestamps seamlessly', () {
      final dhikrWithSync = Dhikr(
        id: 'morning_m_ayatulkursi',
        title: 'Ayatul Kursi',
        arabicText: 'اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ',
        translation: 'Allah! There is no deity except Him...',
        targetCount: 1,
        category: DhikrCategory.morning,
        audioPath: 'audio/morning_m_ayatulkursi.mp3',
      );

      expect(dhikrWithSync.hasTimestamps, isTrue);
      expect(dhikrWithSync.resolvedTimestamps, isNotNull);
      expect(dhikrWithSync.resolvedTimestamps!.length, 9);

      final plainDhikr = Dhikr(
        id: 'custom_generic_dua',
        title: 'Generic Dua',
        arabicText: 'الحمد لله',
        translation: 'Praise be to Allah',
        targetCount: 33,
        category: DhikrCategory.focus,
      );

      expect(plainDhikr.hasTimestamps, isFalse);
      expect(plainDhikr.resolvedTimestamps, isNull);
    });

    test('4. Timestamps segments are strictly sequential without gaps or overlaps', () {
      final segments = DuaTimestampRegistry.getSegments('sayyidul_istighfar')!;
      for (int i = 0; i < segments.length - 1; i++) {
        expect(segments[i].endMs, lessThanOrEqualTo(segments[i + 1].startMs));
      }
    });

    test('5. Smart proportional segmentation generates natural segments for unmapped audio duas', () {
      final unmappedAudioDhikr = Dhikr(
        id: 'food_bismillah_custom',
        title: 'Eating Supplication',
        arabicText: 'بِسْمِ اللَّهِ۔ اللَّهُمَّ بَارِكْ لَنَا فِيهِ۔ وَأَطْعِمْنَا خَيْرًا مِنْهُ۔',
        translation: 'In the name of Allah. O Allah, bless it for us and feed us better than it.',
        targetCount: 1,
        category: DhikrCategory.food,
        audioPath: 'audio/food.mp3',
      );

      expect(unmappedAudioDhikr.hasTimestamps, isTrue);
      final generated = unmappedAudioDhikr.resolvedTimestamps;
      expect(generated, isNotNull);
      expect(generated!.length, greaterThanOrEqualTo(2));
      expect(generated.first.startMs, equals(0));
      expect(generated.last.endMs, equals(15000));
    });

    test('6. Hasbiyallah resolves with accurate audio timestamps and cached instance', () {
      final hasbiyallah = Dhikr(
        id: 'morning_m_hasbiyallah',
        title: 'Hasbiyallah',
        arabicText: 'حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ',
        translation: 'Allah is sufficient for me...',
        targetCount: 7,
        category: DhikrCategory.morning,
        audioPath: 'audio/morning_m_hasbiyallah.mp3',
      );

      expect(hasbiyallah.hasTimestamps, isTrue);
      final segs1 = hasbiyallah.resolvedTimestamps;
      expect(segs1, isNotNull);
      expect(segs1!.length, 3);
      expect(segs1.last.endMs, equals(17760));

      // Must return identical cached list instance to avoid GlobalKey thrashing
      final segs2 = hasbiyallah.resolvedTimestamps;
      expect(identical(segs1, segs2), isTrue);
    });
  });
}
