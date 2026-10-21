// ============================================================================
// lib/utils/date_formatter.dart — Localized Date Formatting for Adhkar 365
// ============================================================================

import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';

import 'responsive.dart';

/// Centralized utility for formatting Gregorian dates, Islamic Hijri dates,
/// and calendar weekday headers localized across all 19 supported languages.
class AppDateFormatter {
  AppDateFormatter._();

  // ───────────────────────────────────────────────────────────────────────────
  // Hijri Month Translations for all 19 supported languages
  // (1 = Muharram .. 12 = Dhu al-Hijjah)
  // ───────────────────────────────────────────────────────────────────────────
  static const Map<String, Map<int, String>> _hijriMonths = {
    'en': {
      1: 'Muharram',
      2: 'Safar',
      3: "Rabi' al-Awwal",
      4: "Rabi' al-Thani",
      5: 'Jumada al-Awwal',
      6: 'Jumada al-Thani',
      7: 'Rajab',
      8: "Sha'ban",
      9: 'Ramadan',
      10: 'Shawwal',
      11: "Dhu al-Qi'dah",
      12: 'Dhu al-Hijjah',
    },
    'bn': {
      1: 'মুহররম',
      2: 'সফর',
      3: 'রবিউল আউয়াল',
      4: 'রবিউস সানি',
      5: 'জমাদিউল আউয়াল',
      6: 'জমাদিউস সানি',
      7: 'রজব',
      8: 'শাবান',
      9: 'রমজান',
      10: 'শাওয়াল',
      11: 'জিলকদ',
      12: 'জিলহজ',
    },
    'ar': {
      1: 'محرّم',
      2: 'صفر',
      3: 'ربيع الأول',
      4: 'ربيع الثاني',
      5: 'جمادى الأولى',
      6: 'جمادى الآخرة',
      7: 'رجب',
      8: 'شعبان',
      9: 'رمضان',
      10: 'شوّال',
      11: 'ذو القعدة',
      12: 'ذو الحجة',
    },
    'ur': {
      1: 'محرم',
      2: 'صفر',
      3: 'ربیع الاول',
      4: 'ربیع الثانی',
      5: 'جمادی الاول',
      6: 'جمادی الثانی',
      7: 'رجب',
      8: 'شعبان',
      9: 'رمضان',
      10: 'شوال',
      11: 'ذوالقعدہ',
      12: 'ذوالحجہ',
    },
    'hi': {
      1: 'मुहर्रम',
      2: 'सफ़र',
      3: 'रबी उल-अव्वल',
      4: 'रबी उल-आखिर',
      5: 'जमादि उल-अव्वल',
      6: 'जमादि उल-आखिर',
      7: 'रजब',
      8: 'शाबान',
      9: 'रमज़ान',
      10: 'शव्वाल',
      11: 'ज़ुल क़ादा',
      12: 'ज़ुल हिज्जा',
    },
    'tr': {
      1: 'Muharrem',
      2: 'Safer',
      3: 'Rebiülevvel',
      4: 'Rebiülahir',
      5: 'Cemaziyelevvel',
      6: 'Cemaziyelahir',
      7: 'Recep',
      8: 'Şaban',
      9: 'Ramazan',
      10: 'Şevval',
      11: 'Zilkade',
      12: 'Zilhicce',
    },
    'id': {
      1: 'Muharram',
      2: 'Safar',
      3: 'Rabiul Awal',
      4: 'Rabiul Akhir',
      5: 'Jumadil Awal',
      6: 'Jumadil Akhir',
      7: 'Rajab',
      8: "Sya'ban",
      9: 'Ramadan',
      10: 'Syawal',
      11: "Dzulqa'dah",
      12: 'Dzulhijjah',
    },
    'ms': {
      1: 'Muharram',
      2: 'Safar',
      3: 'Rabiulawal',
      4: 'Rabiulakhir',
      5: 'Jamadilawal',
      6: 'Jamadilakhir',
      7: 'Rejab',
      8: 'Syaaban',
      9: 'Ramadan',
      10: 'Syawal',
      11: 'Zulkaedah',
      12: 'Zulhijjah',
    },
    'fr': {
      1: 'Mouharram',
      2: 'Safar',
      3: "Rabi' al-Awwal",
      4: "Rabi' al-Thani",
      5: 'Joumada al-Oula',
      6: 'Joumada al-Thani',
      7: 'Rajab',
      8: "Cha'ban",
      9: 'Ramadan',
      10: 'Chawwal',
      11: 'Dhou al-Qi\'da',
      12: 'Dhou al-Hijja',
    },
    'de': {
      1: 'Muharram',
      2: 'Safar',
      3: "Rabi' al-Awwal",
      4: "Rabi' al-Thani",
      5: 'Dschumada l-ula',
      6: 'Dschumada th-thaniya',
      7: 'Radschab',
      8: "Scha'ban",
      9: 'Ramadan',
      10: 'Schawwal',
      11: "Dhu l-qa'da",
      12: 'Dhu l-Hiddscha',
    },
    'es': {
      1: 'Muharram',
      2: 'Safar',
      3: "Rabi' al-Awwal",
      4: "Rabi' al-Zani",
      5: 'Yumada al-Ula',
      6: 'Yumada al-Tania',
      7: 'Rayab',
      8: "Sha'ban",
      9: 'Ramadán',
      10: 'Shawwal',
      11: 'Du al-Qada',
      12: 'Du al-Hiyya',
    },
    'pt': {
      1: 'Muharram',
      2: 'Safar',
      3: 'Rabi al-Awwal',
      4: 'Rabi al-Thani',
      5: 'Jumada al-Awwal',
      6: 'Jumada al-Thani',
      7: 'Rajab',
      8: "Sha'ban",
      9: 'Ramadã',
      10: 'Shawwal',
      11: "Dhu al-Qi'dah",
      12: 'Dhu al-Hijjah',
    },
    'it': {
      1: 'Muharram',
      2: 'Safar',
      3: "Rabi' al-Awwal",
      4: "Rabi' al-Thani",
      5: 'Jumada al-Awwal',
      6: 'Jumada al-Thani',
      7: 'Rajab',
      8: "Sha'ban",
      9: 'Ramadan',
      10: 'Shawwal',
      11: "Dhu al-Qi'dah",
      12: 'Dhu al-Hijjah',
    },
    'nl': {
      1: 'Muharram',
      2: 'Safar',
      3: "Rabi' al-Awwal",
      4: "Rabi' al-Thani",
      5: 'Jumada al-Awwal',
      6: 'Jumada al-Thani',
      7: 'Rajab',
      8: "Sha'ban",
      9: 'Ramadan',
      10: 'Shawwal',
      11: "Dhu al-Qi'dah",
      12: 'Dhu al-Hijjah',
    },
    'ru': {
      1: 'Мухаррам',
      2: 'Сафар',
      3: 'Раби аль-авваль',
      4: 'Раби ас-сани',
      5: 'Джумада аль-уля',
      6: 'Джумада ас-сани',
      7: 'Раджаб',
      8: 'Шаабан',
      9: 'Рамадан',
      10: 'Шавваль',
      11: 'Зу-ль-каада',
      12: 'Зу-ль-хиджа',
    },
    'ta': {
      1: 'முஹர்ரம்',
      2: 'ஸஃபர்',
      3: 'ரபீஉல் அவ்வல்',
      4: 'ரபீஉஸ் ஸானி',
      5: 'ஜுமாதல் ஊலா',
      6: 'ஜுமாதல் ஆகிரா',
      7: 'ரஜப்',
      8: 'ஷஅபான்',
      9: 'ரமழான்',
      10: 'ஷவ்வால்',
      11: 'துல்கஃதா',
      12: 'துல்ஹஜ்',
    },
    'th': {
      1: 'มุฮัรร็อม',
      2: 'เศาะฟัร',
      3: 'เราะบีอุลเอาวัล',
      4: 'เราะบีอุษษานี',
      5: 'ญุมาดัลอูลา',
      6: 'ญุมาดัษษานียะฮ์',
      7: 'รอญับ',
      8: 'ชะอ์บาน',
      9: 'รอมฎอน',
      10: 'เชาวาล',
      11: 'ซุลเกาะอ์ดะฮ์',
      12: 'ซุลฮิจญะฮ์',
    },
    'ja': {
      1: 'ムハッラム',
      2: 'サファル',
      3: 'ラビー・ウル・アウワル',
      4: 'ラビー・ウッ・サーニー',
      5: 'ジュマーダー・アル・ウーラー',
      6: 'ジュマーダー・アッ・サーニー',
      7: 'ラジャブ',
      8: 'シャアバーン',
      9: 'ラマダーン',
      10: 'シャウワール',
      11: 'ズー・アル・カイダ',
      12: 'ズー・アル・ヒッジャ',
    },
    'zh': {
      1: '穆哈兰姆月',
      2: '色法尔月',
      3: '赖比尔·敖外鲁月',
      4: '赖比尔·阿色尼月',
      5: '主马达·敖外鲁月',
      6: '主马达·阿色尼月',
      7: '热哲卜月',
      8: '舍尔邦月',
      9: '莱麦丹月',
      10: '闪瓦鲁月',
      11: '都尔喀尔德月',
      12: '都尔黑哲月',
    },
  };

