// ============================================================================
// lib/services/dua_timestamp_registry.dart
//
// REGISTRY FOR TIME-SYNCED AUDIO RECITATION TIMESTAMPS
//
// Maps Dhikr IDs to their precise phrase-by-phrase timestamps.
// Supports both full composite IDs (e.g. morning_m_ayatulkursi)
// and normalized base keys (e.g. m_ayatulkursi, ayatul_kursi).
// ============================================================================

import '../models/dua_timestamp.dart';

class DuaTimestampRegistry {
  static final Map<String, List<DuaSegment>> _registry = {
    // ── Ayatul Kursi (51.92s Audio Match) ──────────────────────────────────
    'ayatulkursi': const [
      DuaSegment(
        startMs: 0,
        endMs: 8050,
        arabic: 'اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ',
        translation: 'Allah! There is no deity except Him, the Ever-Living, the Sustainer of existence.',
      ),
      DuaSegment(
        startMs: 8050,
        endMs: 13800,
        arabic: 'لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ',
        translation: 'Neither drowsiness overtakes Him nor sleep.',
      ),
      DuaSegment(
        startMs: 13800,
        endMs: 18150,
        arabic: 'لَّهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ',
        translation: 'To Him belongs whatever is in the heavens and whatever is on the earth.',
      ),
      DuaSegment(
        startMs: 18150,
        endMs: 25850,
        arabic: 'مَن ذَا الَّذِي يَشْفَعُ عِندَهُ إِلَّا بِإِذْنِهِ',
        translation: 'Who is it that can intercede with Him except by His permission?',
      ),
      DuaSegment(
        startMs: 25850,
        endMs: 31400,
        arabic: 'يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ',
        translation: 'He knows what is before them and what will be after them,',
      ),
      DuaSegment(
        startMs: 31400,
        endMs: 40050,
        arabic: 'وَلَا يُحِيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلَّا بِمَا شَاءَ',
        translation: 'and they encompass not a thing of His knowledge except for what He wills.',
      ),
      DuaSegment(
        startMs: 40050,
        endMs: 44400,
        arabic: 'وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ',
        translation: 'His Kursi extends over the heavens and the earth,',
      ),
      DuaSegment(
        startMs: 44400,
        endMs: 47800,
        arabic: 'وَلَا يَئُودُهُ حِفْظُهُمَا',
        translation: 'and their preservation tires Him not.',
      ),
      DuaSegment(
        startMs: 47800,
        endMs: 51920,
        arabic: 'وَهُوَ الْعَلِيُّ الْعَظِيمُ',
        translation: 'And He is the Most High, the Most Great.',
      ),
    ],

    // ── Hasbiyallah (17.76s Audio Match) ────────────────────────────────────
    'hasbiyallah': const [
      DuaSegment(
        startMs: 0,
        endMs: 6700,
        arabic: 'حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ',
        translation: 'Allah is sufficient for me; there is no deity except Him.',
        transliteration: 'Hasbiyallahu la ilaha illa Huwa',
      ),
      DuaSegment(
        startMs: 6700,
        endMs: 11350,
        arabic: 'عَلَيْهِ تَوَكَّلْتُ',
        translation: 'Upon Him I have relied,',
        transliteration: "'alayhi tawakkaltu",
      ),
      DuaSegment(
        startMs: 11350,
        endMs: 17760,
        arabic: 'وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ',
        translation: 'and He is the Lord of the Great Throne.',
        transliteration: "wa Huwa Rabbul-'Arshil-'Azim",
      ),
    ],

    // ── Sayyidul Istighfar (26.96s Audio Match) ─────────────────────────────
    'sayyidul_istighfar': const [
      DuaSegment(
        startMs: 0,
        endMs: 4800,
        arabic: 'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ',
        translation: 'O Allah, You are my Lord, there is no deity except You.',
      ),
      DuaSegment(
        startMs: 4800,
        endMs: 8200,
        arabic: 'خَلَقْتَنِي وَأَنَا عَبْدُكَ',
        translation: 'You created me and I am Your servant.',
      ),
      DuaSegment(
        startMs: 8200,
        endMs: 12750,
        arabic: 'وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ',
        translation: 'I am upon Your covenant and promise as best I can.',
      ),
      DuaSegment(
        startMs: 12750,
        endMs: 16200,
        arabic: 'أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ',
        translation: 'I seek refuge in You from the evil of what I have done.',
      ),
      DuaSegment(
        startMs: 16200,
        endMs: 19100,
        arabic: 'أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ',
        translation: 'I acknowledge before You Your blessing upon me,',
      ),
      DuaSegment(
        startMs: 19100,
        endMs: 21600,
        arabic: 'وَأَبُوءُ بِذَنْبِي فَاغْفِرْ لِي',
        translation: 'and I acknowledge my sin. So forgive me,',
      ),
      DuaSegment(
        startMs: 21600,
        endMs: 26960,
        arabic: 'فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ',
        translation: 'for indeed none forgives sins except You.',
      ),
    ],

    // ── Surah Al-Ikhlas (13.12s Audio Match) ─────────────────────────────────
    'ikhlas': const [
      DuaSegment(
        startMs: 0,
        endMs: 2850,
        arabic: 'قُلْ هُوَ اللَّهُ أَحَدٌ',
        translation: 'Say: He is Allah, [who is] One,',
      ),
      DuaSegment(
        startMs: 2850,
        endMs: 5350,
        arabic: 'اللَّهُ الصَّمَدُ',
        translation: 'Allah, the Eternal Refuge.',
      ),
      DuaSegment(
        startMs: 5350,
        endMs: 8250,
        arabic: 'لَمْ يَلِدْ وَلَمْ يُولَدْ',
        translation: 'He neither begets nor is born,',
      ),
      DuaSegment(
        startMs: 8250,
        endMs: 13120,
        arabic: 'وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ',
        translation: 'Nor is there to Him any equivalent.',
      ),
    ],

    // ── Surah Al-Falaq (23.57s Audio Match) ──────────────────────────────────
    'falaq': const [
      DuaSegment(
        startMs: 0,
        endMs: 3350,
        arabic: 'قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ',
        translation: 'Say: I seek refuge in the Lord of daybreak',
      ),
      DuaSegment(
        startMs: 3350,
        endMs: 6950,
        arabic: 'مِن شَرِّ مَا خَلَقَ',
        translation: 'From the evil of that which He created',
      ),
      DuaSegment(
        startMs: 6950,
        endMs: 11950,
        arabic: 'وَمِن شَرِّ غَاسِقٍ إِذَا وَقَبَ',
        translation: 'And from the evil of darkness when it settles',
      ),
      DuaSegment(
        startMs: 11950,
        endMs: 17900,
        arabic: 'وَمِن شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ',
        translation: 'And from the evil of the blowers in knots',
      ),
      DuaSegment(
        startMs: 17900,
        endMs: 23570,
        arabic: 'وَمِن شَرِّ حَاسِدٍ إِذَا حَسَدَ',
        translation: 'And from the evil of an envier when he envies.',
      ),
    ],

    // ── Surah An-Nas (40.56s Audio Match) ────────────────────────────────────
    'nas': const [
      DuaSegment(
        startMs: 0,
        endMs: 6000,
        arabic: 'قُلْ أَعُوذُ بِرَبِّ النَّاسِ',
        translation: 'Say: I seek refuge in the Lord of mankind,',
      ),
      DuaSegment(
        startMs: 6000,
        endMs: 11250,
        arabic: 'مَلِكِ النَّاسِ',
        translation: 'The Sovereign of mankind,',
      ),
      DuaSegment(
        startMs: 11250,
        endMs: 16550,
        arabic: 'إِلَهِ النَّاسِ',
        translation: 'The God of mankind,',
      ),
      DuaSegment(
        startMs: 16550,
        endMs: 24450,
        arabic: 'مِن شَرِّ الْوَسْوَاسِ الْخَنَّاسِ',
        translation: 'From the evil of the retreating whisperer',
      ),
      DuaSegment(
        startMs: 24450,
        endMs: 32350,
        arabic: 'الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ',
        translation: 'Who whispers in the breasts of mankind',
      ),
      DuaSegment(
        startMs: 32350,
        endMs: 40560,
        arabic: 'مِنَ الْجِنَّةِ وَالنَّاسِ',
        translation: 'From among the jinn and mankind.',
      ),
    ],

    // ── Bismillah Protection (9.00s Audio Match) ────────────────────────────
    'bismillah_la_yadurr': const [
      DuaSegment(
        startMs: 0,
        endMs: 6650,
        arabic: 'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ',
        translation: 'In the name of Allah, with whose name nothing can cause harm on earth or in the heavens,',
      ),
      DuaSegment(
        startMs: 6650,
        endMs: 9000,
        arabic: 'وَهُوَ السَّمِيعُ الْعَلِيمُ',
        translation: 'and He is the All-Hearing, the All-Knowing.',
      ),
    ],

    // ── Dua of Yunus (Distress / Anguish 7.00s Audio Match) ─────────────────
    'anguish_yunus': const [
      DuaSegment(
        startMs: 0,
        endMs: 2200,
        arabic: 'لَا إِلَهَ إِلَّا أَنْتَ',
        translation: 'There is no deity except You,',
      ),
      DuaSegment(
        startMs: 2200,
        endMs: 3800,
        arabic: 'سُبْحَانَكَ',
        translation: 'exalted are You!',
      ),
      DuaSegment(
        startMs: 3800,
        endMs: 7000,
        arabic: 'إِنِّي كُنْتُ مِنَ الظَّالِمِينَ',
        translation: 'Indeed, I have been of the wrongdoers.',
      ),
    ],

    // ── Subhanallah wa Bihamdihi ────────────────────────────────────────────
    'subhanallah_bihamdihi': const [
      DuaSegment(
        startMs: 0,
        endMs: 1800,
        arabic: 'سُبْحَانَ اللَّهِ',
        translation: 'Glory be to Allah,',
      ),
      DuaSegment(
        startMs: 1800,
        endMs: 3900,
        arabic: 'وَبِحَمْدِهِ',
        translation: 'and praise be to Him.',
      ),
    ],

    // ── Ya Hayyu Ya Qayyum (15.00s Audio Match) ─────────────────────────────
    'ya_hayyu_ya_qayyum': const [
      DuaSegment(
        startMs: 0,
        endMs: 4350,
        arabic: 'يَا حَيُّ يَا قَيُّومُ بِرَحْمَتِكَ أَسْتَغِيثُ',
        translation: 'O Ever-Living, O Sustainer, by Your mercy I seek assistance;',
      ),
      DuaSegment(
        startMs: 4350,
        endMs: 7450,
        arabic: 'أَصْلِحْ لِي شَأْنِي كُلَّهُ',
        translation: 'rectify for me all of my affairs,',
      ),
      DuaSegment(
        startMs: 7450,
        endMs: 10950,
        arabic: 'وَلَا تَكِلْنِي إِلَى نَفْسِي',
        translation: 'and do not leave me to myself',
      ),
      DuaSegment(
        startMs: 10950,
        endMs: 15000,
        arabic: 'طَرْفَةَ عَيْنٍ',
        translation: 'even for the blink of an eye.',
      ),
    ],

    // ── Radhitu Billah (9.75s Audio Match) ──────────────────────────────────
    'radhitu_billah': const [
      DuaSegment(
        startMs: 0,
        endMs: 3000,
        arabic: 'رَضِيتُ بِاللَّهِ رَبًّا',
        translation: 'I am pleased with Allah as my Lord,',
      ),
      DuaSegment(
        startMs: 3000,
        endMs: 5850,
        arabic: 'وَبِالْإِسْلَامِ دِينًا',
        translation: 'and with Islam as my religion,',
      ),
      DuaSegment(
        startMs: 5850,
        endMs: 9750,
        arabic: 'وَبِمُحَمَّدٍ نَبِيًّا',
        translation: 'and with Muhammad as my Prophet.',
      ),
    ],

    // ── Allahumma Bika Asbahna (12.00s Audio Match) ─────────────────────────
    'allahumma_bika_asbahna': const [
      DuaSegment(
        startMs: 0,
        endMs: 4150,
        arabic: 'اللَّهُمَّ بِكَ أَصْبَحْنَا وَبِكَ أَمْسَيْنَا',
        translation: 'O Allah, by You we enter the morning and by You we enter the evening,',
      ),
      DuaSegment(
        startMs: 4150,
        endMs: 6550,
        arabic: 'وَبِكَ نَحْيَا',
        translation: 'and by You we live,',
      ),
      DuaSegment(
        startMs: 6550,
        endMs: 9900,
        arabic: 'وَبِكَ نَمُوتُ',
        translation: 'and by You we die,',
      ),
      DuaSegment(
        startMs: 9900,
        endMs: 12000,
        arabic: 'وَإِلَيْكَ النُّشُورُ',
        translation: 'and to You is the resurrection.',
      ),
    ],

    // ── Allahumma Afini (27.00s Audio Match) ────────────────────────────────
    'allahumma_afini': const [
      DuaSegment(
        startMs: 0,
        endMs: 3950,
        arabic: 'اللَّهُمَّ عَافِنِي فِي بَدَنِي',
        translation: 'O Allah, grant my body health.',
      ),
      DuaSegment(
        startMs: 3950,
        endMs: 7150,
        arabic: 'اللَّهُمَّ عَافِنِي فِي سَمْعِي',
        translation: 'O Allah, grant my hearing health.',
      ),
      DuaSegment(
        startMs: 7150,
        endMs: 10900,
        arabic: 'اللَّهُمَّ عَافِنِي فِي بَصَرِي',
        translation: 'O Allah, grant my sight health.',
      ),
      DuaSegment(
        startMs: 10900,
        endMs: 15100,
        arabic: 'لَا إِلَهَ إِلَّا أَنْتَ',
        translation: 'There is no deity except You.',
      ),
      DuaSegment(
        startMs: 15100,
        endMs: 20050,
        arabic: 'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْكُفْرِ وَالْفَقْرِ',
        translation: 'O Allah, I seek refuge in You from disbelief and poverty.',
      ),
      DuaSegment(
        startMs: 20050,
        endMs: 23700,
        arabic: 'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنْ عَذَابِ الْقَبْرِ',
        translation: 'O Allah, I seek refuge in You from the punishment of the grave.',
      ),
      DuaSegment(
        startMs: 23700,
        endMs: 27000,
        arabic: 'لَا إِلَهَ إِلَّا أَنْتَ',
        translation: 'There is no deity except You.',
      ),
    ],

    // ── Subhanallah wa Bihamdihi 3 (11.00s Audio Match) ─────────────────────
    'subhanallah_bihamdihi_3': const [
      DuaSegment(
        startMs: 0,
        endMs: 3100,
        arabic: 'سُبْحَانَ اللهِ وَبِحَمْدِهِ',
        translation: 'Glory be to Allah and praise be to Him,',
      ),
      DuaSegment(
        startMs: 3100,
        endMs: 5100,
        arabic: 'عَدَدَ خَلْقِهِ',
        translation: 'as many times as the number of His creation,',
      ),
      DuaSegment(
        startMs: 5100,
        endMs: 7400,
        arabic: 'وَرِضَا نَفْسِهِ',
        translation: 'and according to the pleasure of His Self,',
      ),
      DuaSegment(
        startMs: 7400,
        endMs: 9500,
        arabic: 'وَزِنَةَ عَرْشِهِ',
        translation: 'and equal to the weight of His Throne,',
      ),
      DuaSegment(
        startMs: 9500,
        endMs: 11000,
        arabic: 'وَمِدَادَ كَلِمَاتِهِ',
        translation: 'and equal to the ink that may be used in recording the words for His Praise.',
      ),
    ],

    // ── Asbahna wa Asbahal Mulku (41.00s Audio Match) ───────────────────────
    'asbahna_wal_mulku': const [
      DuaSegment(
        startMs: 0,
        endMs: 4750,
        arabic: 'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ',
        translation: 'We have entered the morning and the kingdom belongs to Allah,',
      ),
      DuaSegment(
        startMs: 4750,
        endMs: 7150,
        arabic: 'وَالْحَمْدُ لِلَّهِ',
        translation: 'and all praise is due to Allah.',
      ),
      DuaSegment(
        startMs: 7150,
        endMs: 12200,
        arabic: 'لَا إِلَهَ إِلَّا اللهُ وَحْدَهُ لَا شَرِيكَ لَهُ',
        translation: 'There is no deity except Allah alone, with no partner.',
      ),
      DuaSegment(
        startMs: 12200,
        endMs: 18100,
        arabic: 'لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
        translation: 'To Him belongs dominion, and to Him belongs praise, and He is over all things omnipotent.',
      ),
      DuaSegment(
        startMs: 18100,
        endMs: 24000,
        arabic: 'رَبِّ أَسْأَلُكَ خَيْرَ مَا فِي هَذَا الْيَوْمِ وَخَيْرَ مَا بَعْدَهُ',
        translation: 'My Lord, I ask You for the good of what is in this day and the good of what follows it,',
      ),
      DuaSegment(
        startMs: 24000,
        endMs: 30150,
        arabic: 'وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فِي هَذَا الْيَوْمِ وَشَرِّ مَا بَعْدَهُ',
        translation: 'and I seek refuge in You from the evil of what is in this day and the evil of what follows it.',
      ),
      DuaSegment(
        startMs: 30150,
        endMs: 36050,
        arabic: 'رَبِّ أَعُوذُ بِكَ مِنَ الْكَسَلِ وَسُوءِ الْكِبَرِ',
        translation: 'My Lord, I seek refuge in You from laziness and the hardships of old age.',
      ),
      DuaSegment(
        startMs: 36050,
        endMs: 41000,
        arabic: 'رَبِّ أَعُوذُ بِكَ مِنْ عَذَابٍ فِي النَّارِ وَعَذَابٍ فِي الْقَبْرِ',
        translation: 'My Lord, I seek refuge in You from punishment in the Fire and punishment in the grave.',
      ),
    ],
  };

