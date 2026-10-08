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
import '../widgets/social_share_card.dart';
import '../widgets/time_synced_dhikr_view.dart';

class DhikrFocusScreen extends StatefulWidget {
  final Dhikr dhikr;
  const DhikrFocusScreen({super.key, required this.dhikr});
  @override
  State<DhikrFocusScreen> createState() => _DhikrFocusScreenState();
}

class _DhikrFocusScreenState extends State<DhikrFocusScreen> {
  bool _pressed = false;
  int _scaleAnimKey = 0;
  bool _isGlowActive = false;

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

  void _tap(int currentCount, int targetCount) async {
    final dp = Provider.of<DhikrProvider>(context, listen: false);
    final milestone = await dp.incrementDhikr(widget.dhikr.id);
    await DhikrProvider.triggerMilestoneHaptic(milestone);

    if (milestone == MilestoneType.thirtyThree ||
        milestone == MilestoneType.sixtySix) {
      if (mounted) {
        setState(() {
          _scaleAnimKey++;
        });
      }
    } else if (milestone == MilestoneType.target ||
        milestone == MilestoneType.hundred) {
      unawaited(DhikrProvider.playCompletionSound());
      if (mounted) {
        setState(() {
          _isGlowActive = true;
        });
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            setState(() => _isGlowActive = false);
          }
        });

