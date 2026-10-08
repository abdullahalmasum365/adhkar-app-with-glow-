// ============================================================================
// lib/models/dua_timestamp.dart
//
// TIME-SYNCED DUA SEGMENT MODEL
//
// Represents a timed segment/sentence of an authentic Dhikr recitation.
// Used by TimeSyncedDhikrView to provide real-time Karaoke-style highlighting,
// auto-scrolling, and interactive tap-to-seek playback.
// ============================================================================

class DuaSegment {
  /// Start timestamp in milliseconds from audio start.
  final int startMs;

  /// End timestamp in milliseconds.
  final int endMs;

  /// Arabic sentence / phrase text.
  final String arabic;

  /// Optional translation of this specific segment.
  final String? translation;

  /// Optional transliteration of this specific segment.
  final String? transliteration;

  const DuaSegment({
    required this.startMs,
    required this.endMs,
    required this.arabic,
    this.translation,
    this.transliteration,
  });

  /// True if [currentMs] falls within this segment's playback window.
  bool isActive(int currentMs) => currentMs >= startMs && currentMs < endMs;

  factory DuaSegment.fromJson(Map<String, dynamic> json) {
    return DuaSegment(
      startMs: (json['startMs'] as num).toInt(),
      endMs: (json['endMs'] as num).toInt(),
      arabic: json['arabic'] as String? ?? '',
      translation: json['translation'] as String?,
      transliteration: json['transliteration'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'startMs': startMs,
        'endMs': endMs,
        'arabic': arabic,
        if (translation != null) 'translation': translation,
        if (transliteration != null) 'transliteration': transliteration,
      };
}
