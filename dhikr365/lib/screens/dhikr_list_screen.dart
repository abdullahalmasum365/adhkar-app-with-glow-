import 'dart:ui';
import 'package:flutter/material.dart';
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
  static const _repeatOptions = [1, 2, 3, 5, 10, 0];
  int _repeatIdx  = 0;
  int _repeatsDone = 0;

  String get _repeatLabel {
    final t = _repeatOptions[_repeatIdx];
    return t == 0 ? '∞' : '$t×';
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
      barrierColor: Colors.black.withOpacity(0.4),
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
                      color: const Color(0xFF042F2E).withOpacity(0.85),
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withOpacity(0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
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
                            color: Colors.white.withOpacity(0.2),
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
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2.0,
                                color: Colors.white,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close, color: Colors.white54),
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
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(children: [
                                const Icon(Icons.spellcheck_rounded,
                                    color: Color(0xFFF59E0B), size: 18),
                                const SizedBox(width: 10),
                                Text(
                                  langProvider.getText('show_transliteration').toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2, color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ]),
                              Switch(
                                value: themeProvider.showTransliteration,
                                activeColor: const Color(0xFFF59E0B),
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
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.0,
                                  color: Colors.white,
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
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              icon: const Icon(Icons.unfold_more, color: Color(0xFFF59E0B), size: 20),
              dropdownColor: const Color(0xFF042F2E),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
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
    // Arabic recitation: MP3 first, Arabic TTS as fallback.
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
      } else {
        await _audio.resume();
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
    final target = _repeatOptions[_repeatIdx];
    if ((target == 0 || _repeatsDone < target) && _activeDhikr != null) {
      await _startPlayback(_activeDhikr!);
    } else {
      setState(() { _playerPlaying = false; _repeatsDone = 0; });
    }
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

    const amber = Color(0xFFF59E0B);

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
                color: const Color(0xFF042F2E).withOpacity(0.93),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: amber.withOpacity(0.22)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.55),
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
                      color: Colors.white24,
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
                            style: const TextStyle(
                                fontSize: 9, fontWeight: FontWeight.w900,
                                letterSpacing: 1.6, color: Colors.white38)),
                          const SizedBox(height: 1),
                          Text(dhikr.title,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700,
                                  color: Colors.white)),
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
                          color: Colors.white.withOpacity(0.07),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white54, size: 16),
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
                          const Icon(Icons.record_voice_over_rounded,
                              color: amber, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            _playerPlaying ? 'RECITING ARABIC...' : 'PAUSED',
                            style: const TextStyle(
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
                        inactiveTrackColor: Colors.white12,
                        thumbColor: amber,
                        overlayColor: amber.withOpacity(0.18),
                      ),
                      child: Slider(
                        value: progress,
                        onChanged: (v) {
                          final ms = (_duration.inMilliseconds * v).toInt();
                          _audio.seek(Duration(milliseconds: ms));
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(fmt(_position),
                              style: const TextStyle(fontSize: 11, color: Colors.white38)),
                          Text(fmt(_duration),
                              style: const TextStyle(fontSize: 11, color: Colors.white38)),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // ── Controls: repeat − | count | +    play/pause ──────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Repeat −
                      _CircleBtn(
                        icon: Icons.remove,
                        onTap: () => setState(() {
                          _repeatIdx = (_repeatIdx - 1 + _repeatOptions.length)
                              % _repeatOptions.length;
                        }),
                      ),
                      const SizedBox(width: 8),
                      // Repeat count chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.12)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.repeat_rounded,
                              color: amber, size: 14),
                          const SizedBox(width: 6),
                          Text(_repeatLabel,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      // Repeat +
                      _CircleBtn(
                        icon: Icons.add,
                        onTap: () => setState(() {
                          _repeatIdx = (_repeatIdx + 1) % _repeatOptions.length;
                        }),
                      ),

                      const SizedBox(width: 28),

                      // Play / Pause (main button)
                      GestureDetector(
                        onTap: () => _onPlayTapped(dhikr),
                        child: Container(
                          width: 54, height: 54,
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
                            color: Colors.black,
                            size: 30,
                          ),
                        ),
                      ),
                    ],
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
                      const Text(
                        'Session Complete!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        streak > 1
                            ? '$streak day streak — MashaAllah! 🌟'
                            : 'Day 1 streak started — keep it up!',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.88),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.close, color: Colors.white.withOpacity(0.6), size: 18),
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
            decoration: const BoxDecoration(
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
                          color: Colors.white.withOpacity(0.05),
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
                              icon: const Icon(Icons.arrow_back_ios_new,
                                  color: Colors.white, size: 20),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.0),
                                hoverColor: Colors.white.withOpacity(0.1),
                              ),
                            ),
                            Expanded(
                              child: Consumer<LanguageProvider>(
                                builder: (context, lp, _) => Text(
                                  _getTitle(lp).toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2.0,
                                    color: Colors.white,
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
                                    icon: const Icon(Icons.edit_document,
                                        color: ThemeProvider.divineAmber, size: 22),
                                  ),
                                IconButton(
                                  onPressed: () {
                                    _showSettingsModal(context);
                                  },
                                  icon: const Icon(Icons.settings_input_component,
                                      color: Colors.white, size: 22),
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
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                        color: Colors.white60,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      "$completedDhikrs / $totalDhikrs ${lp.getText('completed').toUpperCase()}",
                                      style: const TextStyle(
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
                                  color: Colors.white.withOpacity(0.1),
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
                                  size: 60, color: Colors.white.withOpacity(0.2)),
                              const SizedBox(height: 16),
                              Text(
                                lp.getText('plan_empty'),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                lp.getText('plan_empty_desc'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white38,
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
  const _CircleBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.07),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Icon(icon, color: Colors.white70, size: 18),
      ),
    );
  }
}
