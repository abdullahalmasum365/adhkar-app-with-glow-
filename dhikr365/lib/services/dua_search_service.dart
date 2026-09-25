import '../models/dhikr.dart';

class DuaSearchResult {
  final Dhikr dhikr;
  final int relevanceScore;
  final String matchedReason;
  final String? snippet;

  const DuaSearchResult({
    required this.dhikr,
    required this.relevanceScore,
    required this.matchedReason,
    this.snippet,
  });
}

class DuaSearchService {
  /// Strip Arabic diacritics/tashkeel & normalize letters (Alif, Ta Marbuta, Ya)
  static String normalizeArabic(String text) {
    if (text.isEmpty) return '';
    // Strip Tashkeel (harakat), Tanween, Sukun, Shaddah, Dagger Alif, Quranic signs
    var s = text.replaceAll(RegExp(r'[\u064B-\u0652\u0670\u0640\u06D6-\u06ED]'), '');
    // Normalize Alefs: أ, إ, آ, ٱ -> ا
    s = s.replaceAll(RegExp(r'[إأآٱ]'), 'ا');
    // Normalize Alif Maqsura: ى -> ي
    s = s.replaceAll('ى', 'ي');
    // Normalize Ta Marbuta: ة -> ه
    s = s.replaceAll('ة', 'ه');
    return s.trim();
  }

