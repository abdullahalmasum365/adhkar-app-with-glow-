import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _locale               = const Locale('en');
  String _translationCode      = 'en';
  String _transliterationCode  = 'en';
  final Map<String, Map<String, String>> _cache = {};
  bool _loaded = false;

  final _loadCompleter = Completer<void>();
  /// Resolves once the saved language/translation/transliteration codes have
  /// been read from storage. Callers that need the REAL saved values (not
  /// the 'en' constructor default) must await this first — see
  /// SplashScreen, which uses it to re-sync DhikrProvider's content language
  /// on every cold start.
  Future<void> get loadFuture => _loadCompleter.future;

  Locale get locale              => _locale;
  String get translationCode     => _translationCode;
  String get transliterationCode => _transliterationCode;
  bool   get isLoaded            => _loaded;
  bool   get isRTL => _locale.languageCode == 'ar' || _locale.languageCode == 'ur';
  String get greeting => getText('greeting');

  static const List<Map<String, String>> supportedLanguages = [
    {'code':'en','name':'English','nativeName':'English'},
    {'code':'ar','name':'Arabic','nativeName':'العربية'},
    {'code':'fr','name':'French','nativeName':'Français'},
    {'code':'ur','name':'Urdu','nativeName':'اردو'},
    {'code':'hi','name':'Hindi','nativeName':'हिन्दी'},
    {'code':'bn','name':'Bengali','nativeName':'বাংলা'},
    {'code':'ru','name':'Russian','nativeName':'Русский'},
    {'code':'es','name':'Spanish','nativeName':'Español'},
    {'code':'pt','name':'Portuguese','nativeName':'Português'},
    {'code':'de','name':'German','nativeName':'Deutsch'},
    {'code':'it','name':'Italian','nativeName':'Italiano'},
    {'code':'nl','name':'Dutch','nativeName':'Nederlands'},
    {'code':'tr','name':'Turkish','nativeName':'Türkçe'},
    {'code':'ms','name':'Malay','nativeName':'Bahasa Melayu'},
    {'code':'id','name':'Indonesian','nativeName':'Bahasa Indonesia'},
    {'code':'th','name':'Thai','nativeName':'ภาษาไทย'},
    {'code':'ja','name':'Japanese','nativeName':'日本語'},
    {'code':'zh','name':'Chinese (Simplified)','nativeName':'简体中文'},
    {'code':'ta','name':'Tamil','nativeName':'தமிழ்'},
  ];

  LanguageProvider() { _init(); }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('language_code') ?? 'en';
    _locale = Locale(code);
    _translationCode = prefs.getString('translation_code') ?? code;
    _transliterationCode = prefs.getString('transliteration_code') ?? code;
    await _load('en');
    if (code != 'en') await _load(code);
    if (_translationCode != code) await _load(_translationCode);
    if (_transliterationCode != code && _transliterationCode != _translationCode) {
      await _load(_transliterationCode);
    }
    _loaded = true;
    if (!_loadCompleter.isCompleted) _loadCompleter.complete();
    notifyListeners();
  }

  Future<void> _load(String code) async {
    if (_cache.containsKey(code)) return;
    try {
      final raw = await rootBundle.loadString('assets/i18n/$code.json');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _cache[code] = map.map((k, v) => MapEntry(k, v.toString()));
    } catch (e) {
      debugPrint('[LanguageProvider] Could not load $code.json: $e');
      _cache[code] = _cache['en'] ?? {};
    }
  }

  String getText(String key) {
    return _cache[_locale.languageCode]?[key] ?? _cache['en']?[key] ?? key;
  }

  bool _valid(String code) => supportedLanguages.any((l) => l['code'] == code);

  Future<void> setLanguage(String code) async {
    if (!_valid(code)) return;
    await _load(code);
    _locale = Locale(code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', code);
    notifyListeners();
  }

  Future<void> setTranslationLanguage(String code) async {
    if (!_valid(code)) return;
    await _load(code);
    _translationCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('translation_code', code);
    notifyListeners();
  }

  Future<void> setTransliterationLanguage(String code) async {
    if (!_valid(code)) return;
    await _load(code);
    _transliterationCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('transliteration_code', code);
    notifyListeners();
  }
}
