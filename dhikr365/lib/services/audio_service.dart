import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/dhikr.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal() {
    _player.onPlayerStateChanged.listen((s) => _state = s);
  }

  final AudioPlayer _player = AudioPlayer();
  PlayerState _state = PlayerState.stopped;
  DhikrCategory? _currentCategory;
  String? _currentPath;
  double _rate = 1.0;

  /// Playback speed (0.5–2.0). Persists across tracks for the session.
  double get rate => _rate;

  Future<void> setRate(double r) async {
    _rate = r.clamp(0.5, 2.0);
    try {
      await _player.setPlaybackRate(_rate);
    } catch (e) {
      debugPrint('[Audio] setRate: $e');
    }
  }

  DhikrCategory? get currentCategory => _currentCategory;
  String? get currentPath => _currentPath;
  bool get isPlaying => _state == PlayerState.playing;
  bool get isPaused => _state == PlayerState.paused;

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
    }
  }

  /// Play a specific asset path. Returns false if the file doesn't exist or playback fails.
  Future<bool> playPath(String path) async {
    try {
      final cleanPath = path.replaceFirst('assets/', '');
      // Pre-check: rootBundle.load throws FlutterError if asset isn't in bundle.
      // Catching it here prevents the unhandled exception from escaping.
      await rootBundle.load('assets/$cleanPath');
      _currentPath = cleanPath;
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.release);
      await _player.play(AssetSource(cleanPath));
      // Re-apply the session playback speed — a fresh source resets it.
      if (_rate != 1.0) await _player.setPlaybackRate(_rate);
      return true;
    } catch (e) {
      debugPrint('[Audio] playPath: asset not found or playback failed — $e');
      return false;
    }
  }

  /// Play audio for a dhikr category. Returns false if file not found.
  Future<bool> playCategory(DhikrCategory category) async {
    try {
      if (_currentCategory != category) {
        await _player.stop();
        _currentCategory = category;
      }
      _currentPath = assetPath(category);
      await _player.play(AssetSource(assetPath(category)));
      return true;
    } catch (e) {
      debugPrint('[Audio] Play failed: $e');
      return false;
    }
  }

  Future<void> pause() async {
    try { await _player.pause(); } catch (e) { debugPrint('[Audio] Pause: $e'); }
  }

  Future<void> resume() async {
    try { await _player.resume(); } catch (e) { debugPrint('[Audio] Resume: $e'); }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
      _currentCategory = null;
      _currentPath = null;
    } catch (e) { debugPrint('[Audio] Stop: $e'); }
  }

  Future<void> seek(Duration position) async {
    try { await _player.seek(position); } catch (_) {}
  }

  Future<void> play(String? path, {int repeatCount = 1}) async {
    if (path == null || path.isEmpty) return;
    try {
      await _player.stop();
      final mode = repeatCount < 0 ? ReleaseMode.loop : ReleaseMode.release;
      await _player.setReleaseMode(mode);
      _currentPath = path.replaceFirst('assets/', '');
      await _player.play(AssetSource(_currentPath!));
    } catch (e) {
      debugPrint('[Audio] play($path) failed: $e');
    }
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
