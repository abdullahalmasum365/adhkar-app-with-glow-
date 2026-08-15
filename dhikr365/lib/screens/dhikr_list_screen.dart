import 'dart:ui';
import '../constants/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import '../providers/dhikr_provider.dart';
import '../providers/custom_plan_provider.dart';
import '../providers/language_provider.dart';
import '../models/dhikr.dart';
import '../providers/theme_provider.dart';
import '../widgets/dhikr_card.dart';
import '../widgets/repeat_picker.dart';
import '../utils/responsive.dart';
import '../services/audio_service.dart';
import '../services/tts_service.dart';
import 'edit_plan_screen.dart';

// ============================================================================
// DhikrListScreen — converted to StatefulWidget so we can:
//   • Listen for category completion and show a one-time celebration banner.
// ============================================================================

class DhikrListScreen extends StatefulWidget {
  final DhikrCategory category;

  const DhikrListScreen({super.key, required this.category});

  @override
  State<DhikrListScreen> createState() => _DhikrListScreenState();
}

class _DhikrListScreenState extends State<DhikrListScreen> {
  // ── Celebration state ────────────────────────────────────────────────────
  bool _showCelebration = false;
  bool _celebrationShownThisSession = false;
  DhikrProvider? _dhikrProvider;

  // ── Mini player state ────────────────────────────────────────────────────
  final AudioService _audio = AudioService();
  final TtsService   _tts   = TtsService();
  Dhikr? _activeDhikr;
  bool   _playerPlaying    = false;
  bool   _usingTts         = false;
  Duration _position = Duration.zero;
  Duration _duration  = Duration.zero;
  int _repeatTarget = 1; // how many times to play (0 = infinite)
  int _repeatsDone = 0;
  bool _completed = false; // finished all repeats — next play restarts at 0
  double? _dragProgress; // non-null while the user drags the seek bar
  bool _autoNext = false; // continuous play: auto-advance to the next dhikr
  List<Dhikr>? _navList; // currently displayed list, for prev/next

  static const _speeds = [0.75, 1.0, 1.25, 1.5];

  String get _speedLabel {
    final r = _audio.rate;
    return r == 1.0 ? '1×' : '$r×';
  }

  void _cycleSpeed() {
    HapticFeedback.selectionClick();
    final i = _speeds.indexOf(_audio.rate);
    final next = _speeds[(i + 1) % _speeds.length];
    _audio.setRate(next);
    setState(() {});
  }

  /// Jump ±[secs] within the current track (like the 10-second skips in
  /// every podcast/audio app). No-op for TTS playback.
  void _skipBy(int secs) {
    if (_usingTts || _duration == Duration.zero) return;
    HapticFeedback.selectionClick();
    var t = _position + Duration(seconds: secs);
    if (t < Duration.zero) t = Duration.zero;
    if (t > _duration) t = _duration;
    _audio.seek(t);
  }

  /// Play the previous (-1) or next (+1) dhikr in the visible list.
  Future<void> _playRelative(int dir) async {
    final list = _navList;
    if (list == null || list.isEmpty || _activeDhikr == null) return;
    final i = list.indexWhere((d) => d.id == _activeDhikr!.id);
    final j = i + dir;
    if (i == -1 || j < 0 || j >= list.length) return;
    HapticFeedback.lightImpact();
    await _audio.stop();
    await _tts.stop();
    setState(() {
      _activeDhikr   = list[j];
      _repeatsDone   = 0;
      _position      = Duration.zero;
      _duration      = Duration.zero;
      _usingTts      = false;
      _playerPlaying = false;
      _completed     = false;
    });
    await _startPlayback(list[j]);
  }

  /// Whether a prev/next neighbour exists — used to dim the buttons.
  bool _hasNeighbour(int dir) {
    final list = _navList;
    if (list == null || _activeDhikr == null) return false;
    final i = list.indexWhere((d) => d.id == _activeDhikr!.id);
    final j = i + dir;
    return i != -1 && j >= 0 && j < list.length;
  }