  /// Returns the localized name of the Hijri month (1-12) for [langCode].
  static String getHijriMonthName(int month, String langCode) {
    final map = _hijriMonths[langCode] ?? _hijriMonths['en']!;
    return map[month] ?? _hijriMonths['en']![month] ?? '';
  }

  /// Formats an Islamic Hijri calendar date into a localized string:
  /// e.g. "৩০ রবিউস সানি ১৪৪৮" (bn) or "30 Rabi' al-Thani 1448" (en).
  static String formatHijri(HijriCalendar hijri, String langCode) {
    final mName = getHijriMonthName(hijri.hMonth, langCode);
    final raw = '${hijri.hDay} $mName ${hijri.hYear}';
    return R.localizeDigits(raw, langCode);
  }

  /// Formats a Gregorian [DateTime] into a localized string according to
  /// [langCode], respecting localized weekday names, month names, and digits.
  ///
  /// Example:
  ///   formatGregorian(now, 'bn', pattern: 'EEEE, d MMMM yyyy')
  ///   -> "রবিবার, ১১ অক্টোবর ২০২৬"
  static String formatGregorian(
    DateTime date,
    String langCode, {
    String pattern = 'EEEE, d MMMM yyyy',
  }) {
    String formatted;
    try {
      formatted = DateFormat(pattern, langCode).format(date);
    } catch (_) {
      // Fallback to English if the locale data fails
      try {
        formatted = DateFormat(pattern, 'en').format(date);
      } catch (_) {
        formatted = DateFormat(pattern).format(date);
      }
    }
    return R.localizeDigits(formatted, langCode);
  }

