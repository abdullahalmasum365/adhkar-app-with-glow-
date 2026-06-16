enum DhikrCategory { morning, evening, protection, focus, parents, graveyard, food }

class Dhikr {
  final String id;
  final String title;
  final String arabicText;
  final String translation;
  final String? transliteration;
  final String? audioPath;   // nullable — fixed crash in DhikrFocusScreen
  final String? benefit;
  final String? reference;
  final int targetCount;
  final DhikrCategory category;
  int currentCount;

  Dhikr({
    required this.id,
    required this.title,
    required this.arabicText,
    required this.translation,
    this.transliteration,
    this.audioPath,
    this.benefit,
    this.reference,
    required this.targetCount,
    required this.category,
    this.currentCount = 0,
  });

  bool get isCompleted => currentCount >= targetCount;

  double get progress =>
      targetCount > 0 ? (currentCount / targetCount).clamp(0.0, 1.0) : 0.0;

  Dhikr copyWith({
    int? currentCount,
    String? title,
    String? translation,
    String? transliteration,
    String? benefit,
    String? reference,
  }) => Dhikr(
        id: id,
        title: title ?? this.title,
        arabicText: arabicText,
        translation: translation ?? this.translation,
        transliteration: transliteration ?? this.transliteration,
        audioPath: audioPath,
        benefit: benefit ?? this.benefit,
        reference: reference ?? this.reference,
        targetCount: targetCount,
        category: category,
        currentCount: currentCount ?? this.currentCount,
      );
}
