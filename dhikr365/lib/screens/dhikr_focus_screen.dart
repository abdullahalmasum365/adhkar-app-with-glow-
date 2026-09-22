import 'dart:async';
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
import '../widgets/repeat_picker.dart';

class DhikrFocusScreen extends StatefulWidget {
  final Dhikr dhikr;
  const DhikrFocusScreen({super.key, required this.dhikr});
  @override
  State<DhikrFocusScreen> createState() => _DhikrFocusScreenState();
}

class _DhikrFocusScreenState extends State<DhikrFocusScreen> {
  int _count = 0;
  bool _pressed = false;

  // ── Mini player state ───────────────────────────────────────────────────
  final AudioService _audio = AudioService();
  final TtsService _tts = TtsService();
  bool _showPlayer = false;
  bool _playerPlaying = false;
  bool _usingTts = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  int _repeatTarget = 1; // how many times to play (0 = infinite)
  int _repeatsDone = 0;
  bool _completed = false; // finished all repeats — next play restarts at 0
  double? _dragProgress; // non-null while the user drags the seek bar
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<void>? _completeSub;

  static const _speeds = [0.75, 1.0, 1.25, 1.5];

  String get _speedLabel {
    final r = _audio.rate;
    return r == 1.0 ? '1×' : '$r×';
  }

  void _cycleSpeed() {
    HapticFeedback.selectionClick();
    final i = _speeds.indexOf(_audio.rate);
    _audio.setRate(_speeds[(i + 1) % _speeds.length]);
    setState(() {});
  }

