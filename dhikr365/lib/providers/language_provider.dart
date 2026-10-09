import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _locale               = const Locale('en');
  String _translationCode      = 'en';
  String _transliterationCode  = 'en';
  final Map<String, Map<String, String>> _cache = {};
  bool _loaded = false;
  String? _uid;

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
    if (_uid != null) unawaited(_pushToCloud());
  }

  Future<void> setTranslationLanguage(String code) async {
    if (!_valid(code)) return;
    await _load(code);
    _translationCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('translation_code', code);
    notifyListeners();
    if (_uid != null) unawaited(_pushToCloud());
  }

  Future<void> setTransliterationLanguage(String code) async {
    if (!_valid(code)) return;
    await _load(code);
    _transliterationCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('transliteration_code', code);
    notifyListeners();
    if (_uid != null) unawaited(_pushToCloud());
  }

  // ── Cloud Firestore Sync ──────────────────────────────────────────────────

  DocumentReference<Map<String, dynamic>>? get _cloudDoc {
    if (_uid == null || Firebase.apps.isEmpty) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('settings')
        .doc('language');
  }

  /// Called whenever the signed-in user changes. Restores saved language,
  /// translation, and transliteration codes from Cloud Firestore.
  Future<void> attachUser(String? uid) async {
    if (uid == _uid) return;
    _uid = uid;
    if (uid == null || Firebase.apps.isEmpty) return;

    try {
      final doc = _cloudDoc;
      if (doc == null) return;
      final snap = await doc.get();

      if (snap.exists) {
        final data = snap.data()!;
        final cloudLang = data['languageCode'] as String?;
        final cloudTrans = data['translationCode'] as String?;
        final cloudTranslit = data['transliterationCode'] as String?;

        bool languageChanged = false;

        if (cloudLang != null &&
            cloudLang.isNotEmpty &&
            cloudLang != _locale.languageCode &&
            _valid(cloudLang)) {
          await setLanguage(cloudLang);
          languageChanged = true;
        }
        if (cloudTrans != null &&
            cloudTrans.isNotEmpty &&
            cloudTrans != _translationCode &&
            _valid(cloudTrans)) {
          await setTranslationLanguage(cloudTrans);
          languageChanged = true;
        }
        if (cloudTranslit != null &&
            cloudTranslit.isNotEmpty &&
            cloudTranslit != _transliterationCode &&
            _valid(cloudTranslit)) {
          await setTransliterationLanguage(cloudTranslit);
          languageChanged = true;
        }

        if (languageChanged && _onCloudLanguageLoaded != null) {
          await _onCloudLanguageLoaded!(
            _locale.languageCode,
            _translationCode,
            _transliterationCode,
          );
        }
      } else {
        await _pushToCloud();
      }
    } catch (e) {
      debugPrint('[LanguageProvider] cloud sync on sign-in failed: $e');
    }
  }

  Future<void> Function(String ui, String trans, String translit)?
      _onCloudLanguageLoaded;

  void setOnCloudLanguageLoaded(
    Future<void> Function(String ui, String trans, String translit)? callback,
  ) {
    _onCloudLanguageLoaded = callback;
  }

  Future<void> _pushToCloud() async {
    final doc = _cloudDoc;
    if (doc == null) return;
    try {
      final currentAuthUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentAuthUid == null || currentAuthUid != _uid) return;

      await doc.set({
        'languageCode': _locale.languageCode,
        'translationCode': _translationCode,
        'transliterationCode': _transliterationCode,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[LanguageProvider] cloud push failed: $e');
    }
  }
}
