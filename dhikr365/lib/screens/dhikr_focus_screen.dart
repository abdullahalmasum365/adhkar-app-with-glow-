import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/dhikr.dart';
import '../providers/dhikr_provider.dart';
import '../providers/language_provider.dart';
import '../providers/theme_provider.dart';
import '../services/audio_service.dart';
import '../services/tts_service.dart';
import '../constants/app_theme.dart';
import '../utils/responsive.dart';

class DhikrFocusScreen extends StatefulWidget {
  final Dhikr dhikr;
  const DhikrFocusScreen({super.key, required this.dhikr});
  @override
  State<DhikrFocusScreen> createState() => _DhikrFocusScreenState();
}

class _DhikrFocusScreenState extends State<DhikrFocusScreen> {
  int  _count   = 0;
  bool _pressed = false;

  // ── Mini player state ───────────────────────────────────────────────────
  final AudioService _audio = AudioService();
  final TtsService   _tts   = TtsService();
  bool _showPlayer     = false;
  bool _playerPlaying  = false;
  bool _usingTts       = false;
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
    WakelockPlus.enable();
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

  String? _resolveAudioPath() {
    final p = widget.dhikr.audioPath;
    if (p != null && p.isNotEmpty) return p.replaceFirst('assets/', '');
    return 'audio/${widget.dhikr.id}.mp3';
  }

