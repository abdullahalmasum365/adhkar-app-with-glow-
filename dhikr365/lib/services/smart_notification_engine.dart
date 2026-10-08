// ============================================================================
// lib/services/smart_notification_engine.dart
//
// SMART SUNNAH NOTIFICATION ENGINE
//
// Provides:
//   1. Sunnah timing offsets:
//      • Morning Adhkar: 18 mins after Fajr (prime Sunnah window before sunrise)
//      • Evening Adhkar: 12 mins after Asr (prime Sunnah window before Maghrib)
//      • Before Sleep: 35 mins after Isha
//      • Jumu'ah Hour of Acceptance: Fridays 60 mins before Maghrib
//   2. Rotating pool of authentic Hadith & Quranic hooks (Bengali & English)
//   3. Streak loss-aversion dynamic copy
//   4. Actionable notification buttons: [ 📖 এখনই পড়ুন ] and [ ⏰ ১৫ মিনিট পর ]
// ============================================================================

class NotificationHook {
  final String title;
  final String body;
  const NotificationHook({required this.title, required this.body});
}

class SmartNotificationEngine {
  // ── Action IDs for Notification Banner ────────────────────────────────────
  static const String actionRead = 'action_read';
  static const String actionSnooze = 'action_snooze';

  // ── Sunnah-aligned Timing Offsets ─────────────────────────────────────────
  static const Duration morningFajrOffset = Duration(minutes: 18);
  static const Duration eveningAsrOffset = Duration(minutes: 12);
  static const Duration beforeSleepIshaOffset = Duration(minutes: 35);
  static const Duration jumuahMaghribOffset = Duration(minutes: -60); // 1 hour before Maghrib

  // ── Morning Rotating Hadith & Quran Hooks ─────────────────────────────────
  static const List<NotificationHook> _morningHooksBn = [
    NotificationHook(
      title: '🌅 সকালের আযকার ও তাওবা',
      body: 'রাসূলুল্লাহ (ﷺ) বলেছেন: যে ব্যক্তি দৃঢ় বিশ্বাসের সাথে সকালে সাইয়্যিদুল ইস্তিগফার পড়বে এবং সেদিন মারা গেলে সে জান্নাতি হবে। [সহিহ বুখারি]',
    ),
    NotificationHook(
      title: '☀️ সকালের আত্মিক সুরক্ষা',
      body: 'সকাল শুরু হোক রবের সুরক্ষায়: সকালের আযকার আপনাকে সন্ধ্যা পর্যন্ত সমস্ত অনিষ্ট থেকে হেফাজত করবে।',
    ),
    NotificationHook(
      title: '🛡️ আয়াতুল কুরসীর হেফাজত',
      body: 'আয়াতুল কুরসী পড়ুন: সকালের আযকারে আয়াতুল কুরসী পাঠে সন্ধ্যা পর্যন্ত সকল অনিষ্ট ও জিন-শয়তান থেকে পূর্ণ সুরক্ষা পাওয়া যায়। [নাসায়ী ও হাকিম]',
    ),
    NotificationHook(
      title: '✨ গুনাহ মাফের শ্রেষ্ঠ সুযোগ',
      body: 'সুবহানাল্লাহি ওয়া বিহামদিহি ১০০ বার: যে ব্যক্তি সকালে পাঠ করে তার সমস্ত গুনাহ ক্ষমা করে দেওয়া হয়। [মুসলিম]',
    ),
  ];

  static const List<NotificationHook> _morningHooksEn = [
    NotificationHook(
      title: '🌅 Morning Remembrance & Forgiveness',
      body: 'The Prophet (ﷺ) said: Whoever recites Sayyid al-Istighfar with conviction in the morning... [Bukhari]',
    ),
    NotificationHook(
      title: '☀️ Divine Shield of the Morning',
      body: 'Start your day with divine protection: Morning Adhkar shields you from harm until evening.',
    ),
    NotificationHook(
      title: '🛡️ Guardian for Your Day',
      body: 'Recite Ayat al-Kursi: Reciting it in the morning shields you from evil and harm until evening. [An-Nasa\'i & Al-Hakim]',
    ),
    NotificationHook(
      title: '✨ Ocean of Divine Mercy',
      body: 'SubhanAllahi wa bihamdihi (100x): Your sins are forgiven even if they equal the foam of the sea.',
    ),
  ];

