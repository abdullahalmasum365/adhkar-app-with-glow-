import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/dhikr.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;

  AudioPlayer _player = AudioPlayer();
  PlayerState _state = PlayerState.stopped;
  DhikrCategory? _currentCategory;
  String? _currentPath;
  double _rate = 1.0;
  bool _isDisposed = false;

  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<void>? _completeSubscription;

  AudioService._internal() {
    _initSubscriptions();
  }

  void _initSubscriptions() {
    _stateSubscription?.cancel();
    _completeSubscription?.cancel();

    _stateSubscription = _player.onPlayerStateChanged.listen(
      (s) => _state = s,
      onError: (e) {
        debugPrint('[AudioService] onPlayerStateChanged error: $e');
        _state = PlayerState.stopped;
      },
    );

    _completeSubscription = _player.onPlayerComplete.listen(
      (_) {
        _state = PlayerState.completed;
      },
      onError: (e) {
        debugPrint('[AudioService] onPlayerComplete error: $e');
        _state = PlayerState.stopped;
      },
    );
  }

  /// Re-instantiates the AudioPlayer if it was previously disposed,
  /// preventing StateError when calling singleton methods after teardown.
  void _ensureActive() {
    if (_isDisposed) {
      _player = AudioPlayer();
      _isDisposed = false;
      _initSubscriptions();
    }
  }

  /// Playback speed (0.5–2.0). Persists across tracks for the session.
  double get rate => _rate;

  Future<void> setRate(double r) async {
    _rate = r.clamp(0.5, 2.0);
    _ensureActive();
    try {
      await _player.setPlaybackRate(_rate);
    } catch (e) {
      debugPrint('[AudioService] setRate failed: $e');
    }
  }

  DhikrCategory? get currentCategory => _currentCategory;
  String? get currentPath => _currentPath;
  bool get isPlaying => _state == PlayerState.playing;
  bool get isPaused => _state == PlayerState.paused;
  bool get isDisposed => _isDisposed;

  Stream<PlayerState> get stateStream => _player.onPlayerStateChanged;
  Stream<Duration> get positionStream => _player.onPositionChanged;
  Stream<Duration?> get durationStream => _player.onDurationChanged;
  Stream<void> get onComplete => _player.onPlayerComplete;

  static String assetPath(DhikrCategory category) {
    switch (category) {
      case DhikrCategory.morning:    return 'audio/morning.mp3';
      case DhikrCategory.evening:    return 'audio/evening.mp3';
      case DhikrCategory.protection: return 'audio/protection.mp3';
      case DhikrCategory.focus:      return 'audio/focus.mp3';
      case DhikrCategory.parents:    return 'audio/parents.mp3';
      case DhikrCategory.food:       return 'audio/food.mp3';
      case DhikrCategory.graveyard:  return 'audio/graveyard.mp3';
      case DhikrCategory.afterSalah: return 'audio/after_salah.mp3';
      case DhikrCategory.beforeSleep: return 'audio/before_sleep.mp3';
      case DhikrCategory.travel:     return 'audio/travel.mp3';
      case DhikrCategory.shifa:      return 'audio/shifa.mp3';
      case DhikrCategory.distress:   return 'audio/distress.mp3';
    }
  }

  /// All verified available audio recording IDs in assets/audio/
  static const Set<String> availableAudioIds = {
    'distress',
    'distress_anguish_yunus',
    'distress_anxiety_grief',
    'distress_debt_settlement',
    'distress_difficult_affair',
    'distress_worry_grief',
    'evening_e_afwa_wal_afiyah',
    'evening_e_alhamdulillah',
    'evening_e_allahu_akbar',
    'evening_e_allahumma_afini',
    'evening_e_allahumma_ajirni_min_nar',
    'evening_e_allahumma_bika_amsayna',
    'evening_e_allahumma_fatir',
    'evening_e_allahumma_inni_amsaytu',
    'evening_e_allahumma_ma_amsa',
    'evening_e_amsayna_ala_fitrah',
    'evening_e_amsayna_wal_mulku',
    'evening_e_astaghfirullah',
    'evening_e_audhu_bikalimatillah',
    'evening_e_ayatulkursi',
    'evening_e_bismillah_la_yadurr',
    'evening_e_evening_prayer_good_night',
    'evening_e_falaq',
    'evening_e_hasbiyallah',
    'evening_e_ikhlas',
    'evening_e_la_ilaha_illa_allah_10',
    'evening_e_nas',
    'evening_e_radhitu_billah',
    'evening_e_salawat_alan_nabi',
    'evening_e_sayyidul_istighfar',
    'evening_e_subhanallah',
    'evening_e_subhanallah_bihamdihi_100',
    'evening_e_ya_hayyu_ya_qayyum',
    'focus_1',
    'focus_2',
    'focus_3',
    'focus_4',
    'focus_5',
    'focus_6',
    'focus_7',
    'focus_8',
    'focus_9',
    'focus_10',
    'food_aftara_indakum',
    'food_alhamdulillah_ataani',
    'food_alhamdulillah_kathiran',
    'food_atim_man_atamani',
    'food_barik_lana_fihi',
    'food_bismillah_awwalihi',
    'food_breaking_fast',
    'food_breaking_fast_forgiveness',
    'food_dua_for_host',
    'grave_salaam_aisha',
    'grave_salaam_buraidah',
    'morning_m_afwa_wal_afiyah',
    'morning_m_alhamdulillah',
    'morning_m_allahu_akbar',
    'morning_m_allahumma_afini',
    'morning_m_allahumma_ajirni_min_nar',
    'morning_m_allahumma_ashhaduka',
    'morning_m_allahumma_bika_asbahna',
    'morning_m_allahumma_fatir',
    'morning_m_allahumma_ilman_nafian',
    'morning_m_allahumma_ma_asbaha',
    'morning_m_asbahna_ala_fitrah',
    'morning_m_asbahna_wal_mulku',
    'morning_m_astaghfirullah',
    'morning_m_ayatulkursi',
    'morning_m_bismillah_la_yadurr',
    'morning_m_falaq',
    'morning_m_hasbiyallah',
    'morning_m_ikhlas',
    'morning_m_la_ilaha_illa_allah_10',
    'morning_m_morning_blessings',
    'morning_m_nas',
    'morning_m_radhitu_billah',
    'morning_m_salawat_alan_nabi',
    'morning_m_sayyidul_istighfar',
    'morning_m_subhanallah',
    'morning_m_subhanallah_bihamdihi_100',
    'morning_m_subhanallah_bihamdihi_3',
    'morning_m_ya_hayyu_ya_qayyum',
    'parents_rabbanaghfir',
    'parents_rabbi_awzini',
    'parents_rabbighfir_nuh',
    'parents_rabbir_hamhuma',
    'protection_1',
    'protection_2',
    'protection_3',
    'protection_4',
    'protection_5',
    'salah_astaghfirullah_salam',
    'salah_ayatul_kursi',
    'salah_falaq',
    'salah_ikhlas',
    'salah_ilman_nafian',
    'salah_la_hawla',
    'salah_la_ilaha_wahdahu',
    'salah_la_ilaha_yuhyi',
    'salah_nas',
    'salah_tasbih_after_prayer',
    'shifa',
    'shifa_calamity',
    'shifa_pain_in_body',
    'shifa_visiting_sick_1',
    'shifa_visiting_sick_2',
    'sleep_alhamdulillah_atamana',
    'sleep_allahumma_alimal_ghaybi',
    'sleep_allahumma_aslamtu_nafsi',
    'sleep_allahumma_khalaqta_nafsi',
    'sleep_allahumma_qini_adhabaka',
    'sleep_allahumma_rabbas_samawati',
    'sleep_ayatul_kursi',
    'sleep_bismika_amutu_wa_ahya',
    'sleep_bismika_wadatu_janbi',
    'sleep_falaq',
    'sleep_ikhlas',
    'sleep_last_two_ayat_baqarah',
    'sleep_nas',
    'sleep_tasbih_fatimi',
    'travel',
    'travel_market',
    'travel_returning',
    'travel_riding_vehicle',
    'travel_supplication',
  };

  /// Returns true if an audio recording exists for this ID or path.
  static bool hasAudioForId(String id) {
    final clean = id
        .replaceFirst('assets/', '')
        .replaceFirst('audio/', '')
        .replaceAll('.mp3', '');
    return availableAudioIds.contains(clean);
  }

  /// Returns the asset-relative path if available, or null if no recording exists.
  static String? resolveAudioPath(String id, [String? explicitPath]) {
    if (explicitPath != null && explicitPath.isNotEmpty) {
      final clean = explicitPath
          .replaceFirst('assets/', '')
          .replaceFirst('audio/', '')
          .replaceAll('.mp3', '');
      if (availableAudioIds.contains(clean)) {
        return 'audio/$clean.mp3';
      }
    }
    final cleanId = id
        .replaceFirst('assets/', '')
        .replaceFirst('audio/', '')
        .replaceAll('.mp3', '');
    if (availableAudioIds.contains(cleanId)) {
      return 'audio/$cleanId.mp3';
    }
    return null;
  }

  /// Play a specific asset path. Returns false if the file doesn't exist or playback fails.
  Future<bool> playPath(String path) async {
    _ensureActive();
    try {
      final cleanPath = path.replaceFirst('assets/', '');
      // Pre-check: rootBundle.load throws FlutterError if asset isn't in bundle.
      final byteData = await rootBundle.load('assets/$cleanPath');
      if (byteData.lengthInBytes == 0) {
        debugPrint('[AudioService] Asset is empty (0 bytes): assets/$cleanPath');
        _state = PlayerState.stopped;
        _currentPath = null;
        return false;
      }

      _currentPath = cleanPath;
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.release);
      await _player.play(AssetSource(cleanPath));
      // Re-apply the session playback speed — a fresh source resets it.
      if (_rate != 1.0) await _player.setPlaybackRate(_rate);
      return true;
    } catch (e) {
      debugPrint('[AudioService] playPath: asset not found or playback failed — $e');
      _state = PlayerState.stopped;
      _currentPath = null;
      try {
        await _player.stop();
      } catch (_) {}
      return false;
    }
  }

  /// Play audio for a dhikr category. Returns false if file not found.
  Future<bool> playCategory(DhikrCategory category) async {
    _ensureActive();
    try {
      final path = assetPath(category);
      final byteData = await rootBundle.load('assets/$path');
      if (byteData.lengthInBytes == 0) {
        debugPrint('[AudioService] Category asset is empty: assets/$path');
        _state = PlayerState.stopped;
        _currentCategory = null;
        _currentPath = null;
        return false;
      }

      if (_currentCategory != category) {
        await _player.stop();
        _currentCategory = category;
      }
      _currentPath = path;
      await _player.play(AssetSource(path));
      if (_rate != 1.0) await _player.setPlaybackRate(_rate);
      return true;
    } catch (e) {
      debugPrint('[AudioService] playCategory failed: $e');
      _state = PlayerState.stopped;
      _currentCategory = null;
      _currentPath = null;
      try {
        await _player.stop();
      } catch (_) {}
      return false;
    }
  }

  Future<void> pause() async {
    if (_isDisposed) return;
    try {
      await _player.pause();
    } catch (e) {
      debugPrint('[AudioService] Pause: $e');
    }
  }

  Future<void> resume() async {
    _ensureActive();
    try {
      await _player.resume();
    } catch (e) {
      debugPrint('[AudioService] Resume: $e');
    }
  }

  Future<void> stop() async {
    if (_isDisposed) return;
    try {
      await _player.stop();
      _state = PlayerState.stopped;
      _currentCategory = null;
      _currentPath = null;
    } catch (e) {
      debugPrint('[AudioService] Stop: $e');
    }
  }

  Future<void> seek(Duration position) async {
    _ensureActive();
    try {
      await _player.seek(position);
    } catch (e) {
      debugPrint('[AudioService] Seek failed: $e');
    }
  }

  /// Jump directly to an exact millisecond timestamp (used by synced lyrics/segments).
  Future<void> seekMs(int ms) => seek(Duration(milliseconds: ms));

  Future<void> play(String? path, {int repeatCount = 1}) async {
    if (path == null || path.isEmpty) return;
    _ensureActive();
    try {
      final cleanPath = path.replaceFirst('assets/', '');
      final byteData = await rootBundle.load('assets/$cleanPath');
      if (byteData.lengthInBytes == 0) {
        debugPrint('[AudioService] Asset is empty: assets/$cleanPath');
        _state = PlayerState.stopped;
        _currentPath = null;
        return;
      }

      await _player.stop();
      final mode = repeatCount < 0 ? ReleaseMode.loop : ReleaseMode.release;
      await _player.setReleaseMode(mode);
      _currentPath = cleanPath;
      await _player.play(AssetSource(cleanPath));
      if (_rate != 1.0) await _player.setPlaybackRate(_rate);
    } catch (e) {
      debugPrint('[AudioService] play($path) failed: $e');
      _state = PlayerState.stopped;
      _currentPath = null;
      try {
        await _player.stop();
      } catch (_) {}
    }
  }

  /// Disposes audio streams and AudioPlayer instance to release hardware decoders
  /// and prevent memory leaks.
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    try {
      await _stateSubscription?.cancel();
      _stateSubscription = null;
      await _completeSubscription?.cancel();
      _completeSubscription = null;
      await _player.stop();
      await _player.dispose();
      _state = PlayerState.stopped;
      _currentCategory = null;
      _currentPath = null;
    } catch (e) {
      debugPrint('[AudioService] dispose failed: $e');
    }
  }
}