  /// Returns a list of 7 narrow/short weekday header labels for calendar views,
  /// ordered Monday through Sunday (1 to 7).
  static List<String> getWeekdayHeaders(String langCode) {
    const customHeaders = {
      'bn': ['সো', 'ম', 'বু', 'বৃ', 'শু', 'শ', 'র'],
      'ur': ['پ', 'م', 'ب', 'ج', 'ج', 'ہ', 'ا'],
      'hi': ['सो', 'मं', 'बु', 'गु', 'शु', 'श', 'र'],
      'ta': ['தி', 'செ', 'பு', 'வி', 'வெ', 'ச', 'ஞா'],
    };

    if (customHeaders.containsKey(langCode)) {
      return customHeaders[langCode]!;
    }

    try {
      final sym = DateFormat('', langCode).dateSymbols;
      // NARROWWEEKDAYS: index 0 = Sunday, 1 = Monday ... 6 = Saturday
      return [
        sym.NARROWWEEKDAYS[1],
        sym.NARROWWEEKDAYS[2],
        sym.NARROWWEEKDAYS[3],
        sym.NARROWWEEKDAYS[4],
        sym.NARROWWEEKDAYS[5],
        sym.NARROWWEEKDAYS[6],
        sym.NARROWWEEKDAYS[0],
      ];
    } catch (_) {
      return const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    }
  }
}