  // ── Evening Rotating Hadith & Quran Hooks ─────────────────────────────────
  static const List<NotificationHook> _eveningHooksBn = [
    NotificationHook(
      title: '🌆 সন্ধ্যার পূর্ণ নিরাপত্তা',
      body: 'সন্ধ্যা নেমে এসেছে: ৩ বার \'বিসমিল্লাহিল্লাজি লা ইয়াদুররু...\' পাঠ করুন—কোনো বিপদ স্পর্শ করবে না। [তিরমিজি]',
    ),
    NotificationHook(
      title: '🌙 সন্ধ্যার আধ্যাত্মিক প্রশান্তি',
      body: 'দিনের ক্লান্তি দূর হোক: আসরের পরের বরকতময় সময়ে সন্ধ্যার আযকারের মাধ্যমে অন্তরে প্রশান্তি লাভ করুন।',
    ),
    NotificationHook(
      title: '🛡️ তিন ক্বুলের সুরক্ষা',
      body: 'সূরা ইখলাস, ফালাক্ব ও নাস ৩ বার পড়ুন: সকাল ও সন্ধ্যায় এই তিন সূরা পাঠ সব অনিষ্ট থেকে রক্ষার জন্য যথেষ্ট। [আবু দাউদ]',
    ),
    NotificationHook(
      title: '🤲 সন্ধ্যার দোয়া ও হেফাজত',
      body: 'আমসাইনা ওয়া আমসাল মুলকু লিল্লাহ — রবের শোকরিয়ায় সন্ধ্যার বরকতময় জিকির শুরু করুন।',
    ),
  ];

  static const List<NotificationHook> _eveningHooksEn = [
    NotificationHook(
      title: '🌆 Evening Shield & Safety',
      body: 'The sun is setting: Recite \'Bismillahilladhi la yadurru...\' 3 times for complete protection. [Tirmidhi]',
    ),
    NotificationHook(
      title: '🌙 Tranquility in Remembrance',
      body: 'Wash away the fatigue of the day: Rejuvenate your soul with Evening Adhkar.',
    ),
    NotificationHook(
      title: '🛡️ The Three Protectors',
      body: 'Recite Al-Ikhlas, Al-Falaq & An-Nas (3x): They suffice you against every harm. [Abu Dawood]',
    ),
    NotificationHook(
      title: '🤲 Praise and Protection',
      body: 'Amsayna wa amsal-mulku lillah — Glorify the Lord of the worlds at dusk for continuous safety.',
    ),
  ];

  // ── Before Sleep Hooks ───────────────────────────────────────────────────
  static const List<NotificationHook> _beforeSleepHooksBn = [
    NotificationHook(
      title: '😴 প্রশান্তিময় ঘুমের পূর্বপ্রস্তুতি',
      body: 'ঘুমের আগের আযকার: আয়াতুল কুরসী ও সূরা মুলক তিলাওয়াত করে রবের নিরাপত্তায় শান্তিময় ঘুমে যান।',
    ),
    NotificationHook(
      title: '🌙 রাতের বিশ্রাম ও রবের স্মরণ',
      body: 'বিসমিকাল্লাহুম্মা আমুতু ওয়া আহ্ইয়া — শেষ মুহূর্তটি কাটুক আল্লাহর মহিমান্বিত স্মরণে।',
    ),
  ];

  static const List<NotificationHook> _beforeSleepHooksEn = [
    NotificationHook(
      title: '😴 Peaceful Sleep & Protection',
      body: 'Before sleep: Recite Ayat al-Kursi & Surah Al-Mulk for peaceful protection through the night.',
    ),
    NotificationHook(
      title: '🌙 Night Remembrance',
      body: 'End your day in remembrance of Allah for tranquility and sweet sleep.',
    ),
  ];