  /// Jump ±[secs] within the current track. No-op for TTS playback.
  void _skipBy(int secs) {
    if (_usingTts || _duration == Duration.zero) return;
    HapticFeedback.selectionClick();
    var t = _position + Duration(seconds: secs);
    if (t < Duration.zero) t = Duration.zero;
    if (t > _duration) t = _duration;
    _audio.seek(t);
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
        _repeatTarget =
            _repeatTarget == 0 ? 1 : (_repeatTarget - 1).clamp(1, 999);
      });

  void _repeatPlus() => setState(() {
        _repeatTarget =
            _repeatTarget == 0 ? 1 : (_repeatTarget + 1).clamp(1, 999);
      });

  Future<void> _pickRepeatCount() async {
    final v = await showRepeatPicker(context, _repeatTarget);
    if (v != null && mounted) setState(() => _repeatTarget = v);
  }

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _stateSub = _audio.stateStream.listen((s) {
      if (!mounted) return;
      setState(() => _playerPlaying = s == PlayerState.playing);
    });
    _posSub = _audio.positionStream.listen((p) {
      if (!mounted) return;
      setState(() => _position = p);
    });
    _durSub = _audio.durationStream.listen((d) {
      if (!mounted) return;
      setState(() => _duration = d ?? Duration.zero);
    });
    _completeSub = _audio.onComplete.listen((_) {
      if (!mounted) return;
      _handleRepeatComplete();
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _completeSub?.cancel();
    _audio.stop();
    _tts.stop();
    WakelockPlus.disable();
    super.dispose();
  }

  String? _resolveAudioPath() {
    return AudioService.resolveAudioPath(
        widget.dhikr.id, widget.dhikr.audioPath);
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
    _completed = false;
    // Arabic recitation: MP3 first, Arabic TTS as fallback.
    // playPath stops any previous playback and starts fresh from 0:00.
    final path = _resolveAudioPath();
    if (path != null) {
      final ok = await _audio.playPath(path);
      if (ok) {
        setState(() => _usingTts = false);
        return;
      }
    }
    if (widget.dhikr.arabicText.isNotEmpty) {
      setState(() {
        _usingTts = true;
        _playerPlaying = true;
      });
      final ok = await _tts.speak(widget.dhikr.arabicText, lang: 'ar-SA',
          onComplete: () {
        if (mounted) _handleRepeatComplete();
      });
      if (!ok) _showTtsUnavailable();
    } else {
      setState(() => _showPlayer = false);
    }
  }

  Future<void> _handleRepeatComplete() async {
    _repeatsDone++;
    if (_repeatTarget == 0 || _repeatsDone < _repeatTarget) {
      await _startPlayback();
    } else {
      setState(() {
        _playerPlaying = false;
        _repeatsDone = 0;
        _completed = true; // next play tap restarts from 0:00
      });
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
            style: AppText.manrope(
                fontWeight: FontWeight.w700, color: AppColors.onPrimary)),
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
        _showPlayer = false;
        _usingTts = false;
        _position = Duration.zero;
        _duration = Duration.zero;
        _repeatsDone = 0;
        _playerPlaying = false;
        _completed = false;
        _dragProgress = null;
      });
    } else {
      setState(() {
        _showPlayer = true;
        _repeatsDone = 0;
        _usingTts = false;
      });
      _startPlayback();
    }
  }

  void _onPlayPause() {
    if (_playerPlaying) {
      if (_usingTts) {
        _tts.pause();
      } else {
        _audio.pause();
      }
      setState(() => _playerPlaying = false);
    } else {
      if (_usingTts) {
        _tts.resume().then((ok) {
          if (mounted && ok) setState(() => _playerPlaying = true);
        });
      } else if (_audio.isPaused && !_completed) {
        // Paused mid-track → continue where it was.
        _audio.resume();
      } else {
        // Track finished (or player stopped) → restart from the beginning.
        setState(() {
          _repeatsDone = 0;
          _position = Duration.zero;
        });
        _startPlayback();
      }
    }
  }

  // ── Mini player (shown above the footer tap button) ──────────────────────

  Widget _buildMiniPlayer() {
    final amber = AppColors.accent;
    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    String fmt(Duration d) {
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$m:$s';
    }

    return Positioned(
      // High enough to clear the tap-button footer (~205px incl. benefit
      // line) on every screen size — R.px scales with screen width just
      // like the footer's own paddings, so the relationship holds.
      left: 0, right: 0, bottom: R.px(235),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: R.px(14)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: BoxDecoration(
                color: AppColors.playerSurface.withValues(alpha: 0.93),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: amber.withValues(alpha: 0.22)),
                boxShadow: [
                  BoxShadow(color: AppColors.shadow(0.4), blurRadius: 24),
                ],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Title + close
                Row(children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _usingTts
                          ? Icons.record_voice_over_rounded
                          : Icons.music_note_rounded,
                      color: amber,
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(widget.dhikr.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                  ),
                  GestureDetector(
                    onTap: _togglePlayer,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.ink(0.07),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close_rounded,
                          color: AppColors.ink(0.54), size: 14),
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
                        Icon(Icons.record_voice_over_rounded,
                            color: amber, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          _playerPlaying ? 'RECITING ARABIC...' : 'PAUSED',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                            color: amber,
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
                      inactiveTrackColor: AppColors.ink(0.12),
                      thumbColor: amber,
                      overlayColor: amber.withValues(alpha: 0.15),
                    ),
                    // Drag anywhere on the bar: thumb follows the finger
                    // (no fighting with the live position stream) and the
                    // actual seek fires once, when the finger lifts.
                    child: Slider(
                      value: _dragProgress ?? progress,
                      onChangeStart: (v) => setState(() => _dragProgress = v),
                      onChanged: (v) => setState(() => _dragProgress = v),
                      onChangeEnd: (v) async {
                        final ms = (_duration.inMilliseconds * v).toInt();
                        await _audio.seek(Duration(milliseconds: ms));
                        if (mounted) setState(() => _dragProgress = null);
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                          fmt(_dragProgress != null
                              ? Duration(
                                  milliseconds: (_duration.inMilliseconds *
                                          _dragProgress!)
                                      .toInt())
                              : _position),
                          style: TextStyle(
                              fontSize: 10, color: AppColors.ink(0.38))),
                      Text(fmt(_duration),
                          style: TextStyle(
                              fontSize: 10, color: AppColors.ink(0.38))),
                    ],
                  ),
                ],

                const SizedBox(height: 10),

                // Repeat controls + play/pause
                // ── Transport: −10s | play | +10s ─────────────────────
                // FittedBox scales the row down instead of overflowing on
                // narrow screens.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    _SmallBtn(Icons.replay_10_rounded,
                        onTap: () => _skipBy(-10)),
                    const SizedBox(width: 14),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _onPlayPause();
                      },
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: amber,
                          boxShadow: [
                            BoxShadow(
                                color: amber.withValues(alpha: 0.35),
                                blurRadius: 14),
                          ],
                        ),
                        child: Icon(
                            _playerPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: AppColors.onAccent,
                            size: 26),
                      ),
                    ),
                    const SizedBox(width: 14),
                    _SmallBtn(Icons.forward_10_rounded,
                        onTap: () => _skipBy(10)),
                  ]),
                ),

                const SizedBox(height: 10),

                // ── Options: repeat − count + | speed ──────────────────
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    // Repeat − (steps down by 1, minimum 1)
                    _SmallBtn(Icons.remove, onTap: _repeatMinus),
                    const SizedBox(width: 8),
                    // Repeat count chip — tap to TYPE an exact number
                    GestureDetector(
                      onTap: _pickRepeatCount,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.ink(0.07),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.ink(0.1)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.repeat_rounded, color: amber, size: 12),
                          const SizedBox(width: 5),
                          Text(_repeatLabel,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)),
                          const SizedBox(width: 4),
                          Icon(Icons.edit_rounded,
                              color: AppColors.ink(0.35), size: 10),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Repeat + (steps up by 1, max 999)
                    _SmallBtn(Icons.add, onTap: _repeatPlus),
                    const SizedBox(width: 12),
                    // Playback speed (0.75× → 1× → 1.25× → 1.5×)
                    GestureDetector(
                      onTap: _cycleSpeed,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _audio.rate != 1.0
                              ? amber.withValues(alpha: 0.15)
                              : AppColors.ink(0.07),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _audio.rate != 1.0
                                ? amber.withValues(alpha: 0.5)
                                : AppColors.ink(0.1),
                          ),
                        ),
                        child: Text(_speedLabel,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: _audio.rate != 1.0
                                    ? amber
                                    : AppColors.textPrimary)),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        )
            .animate()
            .slideY(
                begin: 0.3,
                end: 0,
                duration: 300.ms,
                curve: Curves.easeOutCubic)
            .fadeIn(duration: 200.ms),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);

    final lp = Provider.of<LanguageProvider>(context);
    final showTranslit =
        Provider.of<ThemeProvider>(context).showTransliteration;
    final target = widget.dhikr.targetCount;
    final label = target > 0 ? '$target' : '∞';
    final prog = target > 0 ? (_count / target).clamp(0.0, 1.0) : null;
    final arabicSize = R.adaptive(28.0, 36.0, 44.0);
    final countSize = R.adaptive(40.0, 48.0, 58.0);
    final btnPadV = R.adaptive(22.0, 28.0, 36.0);
    final headerPad = R.px(18);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.playerSurface, AppColors.bgDark],
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
                  Expanded(
                      child: Column(children: [
                    Text(lp.getText('focus_mode').toUpperCase(),
                        style: AppText.label(color: AppColors.ink(0.38))),
                    SizedBox(height: R.px(2)),
                    Text(widget.dhikr.title.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: AppText.label(color: AppColors.primary),
                        overflow: TextOverflow.ellipsis),
                  ])),
                  Row(children: [
                    _Btn(Icons.refresh,
                        onTap: () => setState(() => _count = 0)),
                    // Audio button: shown for every dhikr that has an audio recording available.
                    // If no recording is available, it is omitted.
                    if (widget.dhikr.hasAudio) ...[
                      SizedBox(width: R.px(8)),
                      _Btn(
                        _showPlayer
                            ? Icons.music_note_rounded
                            : Icons.play_arrow,
                        color: _showPlayer
                            ? AppColors.primary.withValues(alpha: 0.25)
                            : AppColors.ink(0.06),
                        border: _showPlayer
                            ? AppColors.primary.withValues(alpha: 0.4)
                            : AppColors.ink(0.1),
                        iconColor: _showPlayer
                            ? AppColors.primary
                            : AppColors.ink(0.70),
                        onTap: _togglePlayer,
                      ),
                    ],
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
                      backgroundColor: AppColors.ink(0.08),
                      valueColor: AlwaysStoppedAnimation(AppColors.primary),
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
                      // Palette-aware: warm cream on dark themes, deep ink
                      // on light themes — always readable.
                      style: AppText.amiri(
                          fontSize: arabicSize, color: ThemeProvider.cream),
                    ),

                    SizedBox(height: R.px(28)),

                    // FIX: Transliteration uses NotoSerif for full diacritic support
                    // ā ū ī ḥ ḍ ṭ ẓ ṣ now render correctly on all devices
                    if (showTranslit &&
                        widget.dhikr.transliteration?.isNotEmpty == true) ...[
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
                          color: ThemeProvider.cream.withValues(alpha: 0.85)),
                    ),
                  ]),
                ),
              ),
            ]),

            // ── Tap Button Footer ─────────────────────────────────────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding:
                    EdgeInsets.fromLTRB(R.px(20), R.px(48), R.px(20), R.px(40)),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      AppColors.bgDark,
                      AppColors.bgDark.withValues(alpha: 0.9),
                      AppColors.bgDark.withValues(alpha: 0.0),
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
                        // ignore: deprecated_member_use
                        ..scale(_pressed ? 0.97 : 1.0),
                      transformAlignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(R.px(24)),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [AppColors.primary, AppColors.accent],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary
                                .withValues(alpha: _pressed ? 0.5 : 0.25),
                            blurRadius: _pressed ? 40 : 20,
                          ),
                        ],
                      ),
                      child: Column(children: [
                        Text(lp.getText('tap_to_count').toUpperCase(),
                            style: AppText.label(color: AppColors.ink(0.8))),
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
                                  color: AppColors.ink(0.38)),
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
                      style: AppText.label(color: AppColors.ink(0.30)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ]),
              ),
            ),

            // ── Mini audio player ─────────────────────────────────────────────
            // Painted LAST so it always sits on top of the tap-button footer —
            // it can never be hidden behind the counter.
            if (_showPlayer) _buildMiniPlayer(),
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
          color: color ?? AppColors.ink(0.06),
          border: Border.all(color: border ?? AppColors.ink(0.1)),
        ),
        child:
            Icon(icon, size: R.sp(17), color: iconColor ?? AppColors.ink(0.7)),
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
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.ink(0.07),
          border: Border.all(color: AppColors.ink(0.12)),
        ),
        child: Icon(icon, color: AppColors.ink(0.70), size: 16),
      ),
    );
  }
}