  /// Normalizes arbitrary dhikr IDs (e.g. morning_m_ayatulkursi or salah_ayatul_kursi)
  /// to its base key in the registry.
  static String? _normalizeKey(String id) {
    if (_registry.containsKey(id)) return id;
    final clean = id.toLowerCase().replaceAll('_', '').replaceAll('-', '');
    for (final key in _registry.keys) {
      final cleanKey = key.toLowerCase().replaceAll('_', '').replaceAll('-', '');
      if (clean == cleanKey) return key;
    }
    String? bestKey;
    int bestLength = 0;
    for (final key in _registry.keys) {
      final cleanKey = key.toLowerCase().replaceAll('_', '').replaceAll('-', '');
      if (clean.contains(cleanKey)) {
        if (cleanKey.length > bestLength) {
          bestKey = key;
          bestLength = cleanKey.length;
        }
      }
    }
    return bestKey;
  }

  /// Returns true if explicit handcrafted timestamps exist for this dhikr ID.
  static bool hasTimestamps(String id) {
    return _normalizeKey(id) != null;
  }

  /// Returns the timed segments for [id], or null if unmapped.
  static List<DuaSegment>? getSegments(String id) {
    final key = _normalizeKey(id);
    if (key == null) return null;
    return _registry[key];
  }