  // ── Jumu'ah Hour of Acceptance Hooks ──────────────────────────────────────
  static const List<NotificationHook> _jumuahHooksBn = [
    NotificationHook(
      title: '🤲 জুমার দোয়া কবুলের শেষ প্রহর',
      body: 'রাসূলুল্লাহ (ﷺ) বলেছেন: জুমার দিনে এমন এক মুহূর্ত আছে যাতে কোনো মুসলিম দোয়া করলে তা কবুল হয়। [আবু দাউদ]',
    ),
    NotificationHook(
      title: '🕌 আসরের পর থেকে মাগরিব',
      body: 'জুমার বরকতময় অন্তিম ক্ষণে বেশি বেশি দরূদ পড়ুন এবং হৃদয়ের গভীর থেকে আল্লাহর কাছে দোয়া করুন।',
    ),
  ];

  static const List<NotificationHook> _jumuahHooksEn = [
    NotificationHook(
      title: '🤲 Blessed Hour of Acceptance on Jumu\'ah',
      body: 'Seek Allah\'s forgiveness and pour your heart out in dua before Maghrib. [Abu Dawood]',
    ),
    NotificationHook(
      title: '🕌 The Final Hour of Friday',
      body: 'Send abundant blessings upon the Prophet (ﷺ) and pray during this answered hour.',
    ),
  ];

  // ── Public Hook Selectors ─────────────────────────────────────────────────

  /// Returns a rotating Morning Adhkar hook with optional streak loss-aversion
  static NotificationHook getMorningHook(String langCode, int dayIndex, {int streak = 0}) {
    final isBn = langCode == 'bn';
    if (streak >= 3) {
      return NotificationHook(
        title: isBn ? '🔥 আপনার $streak দিনের আমল স্ট্রিক চলমান!' : '🔥 $streak-Day Dhikr Streak Active!',
        body: isBn
            ? 'মাত্র ৩ মিনিট সময় নিয়ে সকালের আযকার পড়ুন—ধারাবাহিকতা অক্ষুণ্ণ রাখুন।'
            : 'Take 3 minutes for Morning Adhkar to protect your spiritual momentum today!',
      );
    }
    final list = isBn ? _morningHooksBn : _morningHooksEn;
    return list[dayIndex % list.length];
  }

  /// Returns a rotating Evening Adhkar hook with optional streak loss-aversion
  static NotificationHook getEveningHook(String langCode, int dayIndex, {int streak = 0}) {
    final isBn = langCode == 'bn';
    if (streak >= 3) {
      return NotificationHook(
        title: isBn ? '🔥 $streak দিনের স্ট্রিক রক্ষার সময়!' : '🔥 Protect Your $streak-Day Streak!',
        body: isBn
            ? 'দিনের শেষ ভাগে সন্ধ্যার আযকার পড়ে আজকের আমল সফলভাবে সম্পন্ন করুন।'
            : 'Complete Evening Adhkar now to maintain your sacred daily habit.',
      );
    }
    final list = isBn ? _eveningHooksBn : _eveningHooksEn;
    return list[dayIndex % list.length];
  }

  /// Returns a rotating Before Sleep hook
  static NotificationHook getBeforeSleepHook(String langCode, int dayIndex) {
    final isBn = langCode == 'bn';
    final list = isBn ? _beforeSleepHooksBn : _beforeSleepHooksEn;
    return list[dayIndex % list.length];
  }

  /// Returns a rotating Jumu'ah hook
  static NotificationHook getJumuahHook(String langCode, int dayIndex) {
    final isBn = langCode == 'bn';
    final list = isBn ? _jumuahHooksBn : _jumuahHooksEn;
    return list[dayIndex % list.length];
  }

  /// Button label: [ 📖 এখনই পড়ুন / Read Now ]
  static String getReadActionLabel(String langCode) {
    return langCode == 'bn' ? '📖 এখনই পড়ুন' : '📖 Read Now';
  }

  /// Button label: [ ⏰ ১৫ মিনিট পর / Snooze 15m ]
  static String getSnoozeActionLabel(String langCode) {
    return langCode == 'bn' ? '⏰ ১৫ মিনিট পর' : '⏰ Snooze 15m';
  }
}