        final lp = Provider.of<LanguageProvider>(context, listen: false);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lp.getText('target_reached'),
                  style: AppText.manrope(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: ThemeProvider.divineAmber,
          duration: const Duration(milliseconds: 2200),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  Widget _buildFocusCountText({
    required int count,
    required bool isDone,
    required double countSize,
  }) {
    Widget text = Text(
      '$count',
      style: AppText.manrope(
        fontSize: countSize,
        fontWeight: FontWeight.w900,
        color: (_isGlowActive || isDone)
            ? ThemeProvider.divineAmber
            : AppColors.textPrimary,
        height: 1.0,
      ),
    );

    if (_scaleAnimKey > 0) {
      text = text
          .animate(key: ValueKey('focus_milestone_$_scaleAnimKey'))
          .scale(
            duration: 125.ms,
            begin: const Offset(1.0, 1.0),
            end: const Offset(1.3, 1.3),
            curve: Curves.easeOut,
          )
          .then()
          .scale(
            duration: 125.ms,
            begin: const Offset(1.3, 1.3),
            end: const Offset(1.0, 1.0),
            curve: Curves.easeIn,
          );
    }
    return text;
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

  // ── Mini player (shown as a floating card) ──────────────────────────────
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
      left: 0,
      right: 0,
      bottom: R.px(42),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {}, // Absorb taps so mini player interactions don't count
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: R.px(14)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                decoration: BoxDecoration(
                  color: AppColors.playerSurface.withValues(alpha: 0.94),
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

                  // Transport: −10s | play | +10s
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

                  // Options: repeat − count + | speed
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      _SmallBtn(Icons.remove, onTap: _repeatMinus),
                      const SizedBox(width: 8),
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
                      _SmallBtn(Icons.add, onTap: _repeatPlus),
                      const SizedBox(width: 12),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);

    final lp = Provider.of<LanguageProvider>(context);
    final showTranslit =
        Provider.of<ThemeProvider>(context).showTransliteration;

    // ── Single Source of Truth from DhikrProvider ───────────────────────────
    final dp = Provider.of<DhikrProvider>(context);
    final currentDhikr = dp.dhikrs.firstWhere(
      (d) => d.id == widget.dhikr.id,
      orElse: () => widget.dhikr,
    );
    final count = currentDhikr.currentCount;
    final target = currentDhikr.targetCount;
    final isDone = target > 0 && count >= target;
    final remaining = target > 0 ? (target - count).clamp(0, target) : 0;
    final label = target > 0 ? '$target' : '∞';
    final prog = target > 0 ? (count / target).clamp(0.0, 1.0) : null;

    final arabicSize = R.adaptive(26.0, 32.0, 38.0);
    final countSize = R.adaptive(38.0, 46.0, 54.0);
    final ringSize = R.adaptive(145.0, 170.0, 195.0);
    final headerPad = R.px(16);

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          _tap(count, target);
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.playerSurface, AppColors.bgDark],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Column(
                  children: [
                    // ── Zen Header ───────────────────────────────────────────
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                          headerPad, headerPad, headerPad, R.px(6)),
                      child: Row(
                        children: [
                          _Btn(
                            Icons.close_rounded,
                            onTap: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  lp.getText('focus_mode').toUpperCase(),
                                  style: AppText.label(color: AppColors.ink(0.38)),
                                ),
                                SizedBox(height: R.px(2)),
                                Text(
                                  widget.dhikr.title.toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style: AppText.label(color: AppColors.primary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (currentDhikr.hasTimestamps) ...[
                                  SizedBox(height: R.px(3)),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.lyrics_rounded,
                                        size: R.sp(10),
                                        color: ThemeProvider.divineAmber,
                                      ),
                                      SizedBox(width: R.px(3)),
                                      Text(
                                        'SYNCED RECITATION',
                                        style: TextStyle(
                                          fontSize: R.sp(8.0),
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.8,
                                          color: ThemeProvider.divineAmber,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              _Btn(
                                Icons.share_rounded,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  SocialShareCard.shareDhikrAsImage(
                                    context: context,
                                    dhikr: currentDhikr,
                                    showTransliteration: showTranslit,
                                  );
                                },
                              ),
                              SizedBox(width: R.px(8)),
                              _Btn(
                                Icons.refresh_rounded,
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  Provider.of<DhikrProvider>(context, listen: false)
                                      .resetDhikr(widget.dhikr.id);
                                },
                              ),
                              if (widget.dhikr.hasAudio) ...[
                                SizedBox(width: R.px(8)),
                                _Btn(
                                  _showPlayer
                                      ? Icons.music_note_rounded
                                      : Icons.play_arrow_rounded,
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
                            ],
                          ),
                        ],
                      ),
                    ),

                    if (prog != null)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: R.px(22)),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: prog,
                            minHeight: 2.5,
                            backgroundColor: AppColors.ink(0.08),
                            valueColor: AlwaysStoppedAnimation(
                              isDone ? ThemeProvider.divineAmber : AppColors.primary,
                            ),
                          ),
                        ),
                      ),

                    // ── Compact Counter Pill when Audio Player is Active ───────
                    if (_showPlayer)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          R.px(20),
                          R.px(6),
                          R.px(20),
                          R.px(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () => _tap(count, target),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: R.px(16),
                                  vertical: R.px(6),
                                ),
                                decoration: BoxDecoration(
                                  color: (_isGlowActive || isDone
                                          ? ThemeProvider.divineAmber
                                          : AppColors.primary)
                                      .withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: (_isGlowActive || isDone
                                            ? ThemeProvider.divineAmber
                                            : AppColors.primary)
                                        .withValues(alpha: 0.35),
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '📿 $count',
                                      style: AppText.manrope(
                                        fontSize: R.adaptive(16.0, 18.0, 20.0),
                                        fontWeight: FontWeight.w900,
                                        color: (_isGlowActive || isDone)
                                            ? ThemeProvider.divineAmber
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      ' / $label',
                                      style: AppText.manrope(
                                        fontSize: R.adaptive(12.5, 14.0, 15.5),
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.ink(0.50),
                                      ),
                                    ),
                                    SizedBox(width: R.px(8)),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: R.px(8),
                                        vertical: R.px(2),
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDone
                                            ? ThemeProvider.divineAmber
                                                .withValues(alpha: 0.20)
                                            : AppColors.ink(0.08),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        isDone
                                            ? '✓ ${lp.getText('completed').toUpperCase()}'
                                            : '$remaining ${lp.getText('remaining')}',
                                        style: TextStyle(
                                          fontSize: R.sp(9.5),
                                          fontWeight: FontWeight.w800,
                                          color: isDone
                                              ? ThemeProvider.divineAmber
                                              : AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ── Upper Section: Arabic & Text / Time-Synced View ──────
                    Expanded(
                      child: (currentDhikr.hasTimestamps &&
                              _showPlayer &&
                              currentDhikr.resolvedTimestamps != null)
                          ? TimeSyncedDhikrView(
                              segments: currentDhikr.resolvedTimestamps!,
                              showTransliteration: showTranslit,
                              onBackgroundTap: () => _tap(count, target),
                            )
                          : Center(
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                padding: EdgeInsets.fromLTRB(
                                    R.px(24), R.px(16), R.px(24), R.px(10)),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Arabic Text
                                    Text(
                                      widget.dhikr.arabicText,
                                      textAlign: TextAlign.center,
                                      textDirection: TextDirection.rtl,
                                      style: AppText.amiri(
                                        fontSize: arabicSize,
                                        color: ThemeProvider.cream,
                                      ),
                                    ),

                                    if (showTranslit &&
                                        widget.dhikr.transliteration?.isNotEmpty == true) ...[
                                      SizedBox(height: R.px(18)),
                                      Text(
                                        widget.dhikr.transliteration!,
                                        textAlign: TextAlign.center,
                                        style: AppText.transliteration(
                                          fontSize: R.adaptive(12.5, 14.5, 17.0),
                                          color: AppColors.textSlate400,
                                        ),
                                      ),
                                    ],

                                    if (widget.dhikr.translation.isNotEmpty) ...[
                                      SizedBox(height: R.px(16)),
                                      Text(
                                        '"${widget.dhikr.translation}"',
                                        textAlign: TextAlign.center,
                                        style: AppText.manrope(
                                          fontSize: R.adaptive(13, 15, 17),
                                          height: 1.6,
                                          color: ThemeProvider.cream.withValues(alpha: 0.85),
                                        ),
                                      ),
                                    ],

                                    if (widget.dhikr.benefit?.isNotEmpty == true) ...[
                                      SizedBox(height: R.px(14)),
                                      Text(
                                        widget.dhikr.benefit!.toUpperCase(),
                                        textAlign: TextAlign.center,
                                        style: AppText.label(color: AppColors.ink(0.35)),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                    ),

                    if (!_showPlayer) ...[
                      // ── Centerpiece: Master Glowing Counter Ring ──────────────
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: R.px(14)),
                        child: Center(
                          child: SizedBox(
                            width: ringSize,
                            height: ringSize,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Background Glow Pulse
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 140),
                                  width: ringSize * 0.90,
                                  height: ringSize * 0.90,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: (_isGlowActive || isDone
                                            ? ThemeProvider.divineAmber
                                            : AppColors.primary)
                                        .withValues(
                                            alpha: _isGlowActive
                                                ? 0.45
                                                : (_pressed ? 0.25 : 0.08)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (_isGlowActive || isDone
                                                ? ThemeProvider.divineAmber
                                                : AppColors.primary)
                                            .withValues(
                                                alpha: _isGlowActive
                                                    ? 0.65
                                                    : (_pressed ? 0.38 : 0.16)),
                                        blurRadius: _isGlowActive
                                            ? 48
                                            : (_pressed ? 36 : 22),
                                        spreadRadius:
                                            _isGlowActive ? 8 : (_pressed ? 4 : 0),
                                      ),
                                    ],
                                  ),
                                ),

                                // Circular Progress Ring Arc
                                if (prog != null)
                                  SizedBox(
                                    width: ringSize,
                                    height: ringSize,
                                    child: CircularProgressIndicator(
                                      value: prog,
                                      strokeWidth: R.adaptive(5.0, 6.0, 7.5),
                                      backgroundColor: AppColors.ink(0.08),
                                      valueColor: AlwaysStoppedAnimation(
                                        (_isGlowActive || isDone)
                                            ? ThemeProvider.divineAmber
                                            : AppColors.primary,
                                      ),
                                      strokeCap: StrokeCap.round,
                                    ),
                                  ),

                                // Digits & Details inside Ring
                                AnimatedScale(
                                  scale: _pressed ? 0.94 : 1.0,
                                  duration: const Duration(milliseconds: 100),
                                  curve: Curves.easeOutCubic,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildFocusCountText(
                                        count: count,
                                        isDone: isDone,
                                        countSize: countSize,
                                      ),
                                      SizedBox(height: R.px(4)),
                                      Text(
                                        '/ $label',
                                        style: AppText.manrope(
                                          fontSize: R.adaptive(12.5, 14.0, 16.0),
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.ink(0.40),
                                        ),
                                      ),
                                      SizedBox(height: R.px(8)),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: R.px(10),
                                          vertical: R.px(3),
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDone
                                              ? ThemeProvider.divineAmber
                                                  .withValues(alpha: 0.16)
                                              : AppColors.primary
                                                  .withValues(alpha: 0.10),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isDone
                                                ? ThemeProvider.divineAmber
                                                    .withValues(alpha: 0.35)
                                                : AppColors.primary
                                                    .withValues(alpha: 0.20),
                                          ),
                                        ),
                                        child: Text(
                                          isDone
                                              ? '✓ ${lp.getText('completed').toUpperCase()}'
                                              : '$remaining ${lp.getText('remaining')}',
                                          style: TextStyle(
                                            fontSize: R.sp(R.adaptive(9.0, 10.5, 12.0)),
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.8,
                                            color: isDone
                                                ? ThemeProvider.divineAmber
                                                : AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // ── Bottom Guidance Hint ─────────────────────────────────
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                            R.px(20), R.px(4), R.px(20), R.px(20)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.touch_app_outlined,
                              size: R.sp(14),
                              color: AppColors.ink(0.35),
                            ),
                            SizedBox(width: R.px(6)),
                            Text(
                              lp.getText('tap_anywhere_to_count'),
                              style: AppText.label(color: AppColors.ink(0.35)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),

                // ── Mini Audio Player (Floating) ─────────────────────────────
                if (_showPlayer) _buildMiniPlayer(),
              ],
            ),
          ),
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
      behavior: HitTestBehavior.opaque,
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
      behavior: HitTestBehavior.opaque,
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