  /// Generates natural, proportional segments for any arbitrary Arabic dua text.
  /// Used as an intelligent fallback so 100% of audio duas have real-time
  /// synced highlighting even without manual timestamp files.
  ///
  /// CRITICAL GUARANTEE: Does NOT alter, reword, or mutate the original text.
  static List<DuaSegment> generateProportionalSegments({
    required String arabicText,
    String? translation,
    String? transliteration,
    int totalDurationMs = 15000,
  }) {
    if (arabicText.trim().isEmpty) return const [];

    // 1. Natural segmentation: split by Arabic full stops, commas, semicolons, or newlines
    final delimiterRegex = RegExp(r'([۔\.\n!؛،,]+)');
    final matches = delimiterRegex.allMatches(arabicText);

    List<String> rawParts = [];
    if (matches.isNotEmpty) {
      int lastEnd = 0;
      for (final m in matches) {
        final phrase = arabicText.substring(lastEnd, m.end).trim();
        if (phrase.isNotEmpty) {
          rawParts.add(phrase);
        }
        lastEnd = m.end;
      }
      if (lastEnd < arabicText.length) {
        final remaining = arabicText.substring(lastEnd).trim();
        if (remaining.isNotEmpty) rawParts.add(remaining);
      }
    } else {
      // No punctuation found: if long (> 90 chars), split by word count (~8-12 words per phrase)
      final words = arabicText.trim().split(RegExp(r'\s+'));
      if (words.length > 8) {
        const chunkSize = 7;
        for (int i = 0; i < words.length; i += chunkSize) {
          final end =
              (i + chunkSize < words.length) ? i + chunkSize : words.length;
          rawParts.add(words.sublist(i, end).join(' '));
        }
      } else {
        rawParts = [arabicText.trim()];
      }
    }

    if (rawParts.isEmpty) {
      rawParts = [arabicText.trim()];
    }

    // 2. Proportional time calculation based on character length
    final totalChars = rawParts.fold<int>(0, (sum, s) => sum + s.length);
    if (totalChars == 0) return const [];

    final List<DuaSegment> segments = [];
    int currentStartMs = 0;

    for (int i = 0; i < rawParts.length; i++) {
      final part = rawParts[i];
      final isLast = i == rawParts.length - 1;
      final partFraction = part.length / totalChars;
      final partDuration = (totalDurationMs * partFraction).round();
      final endMs = isLast ? totalDurationMs : (currentStartMs + partDuration);

      segments.add(DuaSegment(
        startMs: currentStartMs,
        endMs: endMs > currentStartMs ? endMs : currentStartMs + 1000,
        arabic: part,
        translation: (i == 0 && rawParts.length == 1) ? translation : null,
        transliteration:
            (i == 0 && rawParts.length == 1) ? transliteration : null,
      ));

      currentStartMs = endMs;
    }

    return segments;
  }
}