  /// Shows why nothing is audible and resets the player — a playing state
  /// with no sound is the worst possible feedback.
  void _showTtsUnavailable() {
    if (!mounted) return;
    setState(() {
      _playerPlaying = false;
      _usingTts = false;
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

  Future<void> _startPlayback() async {
    // Arabic recitation: MP3 first, Arabic TTS as fallback.
    final path = _resolveAudioPath();
    if (path != null) {
      final ok = await _audio.playPath(path);
      if (ok) { setState(() => _usingTts = false); return; }
    }
    if (widget.dhikr.arabicText.isNotEmpty) {
      setState(() { _usingTts = true; _playerPlaying = true; });
      final ok = await _tts.speak(widget.dhikr.arabicText, lang: 'ar-SA', onComplete: () {
        if (mounted) _handleRepeatComplete();
      });
      if (!ok) _showTtsUnavailable();
    } else {
      setState(() => _showPlayer = false);
    }
  }

  Future<void> _handleRepeatComplete() async {
    _repeatsDone++;
    final target = _repeatOptions[_repeatIdx];
    if (target == 0 || _repeatsDone < target) {
      await _startPlayback();
    } else {
      setState(() { _playerPlaying = false; _repeatsDone = 0; });
    }
  }

  void _tap() {
    setState(() => _count++);
    Provider.of<DhikrProvider>(context, listen: false)
        .incrementDhikr(widget.dhikr.id);
    _count % 100 == 0
        ? HapticFeedback.heavyImpact()
        : HapticFeedback.lightImpact();

    final t = widget.dhikr.targetCount;
    if (t > 0 && _count == t && mounted) {
      HapticFeedback.vibrate();
      final lp = Provider.of<LanguageProvider>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(lp.getText('target_reached'),
            style: AppText.manrope(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.primary,
        duration: const Duration(milliseconds: 1800),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _togglePlayer() {
    if (_showPlayer) {
      _audio.stop();
      _tts.stop();
      setState(() {
        _showPlayer      = false;
        _usingTts        = false;
        _position        = Duration.zero;
        _duration        = Duration.zero;
        _repeatsDone     = 0;
        _playerPlaying   = false;
      });
    } else {
      setState(() { _showPlayer = true; _repeatsDone = 0; _usingTts = false; });
      _startPlayback();
    }
  }

  void _onPlayPause() {
    if (_playerPlaying) {
      if (_usingTts) { _tts.pause(); }
      else           { _audio.pause(); }
      setState(() => _playerPlaying = false);
    } else {
      if (_usingTts) {
        _tts.resume().then((ok) {
          if (mounted && ok) setState(() => _playerPlaying = true);
        });
      } else if (_audio.isPaused) {
        _audio.resume();
      } else {
        _startPlayback();
      }
    }
  }

  @override
  void dispose() {
    _audio.stop();
    _tts.stop();
    WakelockPlus.disable();
    super.dispose();
  }

  // ── Mini player (shown above the footer tap button) ──────────────────────

  Widget _buildMiniPlayer() {
    const amber = Color(0xFFF59E0B);
    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    String fmt(Duration d) {
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$m:$s';
    }

    return Positioned(
      left: 0, right: 0, bottom: R.px(180),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: R.px(14)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: BoxDecoration(
                color: const Color(0xFF042F2E).withOpacity(0.93),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: amber.withOpacity(0.22)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 24),
                ],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Title + close
                Row(children: [
                  Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _usingTts
                          ? Icons.record_voice_over_rounded
                          : Icons.music_note_rounded,
                      color: amber, size: 15,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(widget.dhikr.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                  GestureDetector(
                    onTap: _togglePlayer,
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.07),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white54, size: 14),
                    ),
                  ),
                ]),

                // Seek bar (MP3) or TTS indicator
                if (_usingTts)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.record_voice_over_rounded,
                            color: amber, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          _playerPlaying ? 'RECITING ARABIC...' : 'PAUSED',
                          style: const TextStyle(
                            fontSize: 9, fontWeight: FontWeight.w800,
                            letterSpacing: 1.4, color: amber,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2.5,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 4),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 10),
                      activeTrackColor: amber,
                      inactiveTrackColor: Colors.white12,
                      thumbColor: amber,
                      overlayColor: amber.withOpacity(0.15),
                    ),
                    child: Slider(
                      value: progress,
                      onChanged: (v) {
                        final ms = (_duration.inMilliseconds * v).toInt();
                        _audio.seek(Duration(milliseconds: ms));
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(fmt(_position),
                          style: const TextStyle(
                              fontSize: 10, color: Colors.white38)),
                      Text(fmt(_duration),
                          style: const TextStyle(
                              fontSize: 10, color: Colors.white38)),
                    ],
                  ),
                ],

                const SizedBox(height: 10),

                // Repeat controls + play/pause
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _SmallBtn(Icons.remove, onTap: () => setState(() {
                    _repeatIdx = (_repeatIdx - 1 + _repeatOptions.length)
                        % _repeatOptions.length;
                  })),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.repeat_rounded,
                          color: amber, size: 12),
                      const SizedBox(width: 5),
                      Text(_repeatLabel,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  _SmallBtn(Icons.add, onTap: () => setState(() {
                    _repeatIdx = (_repeatIdx + 1) % _repeatOptions.length;
                  })),
                  const SizedBox(width: 22),
                  GestureDetector(
                    onTap: _onPlayPause,
                    child: Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: amber,
                        boxShadow: [
                          BoxShadow(
                              color: amber.withOpacity(0.35), blurRadius: 14),
                        ],
                      ),
                      child: Icon(
                        _playerPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.black, size: 26),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        )
            .animate()
            .slideY(begin: 0.3, end: 0, duration: 300.ms,
                curve: Curves.easeOutCubic)
            .fadeIn(duration: 200.ms),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);

    final lp           = Provider.of<LanguageProvider>(context);
    final showTranslit = Provider.of<ThemeProvider>(context).showTransliteration;
    final target       = widget.dhikr.targetCount;
    final label      = target > 0 ? '$target' : '∞';
    final prog       = target > 0 ? (_count / target).clamp(0.0, 1.0) : null;
    final arabicSize = R.adaptive(28.0, 36.0, 44.0);
    final countSize  = R.adaptive(40.0, 48.0, 58.0);
    final btnPadV    = R.adaptive(22.0, 28.0, 36.0);
    final headerPad  = R.px(18);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF042F2E), AppColors.bgDark],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Stack(children: [
            Column(children: [
              // ── Header ────────────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(
                    headerPad, headerPad, headerPad, R.px(10)),
                child: Row(children: [
                  _Btn(Icons.close, onTap: () => Navigator.pop(context)),
                  Expanded(child: Column(children: [
                    Text(lp.getText('focus_mode').toUpperCase(),
                        style: AppText.label(color: Colors.white38)),
                    SizedBox(height: R.px(2)),
                    Text(widget.dhikr.title.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: AppText.label(color: AppColors.primary),
                        overflow: TextOverflow.ellipsis),
                  ])),
                  Row(children: [
                    _Btn(Icons.refresh,
                        onTap: () => setState(() => _count = 0)),
                    SizedBox(width: R.px(8)),
                    _Btn(
                      _showPlayer ? Icons.music_note_rounded : Icons.play_arrow,
                      color: _showPlayer
                          ? AppColors.primary.withOpacity(0.25)
                          : Colors.white.withOpacity(0.06),
                      border: _showPlayer
                          ? AppColors.primary.withOpacity(0.4)
                          : Colors.white.withOpacity(0.1),
                      iconColor: _showPlayer ? AppColors.primary : Colors.white70,
                      onTap: _togglePlayer,
                    ),
                  ]),
                ]),
              ),

              if (prog != null)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: R.px(22)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: prog,
                      minHeight: 3,
                      backgroundColor: Colors.white.withOpacity(0.08),
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                ),

              // ── Scrollable text ───────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                      R.px(28), R.px(20), R.px(28), R.h(35)),
                  child: Column(children: [
                    // Arabic
                    Text(
                      widget.dhikr.arabicText,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: AppText.amiri(
                          fontSize: arabicSize,
                          color: const Color(0xFFFDFCF0)),
                    ),

                    SizedBox(height: R.px(28)),

                    // FIX: Transliteration uses NotoSerif for full diacritic support
                    // ā ū ī ḥ ḍ ṭ ẓ ṣ now render correctly on all devices
                    if (showTranslit && widget.dhikr.transliteration?.isNotEmpty == true) ...[
                      Text(
                        widget.dhikr.transliteration!,
                        textAlign: TextAlign.center,
                        style: AppText.transliteration(
                          fontSize: R.adaptive(13.0, 15.0, 18.0),
                          color: AppColors.textSlate400,
                        ),
                      ),
                      SizedBox(height: R.px(28)),
                    ],

                    // Translation
                    Text(
                      '"${widget.dhikr.translation}"',
                      textAlign: TextAlign.center,
                      style: AppText.manrope(
                          fontSize: R.adaptive(14, 16, 18),
                          height: 1.7,
                          color: const Color(0xFFFDFCF0).withOpacity(0.85)),
                    ),
                  ]),
                ),
              ),
            ]),

            // ── Mini audio player ─────────────────────────────────────────────
            if (_showPlayer) _buildMiniPlayer(),

            // ── Tap Button Footer ─────────────────────────────────────────────
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                    R.px(20), R.px(48), R.px(20), R.px(40)),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      AppColors.bgDark,
                      AppColors.bgDark.withOpacity(0.9),
                      AppColors.bgDark.withOpacity(0.0),
                    ],
                  ),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  GestureDetector(
                    onTapDown: (_) => setState(() => _pressed = true),
                    onTapUp: (_) {
                      setState(() => _pressed = false);
                      _tap();
                    },
                    onTapCancel: () => setState(() => _pressed = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: btnPadV),
                      transform: Matrix4.identity()
                        ..scale(_pressed ? 0.97 : 1.0),
                      transformAlignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(R.px(24)),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary
                                .withOpacity(_pressed ? 0.5 : 0.25),
                            blurRadius: _pressed ? 40 : 20,
                          ),
                        ],
                      ),
                      child: Column(children: [
                        Text(lp.getText('tap_to_count').toUpperCase(),
                            style: AppText.label(
                                color: Colors.white.withOpacity(0.8))),
                        SizedBox(height: R.px(6)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '$_count',
                              style: AppText.manrope(
                                  fontSize: countSize,
                                  fontWeight: FontWeight.w900,
                                  height: 1.0),
                            ),
                            SizedBox(width: R.px(6)),
                            Text(
                              '/ $label',
                              style: AppText.manrope(
                                  fontSize: R.adaptive(12, 14, 16),
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white38),
                            ),
                          ],
                        ),
                      ]),
                    ),
                  ),
                  if (widget.dhikr.benefit?.isNotEmpty == true) ...[
                    SizedBox(height: R.px(12)),
                    Text(
                      widget.dhikr.benefit!.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: AppText.label(color: Colors.white30),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color, border, iconColor;

  const _Btn(this.icon,
      {required this.onTap, this.color, this.border, this.iconColor});

  @override
  Widget build(BuildContext context) {
    final size = R.adaptive(34.0, 38.0, 44.0);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color ?? Colors.white.withOpacity(0.06),
          border:
              Border.all(color: border ?? Colors.white.withOpacity(0.1)),
        ),
        child: Icon(icon,
            size: R.sp(17),
            color: iconColor ?? Colors.white.withOpacity(0.7)),
      ),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SmallBtn(this.icon, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.07),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Icon(icon, color: Colors.white70, size: 16),
      ),
    );
  }
}
