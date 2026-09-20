// ============================================================================
// lib/models/sadaqah_dedication.dart
//
// Model representing the spiritual intention and dedication of Sadaqah Jariyah.
// Allows users to dedicate their ongoing charity for themselves, their parents,
// deceased loved ones, or family.
// ============================================================================

enum DedicationType {
  self,
  parents,
  deceased,
  family,
}

class SadaqahDedication {
  final DedicationType type;
  final String? recipientName;
  final DateTime timestamp;

  const SadaqahDedication({
    required this.type,
    this.recipientName,
    required this.timestamp,
  });

  String getDisplayTitle(String langCode) {
    final isBn = langCode == 'bn';
    switch (type) {
      case DedicationType.self:
        return isBn ? 'আমার নিজের জন্য' : 'For Myself';
      case DedicationType.parents:
        return isBn ? 'আমার পিতা-মাতার জন্য' : 'For My Parents';
      case DedicationType.deceased:
        return isBn ? 'মরহুম প্রিয় মানুষের মাগফিরাতে' : 'In Memory of Deceased Loved One';
      case DedicationType.family:
        return isBn ? 'সন্তান ও পরিবারের কল্যাণে' : 'For My Children & Family';
    }
  }

  String getDuaArabic() {
    switch (type) {
      case DedicationType.parents:
        return 'رَّبِّ ارْحَمْهُمَا كَمَا رَبَّيَانِي صَغِيرًا';
      case DedicationType.deceased:
        return 'رَبَّنَا اغْفِرْ لَنَا وَلِإِخْوَانِنَا الَّذِينَ سَبَقُونَا بِالْإِيمَانِ';
      case DedicationType.self:
      case DedicationType.family:
        return 'رَبَّنَا تَقَبَّلْ مِنَّا ۖ إِنَّكَ أَنتَ السَّمِيعُ الْعَلِيمُ';
    }
  }

  String getDuaTranslation(String langCode) {
    final isBn = langCode == 'bn';
    switch (type) {
      case DedicationType.parents:
        return isBn
            ? '“হে আমার রব! তাদের প্রতি রহম করুন, যেমন তারা শৈশবে আমাকে লালন-পালন করেছেন।” (সূরা বনী ইসরাঈল: ২৪)'
            : '“My Lord, have mercy upon them as they brought me up when I was small.” (Surah Al-Isra: 24)';
      case DedicationType.deceased:
        return isBn
            ? '“হে আমাদের রব! আমাদের এবং আমাদের পূর্বে যেসব ভাই ঈমান নিয়ে মারা গেছেন তাদের ক্ষমা করে দিন।” (সূরা আল-হাশর: ১০)'
            : '“Our Lord, forgive us and our brothers who preceded us in faith.” (Surah Al-Hashr: 10)';
      case DedicationType.self:
      case DedicationType.family:
        return isBn
            ? '“হে আমাদের রব! আমাদের পক্ষ থেকে কবুল করুন, নিশ্চয় আপনি সর্বশ্রোতা, সর্বজ্ঞ।” (সূরা আল-বাক্বারা: ১২৭)'
            : '“Our Lord, accept this from us. Indeed You are the All-Hearing, the All-Knowing.” (Surah Al-Baqarah: 127)';
    }
  }
}