  /// "5×" normally; live progress "2/5×" while a multi-repeat runs.
  String get _repeatLabel {
    if (_repeatTarget == 0) {
      return _repeatsDone > 0 ? '${_repeatsDone + 1}∞' : '∞';
    }
    if (_repeatTarget > 1 && (_playerPlaying || _repeatsDone > 0)) {
      return '${(_repeatsDone + 1).clamp(1, _repeatTarget)}/$_repeatTarget×';
    }
    return '$_repeatTarget×';
  }

  void _repeatMinus() => setState(() {
        _repeatTarget = _repeatTarget == 0 ? 1 : (_repeatTarget - 1).clamp(1, 999);
      });

  void _repeatPlus() => setState(() {
        _repeatTarget = _repeatTarget == 0 ? 1 : (_repeatTarget + 1).clamp(1, 999);
      });

  Future<void> _pickRepeatCount() async {
    final v = await showRepeatPicker(context, _repeatTarget);
    if (v != null && mounted) setState(() => _repeatTarget = v);
  }

  @override
  void initState() {
    super.initState();
    // Keep the screen on while the user is reciting dhikr.
    WakelockPlus.enable();
    // We can't call Provider.of here (context is not fully wired yet), so
    // defer to the first post-frame callback.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final dp = Provider.of<DhikrProvider>(context, listen: false);
      _dhikrProvider = dp;
      if (dp.isCategoryCompleted(widget.category)) {
        _celebrationShownThisSession = true;
      }
      dp.addListener(_onProviderChanged);
    });

    // Subscribe to audio streams for mini player UI
    _audio.stateStream.listen((s) {
      if (!mounted) return;
      setState(() => _playerPlaying = s == PlayerState.playing);
    });
    _audio.positionStream.listen((p) {
      if (!mounted) return;
      setState(() => _position = p);
    });
    _audio.durationStream.listen((d) {
      if (!mounted) return;
      setState(() => _duration = d ?? Duration.zero);
    });
    _audio.onComplete.listen((_) {
      if (!mounted) return;
      _handleRepeatComplete();
    });
  }

  @override
  void dispose() {
    _dhikrProvider?.removeListener(_onProviderChanged);
    _audio.stop();
    _tts.stop();
    WakelockPlus.disable();
    super.dispose();
  }

  void _onProviderChanged() {
    if (!mounted) return;
    final dp = Provider.of<DhikrProvider>(context, listen: false);
    if (!_celebrationShownThisSession && dp.isCategoryCompleted(widget.category)) {
      _celebrationShownThisSession = true;
      setState(() => _showCelebration = true);
      // Auto-dismiss after 2.8 s
      Future.delayed(const Duration(milliseconds: 2800), () {
        if (mounted) setState(() => _showCelebration = false);
      });
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _getTitle(LanguageProvider lp) {
    switch (widget.category) {
      case DhikrCategory.morning:
        return lp.getText('morning_adhkar');
      case DhikrCategory.evening:
        return lp.getText('evening_adhkar');
      case DhikrCategory.protection:
        return lp.getText('protection');
      case DhikrCategory.focus:
        return lp.getText('focus');
      case DhikrCategory.parents:
        return lp.getText('parents');
      case DhikrCategory.graveyard:
        return lp.getText('graveyard');
      case DhikrCategory.afterSalah:
        return lp.getText('after_salah');
      case DhikrCategory.beforeSleep:
        return lp.getText('before_sleep');
      default:
        return 'Dhikr';
    }
  }

  void _showSettingsModal(BuildContext context) {
    final dhikrProvider = Provider.of<DhikrProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.shadow(0.4),
      builder: (BuildContext context) {
        final langProvider = Provider.of<LanguageProvider>(context, listen: false);
        String selectedAppLang = LanguageProvider.supportedLanguages.firstWhere((l) => l['code'] == langProvider.locale.languageCode)['name']!;
        String selectedTranslationLang = LanguageProvider.supportedLanguages.firstWhere((l) => l['code'] == langProvider.translationCode)['name']!;
        String selectedTransliterationLang = LanguageProvider.supportedLanguages.firstWhere((l) => l['code'] == langProvider.transliterationCode)['name']!;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 40,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 25.0, sigmaY: 25.0),
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppColors.playerSurface.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withOpacity(0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadow(0.5),
                          blurRadius: 40,
                        ),
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withOpacity(0.1),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Handle bar
                        Container(
                          width: 48,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.ink(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              langProvider.getText('settings').toUpperCase(),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2.0,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(Icons.close, color: AppColors.ink(0.54)),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // App Language Row
                        _buildLanguageDropdown(
                          label: langProvider.getText('app_language').toUpperCase(),
                          subLabel: "Interface language",
                          icon: Icons.language,
                          value: selectedAppLang,
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedAppLang = val);
                          },
                        ),
                        const SizedBox(height: 24),

                        // Translation Row
                        _buildLanguageDropdown(
                          label: langProvider.getText('translation_lang').toUpperCase(),
                          subLabel: "Meaning language",
                          icon: Icons.subtitles_outlined,
                          value: selectedTranslationLang,
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedTranslationLang = val);
                          },
                        ),
                        const SizedBox(height: 24),

                        // Transliteration language Row
                        _buildLanguageDropdown(
                          label: langProvider.getText('transliteration_lang').toUpperCase(),
                          subLabel: "Reading aid",
                          icon: Icons.spellcheck,
                          value: selectedTransliterationLang,
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedTransliterationLang = val);
                          },
                        ),
                        const SizedBox(height: 24),

                        // Show Transliteration toggle
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.ink(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.ink(0.1)),
                          ),
                          child: Row(
                            children: [
                              // Expanded + ellipsis: the label shrinks
                              // instead of overflowing past the Switch on
                              // narrow screens or longer translated strings.
                              Expanded(
                                child: Row(children: [
                                  Icon(Icons.spellcheck_rounded,
                                      color: AppColors.accent, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      langProvider
                                          .getText('show_transliteration')
                                          .toUpperCase(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.2,
                                        color: AppColors.textSlate400,
                                      ),
                                    ),
                                  ),
                                ]),
                              ),
                              Switch(
                                value: themeProvider.showTransliteration,
                                activeColor: AppColors.accent,
                                onChanged: (v) {
                                  themeProvider.toggleTransliteration(v);
                                  setModalState(() {});
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),
                        // Save Button
                        GestureDetector(
                          onTap: () async {
                            String appCode = LanguageProvider.supportedLanguages
                                .firstWhere((l) => l['name'] == selectedAppLang)['code']!;
                            String transCode = LanguageProvider.supportedLanguages
                                .firstWhere((l) => l['name'] == selectedTranslationLang)['code']!;
                            String translitCode = LanguageProvider.supportedLanguages
                                .firstWhere((l) => l['name'] == selectedTransliterationLang)['code']!;

                            await langProvider.setLanguage(appCode);
                            await langProvider.setTranslationLanguage(transCode);
                            await langProvider.setTransliterationLanguage(translitCode);

                            await dhikrProvider.reloadDhikrs(
                              uiLanguageCode: appCode,
                              transliterationCode: translitCode,
                              translationCode: transCode,
                            );

                            if (context.mounted) Navigator.pop(context);
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Text(
                                langProvider.getText('save_changes').toUpperCase(),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.0,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLanguageDropdown({
    required String label,
    required String subLabel,
    required IconData icon,
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFFF59E0B), size: 14),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.ink(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.ink(0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              icon: const Icon(Icons.unfold_more, color: Color(0xFFF59E0B), size: 20),
              dropdownColor: AppColors.playerSurface,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              onChanged: onChanged,
              items: LanguageProvider.supportedLanguages.map((lang) {
                return DropdownMenuItem(
                  value: lang['name'],
                  child: Text(lang['name']!),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // ── Mini player logic ────────────────────────────────────────────────────

  /// Returns the asset-relative path for this dhikr's audio, or null if none.
  /// Priority: JSON audioPath → auto-derived audio/{id}.mp3 (added by user).
  /// Never falls back to the category compilation — that would play all duas.
  String? _resolveAudioPath(Dhikr d) {
    if (d.audioPath != null && d.audioPath!.isNotEmpty) {
      return d.audioPath!.replaceFirst('assets/', '');
    }
    // Auto-derived: user can drop assets/audio/{dhikr_id}.mp3 to enable audio
    return 'audio/${d.id}.mp3';
  }

  // ── Playback helpers ─────────────────────────────────────────────────────

  /// Shows why nothing is audible and resets the player — a playing state
  /// with no sound is the worst possible feedback.
  void _showTtsUnavailable() {
    if (!mounted) return;
    setState(() {
      _playerPlaying = false;
      _usingTts = false;
      _activeDhikr = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'No voice for this language is installed on your device.\n'
          'Install it under device Settings → Text-to-Speech output.',
        ),
        backgroundColor: Colors.red.shade800,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _startPlayback(Dhikr dhikr) async {
    _completed = false;
    // Arabic recitation: MP3 first, Arabic TTS as fallback.
    // playPath stops any previous playback and starts fresh from 0:00.
    final path = _resolveAudioPath(dhikr);
    if (path != null) {
      final ok = await _audio.playPath(path);
      if (ok) { setState(() => _usingTts = false); return; }
    }
    if (dhikr.arabicText.isNotEmpty) {
      setState(() { _usingTts = true; _playerPlaying = true; });
      final ok = await _tts.speak(dhikr.arabicText, lang: 'ar-SA', onComplete: () {
        if (mounted) _handleRepeatComplete();
      });
      if (!ok) _showTtsUnavailable();
    } else {
      setState(() => _activeDhikr = null);
    }
  }

  Future<void> _onPlayTapped(Dhikr dhikr) async {
    final isSame = _activeDhikr?.id == dhikr.id;
    if (isSame && _playerPlaying) {
      if (_usingTts) { await _tts.pause(); }
      else           { await _audio.pause(); }
      setState(() => _playerPlaying = false);
      return;
    }
    if (isSame && !_playerPlaying) {
      if (_usingTts) {
        final ok = await _tts.resume();
        if (ok) setState(() => _playerPlaying = true);
      } else if (_audio.isPaused && !_completed) {
        // Paused mid-track → continue where it was.
        await _audio.resume();
      } else {
        // Track finished (or player stopped) → restart from the beginning.
        setState(() {
          _repeatsDone = 0;
          _position = Duration.zero;
        });
        await _startPlayback(dhikr);
      }
      return;
    }
    await _audio.stop();
    await _tts.stop();
    setState(() {
      _activeDhikr   = dhikr;
      _repeatsDone   = 0;
      _position      = Duration.zero;
      _duration      = Duration.zero;
      _usingTts      = false;
      _playerPlaying = false;
    });
    await _startPlayback(dhikr);
  }

  Future<void> _handleRepeatComplete() async {
    _repeatsDone++;
    if ((_repeatTarget == 0 || _repeatsDone < _repeatTarget) &&
        _activeDhikr != null) {
      await _startPlayback(_activeDhikr!);
      return;
    }
    // All repeats done. Continuous mode advances through the list —
    // repeating each dhikr its set number of times along the way.
    if (_autoNext && _hasNeighbour(1)) {
      await _playRelative(1);
      return;
    }
    setState(() {
      _playerPlaying = false;
      _repeatsDone = 0;
      _completed = true; // next play tap restarts from 0:00
    });
  }

  void _closePlayer() {
    _audio.stop();
    _tts.stop();
    setState(() {
      _activeDhikr     = null;
      _playerPlaying   = false;
      _usingTts        = false;
      _position        = Duration.zero;
      _duration        = Duration.zero;
      _repeatsDone     = 0;
      _completed       = false;
      _dragProgress    = null;
    });
  }

  Widget _buildMiniPlayer(Dhikr dhikr) {
    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    String fmt(Duration d) {
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$m:$s';
    }

    final amber = AppColors.accent;

    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: SafeArea(
        top: false,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              decoration: BoxDecoration(
                color: AppColors.playerSurface.withOpacity(0.93),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: amber.withOpacity(0.22)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow(0.55),
                    blurRadius: 32,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Handle ────────────────────────────────────────────
                  Container(
                    width: 36, height: 3,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: AppColors.ink(0.24),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // ── Title row ─────────────────────────────────────────
                  Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _usingTts
                            ? Icons.record_voice_over_rounded
                            : Icons.music_note_rounded,
                        color: amber, size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _usingTts ? 'VOICE RECITATION' : 'NOW PLAYING',
                            style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.w900,
                                letterSpacing: 1.6, color: AppColors.ink(0.38))),
                          const SizedBox(height: 1),
                          Text(dhikr.title,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Close
                    GestureDetector(
                      onTap: _closePlayer,
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.ink(0.07),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.ink(0.1)),
                        ),
                        child: Icon(Icons.close_rounded,
                            color: AppColors.ink(0.54), size: 16),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 12),

                  // ── Seek bar (MP3) or voice indicator ────────────────
                  if (_usingTts)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.record_voice_over_rounded,
                              color: amber, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            _playerPlaying ? 'RECITING ARABIC...' : 'PAUSED',
                            style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w800,
                              letterSpacing: 1.6, color: amber,
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                        activeTrackColor: amber,
                        inactiveTrackColor: AppColors.ink(0.12),
                        thumbColor: amber,
                        overlayColor: amber.withOpacity(0.18),
                      ),
                      // Drag anywhere on the bar: thumb follows the finger
                      // (no fighting with the live position stream) and the
                      // actual seek fires once, when the finger lifts.
                      child: Slider(
                        value: _dragProgress ?? progress,
                        onChangeStart: (v) =>
                            setState(() => _dragProgress = v),
                        onChanged: (v) => setState(() => _dragProgress = v),
                        onChangeEnd: (v) async {
                          final ms = (_duration.inMilliseconds * v).toInt();
                          await _audio.seek(Duration(milliseconds: ms));
                          if (mounted) setState(() => _dragProgress = null);
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              fmt(_dragProgress != null
                                  ? Duration(
                                      milliseconds: (_duration.inMilliseconds *
                                              _dragProgress!)
                                          .toInt())
                                  : _position),
                              style: TextStyle(fontSize: 11, color: AppColors.ink(0.38))),
                          Text(fmt(_duration),
                              style: TextStyle(fontSize: 11, color: AppColors.ink(0.38))),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // ── Transport: prev | −10s | PLAY | +10s | next ───────
                  // FittedBox scales the row down instead of overflowing
                  // on narrow screens.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _CircleBtn(
                        icon: Icons.skip_previous_rounded,
                        dimmed: !_hasNeighbour(-1),
                        onTap: () => _playRelative(-1),
                      ),
                      const SizedBox(width: 10),
                      _CircleBtn(
                        icon: Icons.replay_10_rounded,
                        dimmed: _usingTts,
                        onTap: () => _skipBy(-10),
                      ),
                      const SizedBox(width: 14),
                      // Play / Pause (main button)
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _onPlayTapped(dhikr);
                        },
                        child: Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: amber,
                            boxShadow: [
                              BoxShadow(
                                color: amber.withOpacity(0.4),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                          child: Icon(
                            _playerPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: AppColors.onAccent,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      _CircleBtn(
                        icon: Icons.forward_10_rounded,
                        dimmed: _usingTts,
                        onTap: () => _skipBy(10),
                      ),
                      const SizedBox(width: 10),
                      _CircleBtn(
                        icon: Icons.skip_next_rounded,
                        dimmed: !_hasNeighbour(1),
                        onTap: () => _playRelative(1),
                      ),
                    ],
                  ),
                  ),

                  const SizedBox(height: 12),

                  // ── Options: repeat − count + | speed | autoplay ──────
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Repeat − (steps down by 1, minimum 1)
                      _CircleBtn(
                        icon: Icons.remove,
                        small: true,
                        onTap: _repeatMinus,
                      ),
                      const SizedBox(width: 6),
                      // Repeat count chip — tap to TYPE an exact number
                      GestureDetector(
                        onTap: _pickRepeatCount,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.ink(0.07),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.ink(0.12)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.repeat_rounded,
                                color: amber, size: 13),
                            const SizedBox(width: 5),
                            Text(_repeatLabel,
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary)),
                            const SizedBox(width: 4),
                            Icon(Icons.edit_rounded,
                                color: AppColors.ink(0.35), size: 10),
                          ]),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Repeat + (steps up by 1, max 999)
                      _CircleBtn(
                        icon: Icons.add,
                        small: true,
                        onTap: _repeatPlus,
                      ),

                      const SizedBox(width: 16),

                      // Playback speed (0.75× → 1× → 1.25× → 1.5×)
                      GestureDetector(
                        onTap: _cycleSpeed,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: _audio.rate != 1.0
                                ? amber.withOpacity(0.15)
                                : AppColors.ink(0.07),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _audio.rate != 1.0
                                  ? amber.withOpacity(0.5)
                                  : AppColors.ink(0.12),
                            ),
                          ),
                          child: Text(_speedLabel,
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w800,
                                  color: _audio.rate != 1.0
                                      ? amber
                                      : AppColors.textPrimary)),
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Continuous play: keep going through the whole list
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _autoNext = !_autoNext);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: _autoNext
                                ? amber.withOpacity(0.15)
                                : AppColors.ink(0.07),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _autoNext
                                  ? amber.withOpacity(0.5)
                                  : AppColors.ink(0.12),
                            ),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.playlist_play_rounded,
                                color: _autoNext
                                    ? amber
                                    : AppColors.ink(0.55),
                                size: 16),
                            const SizedBox(width: 4),
                            Text('AUTO',
                                style: TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: _autoNext
                                        ? amber
                                        : AppColors.ink(0.55))),
                          ]),
                        ),
                      ),
                    ],
                  ),
                  ),
                ],
              ),
            ),
          ),
        )
            .animate()
            .slideY(begin: 1, end: 0, duration: 340.ms, curve: Curves.easeOutCubic)
            .fadeIn(duration: 200.ms),
      ),
    );
  }

  // ── Celebration banner ───────────────────────────────────────────────────

  Widget _buildCelebrationBanner(int streak) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        top: false,
        child: GestureDetector(
          onTap: () => setState(() => _showCelebration = false),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF97316), Color(0xFFEA580C)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF97316).withOpacity(0.45),
                  blurRadius: 24,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 30)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Session Complete!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        streak > 1
                            ? '$streak day streak — MashaAllah! 🌟'
                            : 'Day 1 streak started — keep it up!',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.ink(0.88),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.close, color: AppColors.ink(0.6), size: 18),
              ],
            ),
          )
              .animate()
              .slideY(
                begin: 1.2,
                end: 0.0,
                duration: 420.ms,
                curve: Curves.easeOutCubic,
              )
              .fadeIn(duration: 300.ms),
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final lp = Provider.of<LanguageProvider>(context);
    final streak = Provider.of<DhikrProvider>(context, listen: false).streakDays;

    return Scaffold(
      backgroundColor: ThemeProvider.brandDark,
      body: Stack(
        children: [
          // ── Main content ──────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [ThemeProvider.deepTeal, ThemeProvider.brandDark],
                stops: [0.0, 0.4],
              ),
            ),
            child: Column(
              children: [
                // Custom Header
                SafeArea(
                  bottom: false,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(R.px(12), R.px(12), R.px(8), R.px(20)),
                    decoration: BoxDecoration(
                      color: ThemeProvider.deepTeal.withOpacity(0.4),
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.ink(0.05),
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Top Row: Back, Title, Actions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(Icons.arrow_back_ios_new,
                                  color: AppColors.textPrimary, size: 20),
                              style: IconButton.styleFrom(
                                backgroundColor: AppColors.ink(0.0),
                                hoverColor: AppColors.ink(0.1),
                              ),
                            ),
                            Expanded(
                              child: Consumer<LanguageProvider>(
                                builder: (context, lp, _) => Text(
                                  _getTitle(lp).toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2.0,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (Provider.of<CustomPlanProvider>(context,
                                        listen: false)
                                    .useCustomPlan)
                                  IconButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                EditPlanScreen(category: widget.category)),
                                      );
                                    },
                                    icon: Icon(Icons.edit_document,
                                        color: ThemeProvider.divineAmber, size: 22),
                                  ),
                                IconButton(
                                  onPressed: () {
                                    _showSettingsModal(context);
                                  },
                                  icon: Icon(Icons.settings_input_component,
                                      color: AppColors.textPrimary, size: 22),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Progress Section
                        Consumer2<DhikrProvider, CustomPlanProvider>(builder:
                            (context, provider, customPlanProvider, child) {
                          List<Dhikr> dhikrs;
                          if (widget.category == DhikrCategory.morning) {
                            dhikrs = provider.getMorningDhikrs();
                          } else if (widget.category == DhikrCategory.evening) {
                            dhikrs = provider.getEveningDhikrs();
                          } else if (widget.category == DhikrCategory.focus) {
                            dhikrs = provider.getFocusDhikrs();
                          } else if (widget.category == DhikrCategory.parents) {
                            dhikrs = provider.getParentsDhikrs();
                          } else if (widget.category == DhikrCategory.graveyard) {
                            dhikrs = provider.getGraveyardDhikrs();
                          } else if (widget.category == DhikrCategory.food) {
                            dhikrs = provider.getFoodDhikrs();
                          } else if (widget.category == DhikrCategory.afterSalah) {
                            dhikrs = provider.getAfterSalahDhikrs();
                          } else if (widget.category == DhikrCategory.beforeSleep) {
                            dhikrs = provider.getBeforeSleepDhikrs();
                          } else {
                            dhikrs = provider.getProtectionDhikrs();
                          }

                          List<Dhikr> displayList = [...dhikrs];
                          if (customPlanProvider.useCustomPlan) {
                            displayList = displayList
                                .where(
                                    (d) => customPlanProvider.isDhikrEnabled(d.id))
                                .toList();
                          }

                          final List<Dhikr> allDhikrs = displayList;

                          int totalDhikrs = allDhikrs.length;
                          int completedDhikrs = allDhikrs
                              .where((d) => d.currentCount >= d.targetCount)
                              .length;
                          double progress =
                              totalDhikrs > 0 ? completedDhikrs / totalDhikrs : 0;

                          return Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      lp.getText('your_progress').toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                        color: AppColors.ink(0.60),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      "$completedDhikrs / $totalDhikrs ${lp.getText('completed').toUpperCase()}",
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.0,
                                        color: ThemeProvider.divineAmber,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 6,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: AppColors.ink(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: progress,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: ThemeProvider.divineAmber,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: ThemeProvider.divineAmber
                                              .withOpacity(0.5),
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                // List View
                Expanded(
                  child: Consumer2<DhikrProvider, CustomPlanProvider>(
                    builder: (context, provider, customPlanProvider, child) {
                      List<Dhikr> dhikrs;
                      if (widget.category == DhikrCategory.morning) {
                        dhikrs = provider.getMorningDhikrs();
                      } else if (widget.category == DhikrCategory.evening) {
                        dhikrs = provider.getEveningDhikrs();
                      } else if (widget.category == DhikrCategory.focus) {
                        dhikrs = provider.getFocusDhikrs();
                      } else if (widget.category == DhikrCategory.parents) {
                        dhikrs = provider.getParentsDhikrs();
                      } else if (widget.category == DhikrCategory.graveyard) {
                        dhikrs = provider.getGraveyardDhikrs();
                      } else if (widget.category == DhikrCategory.food) {
                        dhikrs = provider.getFoodDhikrs();
                      } else if (widget.category == DhikrCategory.afterSalah) {
                        dhikrs = provider.getAfterSalahDhikrs();
                      } else if (widget.category == DhikrCategory.beforeSleep) {
                        dhikrs = provider.getBeforeSleepDhikrs();
                      } else {
                        dhikrs = provider.getProtectionDhikrs();
                      }

                      List<Dhikr> displayList = [...dhikrs];
                      if (customPlanProvider.useCustomPlan) {
                        displayList = displayList
                            .where((d) => customPlanProvider.isDhikrEnabled(d.id))
                            .toList();
                      }

                      if (customPlanProvider.useCustomPlan && displayList.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2_outlined,
                                  size: 60, color: AppColors.ink(0.2)),
                              const SizedBox(height: 16),
                              Text(
                                lp.getText('plan_empty'),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.ink(0.70),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                lp.getText('plan_empty_desc'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.ink(0.38),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            EditPlanScreen(category: widget.category)),
                                  );
                                },
                                icon: const Icon(Icons.edit_document, size: 16),
                                label: Text(lp.getText('edit_my_plan')),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ThemeProvider.divineAmber,
                                  foregroundColor: ThemeProvider.brandDark,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn().slideY(begin: 0.2, end: 0);
                      }

                      // Snapshot for the mini player's prev/next navigation.
                      _navList = displayList;
                      return ListView.builder(
                        padding: EdgeInsets.only(
                            bottom: _activeDhikr != null ? R.px(240) : R.px(100),
                            top: R.px(16)),
                        itemCount: displayList.length,
                        itemBuilder: (context, index) {
                          final d = displayList[index];
                          return DhikrCard(
                            dhikr: d,
                            onPlayTapped: _onPlayTapped,
                            isActive: _activeDhikr?.id == d.id,
                            isPlaying: _activeDhikr?.id == d.id && _playerPlaying,
                          )
                              .animate()
                              .fadeIn(delay: (50 * index).ms)
                              .slideY(begin: 0.1, end: 0);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // ── Mini player (shown when a card's play button is tapped) ──────────
          if (_activeDhikr != null) _buildMiniPlayer(_activeDhikr!),

          // ── Celebration overlay (shown once when category completes) ───────
          if (_showCelebration) _buildCelebrationBanner(streak),
        ],
      ),
    );
  }
}

// ── Small circular icon button used in the mini player ────────────────────────
class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool dimmed; // visually disabled (e.g. no next track)
  final bool small;
  const _CircleBtn(
      {required this.icon,
      required this.onTap,
      this.dimmed = false,
      this.small = false});

  @override
  Widget build(BuildContext context) {
    final size = small ? 30.0 : 38.0;
    return GestureDetector(
      onTap: dimmed ? null : onTap,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.ink(dimmed ? 0.03 : 0.07),
          border: Border.all(color: AppColors.ink(dimmed ? 0.06 : 0.12)),
        ),
        child: Icon(icon,
            color: AppColors.ink(dimmed ? 0.20 : 0.70),
            size: small ? 16 : 20),
      ),
    );
  }
}