  /// General lowercasing and punctuation removal
  static String normalizeText(String text) {
    if (text.isEmpty) return '';
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'''[।.,?!:;'"\-–—_()[\]{}«»/\\]'''), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Comprehensive Islamic concept and transliteration synonym mappings
  static const Map<String, List<String>> _synonyms = {
    // Tawheed & Creed
    'ayatul kursi': ['আয়াতুল কুরসী', 'কুরসী', 'kursi', 'throne', 'allahula', 'baqarah 255'],
    'ayatulkursi': ['আয়াতুল কুরসী', 'কুরসী', 'kursi', 'throne'],
    'কুরসী': ['kursi', 'ayatul kursi', 'আয়াতুল কুরসী', 'throne', 'কুরসি'],
    'কুরসি': ['kursi', 'ayatul kursi', 'আয়াতুল কুরসী'],
    'throne': ['আয়াতুল কুরসী', 'kursi'],
    'subhanallah': ['সুবহানাল্লাহ', 'মহিমা', 'glorified', 'tasbih', 'পবিত্রতা'],
    'সুবহানাল্লাহ': ['subhanallah', 'tasbih', 'পবিত্র'],
    'alhamdulillah': ['আলহামদুলিল্লাহ', 'প্রশংসা', 'praise', 'thanks'],
    'আলহামদুলিল্লাহ': ['alhamdulillah', 'প্রশংসা'],
    'allahu akbar': ['আল্লাহু আকবার', 'তাকবীর', 'takbir', 'greatest'],
    'allahuakbar': ['আল্লাহু আকবার', 'তাকবীর'],
    'আল্লাহু আকবার': ['allahu akbar', 'takbir'],
    'la ilaha illallah': ['লা ইলাহা ইল্লাল্লাহ', 'তাওহীদ', 'tahlil', 'none worthy'],
    'লা ইলাহা ইল্লাল্লাহ': ['la ilaha illallah', 'তাওহীদ'],
    'bismillah': ['বিসমিল্লাহ', 'নামে', 'name of allah'],
    'বিসমিল্লাহ': ['bismillah'],
    'hasbunallah': ['হাসবুনাল্লাহ', 'যথেষ্ট', 'sufficient'],
    'হাসবুনাল্লাহ': ['hasbunallah'],

    // Forgiveness & Repentance
    'istighfar': ['ইস্তিগফার', 'ক্ষমা', 'মাফ', 'forgiveness', 'astaghfirullah', 'আস্তাগফিরুল্লাহ'],
    'ইস্তিগফার': ['istighfar', 'ক্ষমা', 'মাফ', 'forgiveness', 'astaghfirullah', 'আস্তাগফিরুল্লাহ'],
    'astaghfirullah': ['আস্তাগফিরুল্লাহ', 'ইস্তিগফার', 'ক্ষমা', 'forgiveness'],
    'আস্তাগফিরুল্লাহ': ['astaghfirullah', 'ইস্তিগফার', 'ক্ষমা'],
    'sayyidul istighfar': ['সৈয়্যিদুল ইস্তিগফার', 'master of forgiveness', 'সেরা ইস্তিগফার'],
    'সৈয়্যিদুল ইস্তিগফার': ['sayyidul istighfar', 'master of forgiveness'],
    'ক্ষমা': ['forgiveness', 'istighfar', 'ইস্তিগফার', 'পাপ', 'গুনাহ', 'মাফ', 'পardon'],
    'মাফ': ['ক্ষমা', 'forgiveness', 'istighfar', 'ইস্তিগফার'],
    'তওবা': ['tawbah', 'repentance', 'ফিরে আসা', 'ইস্তিগফার'],
    'tawbah': ['তওবা', 'repentance'],

    // Daily Life & Occasions
    'namaz': ['সালাত', 'নামাজ', 'prayer', 'salah', 'after salah', 'নামায'],
    'namaj': ['সালাত', 'নামাজ', 'prayer', 'salah'],
    'নামাজ': ['সালাত', 'namaz', 'salah', 'prayer', 'after salah'],
    'নামায': ['সালাত', 'namaz', 'salah', 'prayer'],
    'সালাত': ['নামাজ', 'salah', 'prayer', 'namaz'],
    'salah': ['সালাত', 'নামাজ', 'prayer', 'after salah'],
    'prayer': ['সালাত', 'নামাজ', 'salah'],
    'wudu': ['ওজু', 'অজু', 'ablution', 'wudhu'],
    'ওজু': ['wudu', 'ablution', 'অজু', 'পবিত্রতা'],
    'sleep': ['ঘুম', 'ঘুমানো', 'শয়ন', 'bedtime', 'night', 'নিদ্রা'],
    'ঘুম': ['sleep', 'ঘুমানো', 'শয়ন', 'bedtime', 'night'],
    'শয়ন': ['sleep', 'ঘুম'],
    'food': ['খাবার', 'খাওয়া', 'আহার', 'eating', 'meal', 'দুধ', 'পানাহার'],
    'খাবার': ['food', 'eating', 'খাওয়া', 'আহার', 'দুধ'],
    'খাওয়া': ['food', 'eating', 'খাবার'],
    'milk': ['দুধ', 'লেবু', 'food'],
    'দুধ': ['milk', 'food'],
    'travel': ['সফর', 'ভ্রমণ', 'journey', 'বাহন', 'সवारी'],
    'সফর': ['travel', 'ভ্রমণ', 'journey', 'বাহন'],
    'ভ্রমণ': ['travel', 'সফর'],
    'parents': ['পিতা মাতা', 'মা বাবা', 'বাবা', 'মা', 'পিতা', 'মাতা', 'father', 'mother', 'প্যারেন্টস'],
    'পিতা মাতা': ['parents', 'মা বাবা', 'বাবা', 'মা', 'রব্বির হামহুমা'],
    'মা বাবা': ['parents', 'পিতা মাতা'],
    'graveyard': ['কবর', 'কবরস্থান', 'মৃত', 'grave', 'death', 'সালাম'],
    'কবর': ['graveyard', 'grave', 'কবরস্থান', 'মৃত'],
    'কবরস্থান': ['graveyard', 'grave', 'কবর'],

    // Shifa & Protection
    'protection': ['সুরক্ষা', 'হেফাজত', 'রক্ষা', 'আশ্রয়', 'নিরাপত্তা', 'শয়তান', 'জিন'],
    'সুরক্ষা': ['protection', 'হেফাজত', 'রক্ষা', 'নিরাপত্তা'],
    'হেফাজত': ['protection', 'সুরক্ষা', 'রক্ষা'],
    'evil eye': ['নজর', 'কু নজর', 'عين', 'চোখ লাগা', 'protection'],
    'নজর': ['evil eye', 'কু নজর', 'protection'],
    'magic': ['যাদু', 'জাদু', 'কালো জাদু', 'sihr', 'protection', 'ফালাক', 'নাস'],
    'জাদু': ['magic', 'যাদু', 'protection'],
    'shifa': ['শিফা', 'রোগ', 'ব্যথা', 'অসুখ', 'healing', 'cure', 'pain', 'সুস্থতা'],
    'শিফা': ['shifa', 'রোগ', 'ব্যথা', 'healing', 'cure', 'সুস্থতা'],
    'ব্যথা': ['pain', 'shifa', 'রোগ', 'শিফা', 'যন্ত্রণা'],
    'pain': ['ব্যথা', 'shifa', 'রোগ'],
    'রোগ': ['shifa', 'healing', 'অসুখ', 'ব্যথা', 'cure'],
    'distress': ['চিন্তা', 'দুশ্চিন্তা', 'কষ্ট', 'বিপদ', 'ঋণ', 'debt', 'anxiety', 'worry', 'টাকা'],
    'বিপদ': ['distress', 'কষ্ট', 'দুশ্চিন্তা', 'উদ্ধার', 'মুসিবত'],
    'ঋণ': ['debt', 'ঋণগ্রস্ততা', 'টাকা', 'কর্জ', 'distress'],
    'debt': ['ঋণ', 'কর্জ', 'distress'],
    'দুশ্চিন্তা': ['distress', 'anxiety', 'worry', 'চিন্তা', 'পেরেশানি'],
    'anxiety': ['দুশ্চিন্তা', 'চিন্তা', 'distress'],

    // Virtue & Afterlife
    'jannat': ['জান্নাত', 'paradise', 'heaven', 'বাগান'],
    'জান্নাত': ['jannat', 'paradise', 'heaven'],
    'paradise': ['জান্নাত', 'jannat'],
    'jahannam': ['জাহান্নাম', 'আগুন', 'hell', 'hellfire', 'দোযখ'],
    'জাহান্নাম': ['jahannam', 'আগুন', 'hell', 'hellfire'],
    'hell': ['জাহান্নাম', 'jahannam', 'আগুন'],
    'rizq': ['রিজিক', 'বরকত', 'wealth', 'sustenance', 'জীবিকা'],
    'রিজিক': ['rizq', 'বরকত', 'জীবিকা', 'sustenance', 'হালাল'],
    'knowledge': ['ইলম', 'জ্ঞান', 'উপকারী জ্ঞান', 'ilm', 'পড়াশোনা'],
    'জ্ঞান': ['knowledge', 'ইলম', 'ilm', 'পড়াশোনা'],
    'ইলম': ['knowledge', 'জ্ঞান', 'ilm'],
    'দরূদ': ['salawat', 'দরুদ', 'দুরুদ', 'durood', 'নবীজি', 'রাসূল'],
    'দরুদ': ['salawat', 'দরূদ', 'দুরুদ'],
    'salawat': ['দরূদ', 'দরুদ', 'durood', 'prophet'],
  };

