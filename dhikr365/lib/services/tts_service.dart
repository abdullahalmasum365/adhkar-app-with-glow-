// ============================================================================
// lib/services/tts_service.dart
//
// TEXT-TO-SPEECH — translation reading + Arabic fallback.
//
// Voice gender: the user can choose a MALE or FEMALE voice (Settings →
// Localization → Translation Voice). Selection strategy, per language:
//   1. Ask the engine for its installed voices and pick one whose gender
//      matches (exact locale first, then same language). iOS exposes a
//      `gender` field; on Android we classify by the voice-name conventions
//      Google TTS uses (see [_voiceGender]).
//   2. If the device has no voice of the requested gender for that language,
//      fall back to pitch shaping (female ≈ 1.25, male ≈ 0.85) so the choice
//      is still clearly audible.
// The chosen voice is cached per (language, gender) — getVoices is queried
// once per session, not once per utterance.
//
// Clarity: a measured speech rate (0.42), full volume, and [_clean] which
// strips symbols TTS engines garble (honorific ligatures ﷺ/ﷻ in non-Arabic
// text, collapsed whitespace, stray asterisks).
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal() {
    // Load the saved gender eagerly (fire-and-forget) so UI that reads
    // [voiceGender] before the first utterance still shows the right value.
    _loadGenderPref();
  }

  Future<void> _loadGenderPref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved == 'male' || saved == 'female') _gender = saved!;
    } catch (_) {}
  }

  static const _prefKey = 'tts_voice_gender';

  final FlutterTts _tts = FlutterTts();
  bool _speaking = false;
  bool _initialised = false;
  String? _currentText;
  String _currentLang = 'ar-SA';
  VoidCallback? _onComplete;

  /// 'male' or 'female'. Male by default — the conventional voice for
  /// religious content; the user can switch anytime in Settings.
  String _gender = 'male';

  /// Which (lang|gender) combination the engine is currently configured for.
  /// Null forces re-resolution on the next speak().
  String? _appliedKey;

  /// Raw voice list from the engine, fetched once per session.
  List<Map<String, String>>? _voices;

  bool get isSpeaking => _speaking;
  String get voiceGender => _gender;

  /// Map app language codes → BCP-47 TTS language tags
  static String ttsLang(String langCode) {
    const map = {
      'ar': 'ar-SA', 'en': 'en-US', 'fr': 'fr-FR', 'de': 'de-DE',
      'es': 'es-ES', 'id': 'id-ID', 'ms': 'ms-MY', 'tr': 'tr-TR',
      'ur': 'ur-PK', 'bn': 'bn-BD', 'hi': 'hi-IN', 'ru': 'ru-RU',
      'zh': 'zh-CN', 'ja': 'ja-JP', 'pt': 'pt-PT', 'nl': 'nl-NL',
      'it': 'it-IT', 'ta': 'ta-IN', 'th': 'th-TH',
    };
    return map[langCode] ?? 'en-US';
  }

  Future<void> _ensureInit() async {
    if (_initialised) return;
    _initialised = true;
    await _loadGenderPref();
    await _tts.setSpeechRate(0.42);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _tts.setCompletionHandler(() {
      _speaking = false;
      final cb = _onComplete;
      _onComplete = null;
      cb?.call();
    });
    _tts.setCancelHandler(() => _speaking = false);
    _tts.setErrorHandler((msg) {
      _speaking = false;
      debugPrint('[TTS] error: $msg');
    });
  }

  /// Switch between 'male' and 'female'. Persisted; takes effect on the
  /// next utterance (the voice is re-resolved lazily).
  Future<void> setVoiceGender(String gender) async {
    if (gender != 'male' && gender != 'female') return;
    _gender = gender;
    _appliedKey = null; // force voice re-resolution
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, gender);
    } catch (_) {}
  }

  // ── Voice resolution ────────────────────────────────────────────────────

  /// Best-effort gender classification of an engine voice.
  /// iOS ships a real `gender` field. Android (Google TTS) encodes the
  /// variant in the name — e.g. "bn-in-x-bnf-local" / "en-us-x-tpm-network":
  /// the trailing letter of the "-x-???" segment is f/g for female voices
  /// and m/d for male ones. Anything unrecognized returns null.
  static String? _voiceGenderOf(String name, String gender) {
    if (gender == 'male' || gender == 'female') return gender;
    final n = name.toLowerCase();
    if (n.contains('female')) return 'female';
    if (n.contains('male')) return 'male'; // checked after 'female'
    final m = RegExp(r'-x-([a-z]{3})').firstMatch(n);
    if (m != null) {
      final last = m.group(1)![2];
      if (last == 'f' || last == 'g') return 'female';
      if (last == 'm' || last == 'd') return 'male';
    }
    return null;
  }

  Future<List<Map<String, String>>> _getVoices() async {
    if (_voices != null) return _voices!;
    try {
      final raw = await _tts.getVoices;
      _voices = (raw as List)
          .whereType<Map>()
          .map((v) => {
                'name': (v['name'] ?? '').toString(),
                'locale': (v['locale'] ?? '').toString(),
                'gender': (v['gender'] ?? '').toString().toLowerCase(),
              })
          .where((v) => v['name']!.isNotEmpty && v['locale']!.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('[TTS] getVoices failed: $e');
      _voices = const [];
    }
    return _voices!;
  }

  /// Finds the best installed voice for [lang] + [gender], or null when the
  /// device has no voice of that gender for that language.
  Future<Map<String, String>?> _findVoice(String lang, String gender) async {
    final voices = await _getVoices();
    if (voices.isEmpty) return null;

    final langLower = lang.toLowerCase().replaceAll('_', '-');
    final prefix = langLower.split('-').first;

    Map<String, String>? best;
    var bestScore = -1000;
    for (final v in voices) {
      final locale = v['locale']!.toLowerCase().replaceAll('_', '-');
      if (!locale.startsWith(prefix)) continue;
      if (_voiceGenderOf(v['name']!, v['gender']!) != gender) continue;
      // Score: exact locale beats same-language; offline beats network
      // (a network-only voice is silent without internet).
      var score = 0;
      final name = v['name']!.toLowerCase();
      if (locale == langLower) score += 2;
      if (name.contains('local')) score += 3;
      if (name.contains('network')) score -= 2;
      if (score > bestScore) {
        bestScore = score;
        best = v;
      }
    }
    return best == null
        ? null
        : {'name': best['name']!, 'locale': best['locale']!};
  }

  /// Configures engine language + voice for (lang, current gender).
  /// No-op when already configured for that combination.
  /// Every engine call is guarded — a voice-selection failure must never
  /// prevent speech; worst case we speak with the engine's default voice.
  Future<void> _applyVoice(String lang) async {
    final key = '$lang|$_gender';
    if (key == _appliedKey) return;

    try {
      await _tts.setLanguage(lang);
    } catch (e) {
      debugPrint('[TTS] setLanguage($lang) failed: $e');
    }
    _currentLang = lang;

    try {
      final voice = await _findVoice(lang, _gender);
      if (voice != null) {
        await _tts.setVoice(voice);
        await _tts.setPitch(1.0);
        debugPrint('[TTS] voice=$voice for $key');
      } else {
        // No gendered voice installed for this language — shape the default.
        await _tts.setPitch(_gender == 'female' ? 1.25 : 0.85);
        debugPrint('[TTS] no $_gender voice for $lang — pitch fallback');
      }
    } catch (e) {
      debugPrint('[TTS] voice selection failed ($e) — engine default voice');
      try {
        await _tts.setPitch(1.0);
      } catch (_) {}
    }
    _appliedKey = key;
  }

  /// True when the engine can speak [lang] (or its bare language code).
  /// Errors (e.g. unimplemented platform) are treated as "available" so we
  /// never block speech on a failed capability probe.
  Future<String?> _resolveAvailableLang(String lang) async {
    try {
      if (await _tts.isLanguageAvailable(lang) == true) return lang;
      final bare = lang.split('-').first;
      if (bare != lang && await _tts.isLanguageAvailable(bare) == true) {
        return bare;
      }
      return null;
    } catch (_) {
      return lang; // probe unsupported on this platform — just try speaking
    }
  }

  // ── Text hygiene ────────────────────────────────────────────────────────

  /// Removes artifacts that make TTS output unclear: honorific ligatures the
  /// non-Arabic engines spell out as garbage, markdown leftovers, and
  /// whitespace runs that cause unnatural pauses.
  static String _clean(String text, String lang) {
    var t = text;
    if (!lang.toLowerCase().startsWith('ar')) {
      t = t.replaceAll('ﷺ', '').replaceAll('ﷻ', ''); // ﷺ ﷻ
    }
    t = t
        .replaceAll('*', '')
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return t;
  }

  // ── Public API ──────────────────────────────────────────────────────────

  /// Speaks [text]. Returns false when the device genuinely cannot speak
  /// this language (no engine voice installed) — callers should surface
  /// that to the user instead of showing a playing state with no sound.
  Future<bool> speak(
    String text, {
    String lang = 'ar-SA',
    VoidCallback? onComplete,
  }) async {
    await _ensureInit();
    await _tts.stop();

    // A missing language pack is the #1 cause of "TTS not working":
    // speak() succeeds but the engine silently produces nothing.
    final usable = await _resolveAvailableLang(lang);
    if (usable == null) {
      debugPrint('[TTS] language not available on device: $lang');
      _speaking = false;
      return false;
    }

    await _applyVoice(usable);
    _currentText = text;
    _onComplete = onComplete;

    final cleaned = _clean(text, usable);
    var result = await _tts.speak(cleaned);
    if (result != 1) {
      // Retry once with pure engine defaults — recovers from a voice the
      // engine advertised but refuses to load (e.g. stale network voice).
      debugPrint('[TTS] speak failed with selected voice — retrying default');
      _appliedKey = null;
      _voices = null;
      try {
        await _tts.setLanguage(usable);
        await _tts.setPitch(1.0);
      } catch (_) {}
      result = await _tts.speak(cleaned);
    }
    _speaking = result == 1;
    return _speaking;
  }

  Future<void> stop() async {
    await _ensureInit();
    await _tts.stop();
    _speaking = false;
    _currentText = null;
    _onComplete = null;
  }

  Future<void> pause() async {
    await _tts.pause();
    _speaking = false;
  }

  Future<bool> resume() async {
    if (_currentText != null) {
      return speak(_currentText!, lang: _currentLang, onComplete: _onComplete);
    }
    return false;
  }
}