  /// Expands raw query into related search tokens with bi-directional synonyms
  static Set<String> getExpandedTokens(String query) {
    final clean = normalizeText(query);
    if (clean.isEmpty) return {};

    final tokens = clean.split(' ').where((t) => t.isNotEmpty).toSet();
    final result = Set<String>.from(tokens);

    // Add whole query as a phrase token
    result.add(clean);

    // Bi-directional synonym lookup
    _synonyms.forEach((key, synList) {
      final normKey = normalizeText(key);
      if (clean == normKey || clean.contains(normKey) || tokens.contains(normKey)) {
        result.addAll(synList.map((s) => normalizeText(s)));
      }
      for (final s in synList) {
        final normS = normalizeText(s);
        if (clean == normS || clean.contains(normS) || tokens.contains(normS)) {
          result.add(normKey);
          result.addAll(synList.map((x) => normalizeText(x)));
          break;
        }
      }
    });

    return result;
  }

  /// Searches all dhikrs with Google-like fuzzy, multi-field, and relevance ranking
  static List<DuaSearchResult> search({
    required List<Dhikr> allDhikrs,
    required String query,
  }) {
    final rawQuery = query.trim();
    if (rawQuery.isEmpty) return [];

    final cleanQuery = normalizeText(rawQuery);
    final normArQuery = normalizeArabic(rawQuery);
    final expandedTokens = getExpandedTokens(rawQuery);

    final List<DuaSearchResult> results = [];

    for (final dhikr in allDhikrs) {
      int score = 0;
      String? matchedReason;
      String? snippet;

      final normTitle = normalizeText(dhikr.title);
      final normTranslit = normalizeText(dhikr.transliteration ?? '');
      final normTrans = normalizeText(dhikr.translation);
      final normBenefit = normalizeText(dhikr.benefit ?? '');
      final normRef = normalizeText(dhikr.reference ?? '');
      final normId = dhikr.id.replaceAll('_', ' ').toLowerCase();
      final normArText = normalizeArabic(dhikr.arabicText);

      // ── 1. EXACT PHRASE MATCHES (Highest Priority) ─────────────────────────
      if (normTitle == cleanQuery) {
        score += 250;
        matchedReason = 'Exact Title Match';
      } else if (normTitle.contains(cleanQuery)) {
        score += 150;
        matchedReason = 'Title Match';
      }

      // Exact phrase in Transliteration
      if (normTranslit.contains(cleanQuery) && cleanQuery.length > 2) {
        score += 100;
        matchedReason ??= 'Transliteration Match';
      }

      // Arabic Exact / Substring / Token Match (normalized without harakat)
      if (normArQuery.isNotEmpty && normArQuery.length >= 2) {
        if (normArText == normArQuery) {
          score += 200;
          matchedReason = 'Exact Arabic Match';
        } else if (normArText.contains(normArQuery)) {
          score += 120;
          matchedReason ??= 'Arabic Text Match';
        } else {
          // Token matching for Arabic: e.g. "لا اله الا الله"
          final arTokens = normArQuery.split(' ').where((t) => t.length >= 2).toList();
          if (arTokens.isNotEmpty) {
            int arMatches = 0;
            for (final at in arTokens) {
              if (normArText.contains(at)) {
                arMatches++;
              }
            }
            if (arMatches >= 2 || (arTokens.length == 1 && arMatches == 1)) {
              score += 35 * arMatches;
              matchedReason ??= 'Arabic Match';
            }
          }
        }
      }

      // Exact phrase in Translation
      if (normTrans.contains(cleanQuery) && cleanQuery.length > 2) {
        score += 80;
        matchedReason ??= 'Meaning Match';
        snippet = _extractSnippet(dhikr.translation, cleanQuery);
      }

      // Exact phrase in Benefit / Virtues
      if (normBenefit.contains(cleanQuery) && cleanQuery.length > 2) {
        score += 60;
        matchedReason ??= 'Virtue/Benefit Match';
        snippet ??= _extractSnippet(dhikr.benefit!, cleanQuery);
      }

      // ID match (e.g. 'm_ayatulkursi', 'food_bismillah')
      if (normId.contains(cleanQuery)) {
        score += 70;
        matchedReason ??= 'Keyword Match';
      }

      // ── 2. TOKEN & SYNONYM MATCHES ──────────────────────────────────────────
      int tokenHitsInTitle = 0;
      int tokenHitsInTrans = 0;
      int tokenHitsInBenefit = 0;

      for (final token in expandedTokens) {
        if (token.isEmpty || token.length < 2) continue;

        if (normTitle.contains(token)) {
          tokenHitsInTitle++;
          score += 40;
          matchedReason ??= 'Title Match';
        }
        if (normTranslit.contains(token)) {
          score += 25;
          matchedReason ??= 'Pronunciation Match';
        }
        if (normTrans.contains(token)) {
          tokenHitsInTrans++;
          score += 20;
          matchedReason ??= 'Meaning Match';
          snippet ??= _extractSnippet(dhikr.translation, token);
        }
        if (normBenefit.contains(token)) {
          tokenHitsInBenefit++;
          score += 15;
          matchedReason ??= 'Benefit Match';
          snippet ??= _extractSnippet(dhikr.benefit!, token);
        }
        if (normRef.contains(token)) {
          score += 15;
          matchedReason ??= 'Hadith Reference Match';
        }
        if (normId.contains(token)) {
          score += 15;
        }
      }

      // Bonus if multiple query tokens matched in title or translation
      if (tokenHitsInTitle > 1) score += 30;
      if (tokenHitsInTrans > 1) score += 20;
      if (tokenHitsInBenefit > 1) score += 15;

      if (score > 0) {
        results.add(DuaSearchResult(
          dhikr: dhikr,
          relevanceScore: score,
          matchedReason: matchedReason ?? 'Relevant Supplication',
          snippet: snippet,
        ));
      }
    }

    // Sort by relevance score descending
    results.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));

    return results;
  }

  /// Extracts a 60-character surrounding context window for a search term
  static String? _extractSnippet(String source, String query) {
    final lower = source.toLowerCase();
    final idx = lower.indexOf(query.toLowerCase());
    if (idx == -1) return null;

    final start = (idx - 25).clamp(0, source.length);
    final end = (idx + query.length + 35).clamp(0, source.length);

    String text = source.substring(start, end).trim();
    if (start > 0) text = '...$text';
    if (end < source.length) text = '$text...';
    return text;
  }
}
