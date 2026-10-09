// ============================================================================
// lib/widgets/time_synced_dhikr_view.dart
//
// TIME-SYNCED DUA RECITATION VIEW
//
// Real-time Karaoke-style interactive recitation engine:
//   • Actively highlights the recited Arabic phrase in Divine Amber gold
//   • Auto-scrolls smoothly to keep the active sentence centered
//   • Supports interactive tap-to-seek to jump to any phrase instantly
//   • Gracefully pauses auto-scroll when user manually drags the view
//   • Bubble-up background taps to continue full-screen tasbih counting
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_theme.dart';
import '../models/dua_timestamp.dart';
import '../providers/theme_provider.dart';
import '../services/audio_service.dart';
import '../utils/responsive.dart';

class TimeSyncedDhikrView extends StatefulWidget {
  final List<DuaSegment> segments;
  final bool showTransliteration;
  final VoidCallback? onBackgroundTap;

  const TimeSyncedDhikrView({
    super.key,
    required this.segments,
    this.showTransliteration = true,
    this.onBackgroundTap,
  });

  @override
  State<TimeSyncedDhikrView> createState() => _TimeSyncedDhikrViewState();
}

class _TimeSyncedDhikrViewState extends State<TimeSyncedDhikrView> {
  final AudioService _audio = AudioService();
  final ScrollController _scrollController = ScrollController();
  List<GlobalKey> _segmentKeys = [];

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  late List<DuaSegment> _effectiveSegments;
  int _activeIdx = -1;
  int _currentMs = 0;
  int _lastScrolledIdx = -1;
  bool _userInteracting = false;
  Timer? _resumeAutoScrollTimer;

  static bool _areSegmentsEqual(List<DuaSegment> a, List<DuaSegment> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].startMs != b[i].startMs ||
          a[i].endMs != b[i].endMs ||
          a[i].arabic != b[i].arabic) {
        return false;
      }
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _effectiveSegments = List.from(widget.segments);
    _segmentKeys = List.generate(_effectiveSegments.length, (_) => GlobalKey());
    _listenPosition();
  }

  @override
  void didUpdateWidget(covariant TimeSyncedDhikrView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_areSegmentsEqual(oldWidget.segments, widget.segments)) {
      _effectiveSegments = List.from(widget.segments);
      _segmentKeys =
          List.generate(_effectiveSegments.length, (_) => GlobalKey());
      _activeIdx = -1;
      _lastScrolledIdx = -1;
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _resumeAutoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _listenPosition() {
    _posSub = _audio.positionStream.listen((pos) {
      if (!mounted) return;
      final ms = pos.inMilliseconds;
      int match = -1;
      for (int i = 0; i < _effectiveSegments.length; i++) {
        if (_effectiveSegments[i].isActive(ms)) {
          match = i;
          break;
        }
      }

      // If in a microscopic gap between segments during active playback,
      // maintain the previous active segment to prevent flicker
      if (match == -1 && _activeIdx != -1 && _audio.isPlaying) {
        if (_activeIdx < _effectiveSegments.length - 1) {
          final nextSeg = _effectiveSegments[_activeIdx + 1];
          if (ms < nextSeg.startMs) {
            match = _activeIdx;
          }
        }
      }

      if (_currentMs != ms || match != _activeIdx) {
        setState(() {
          _currentMs = ms;
          _activeIdx = match;
        });
        if (match != -1 && match != _lastScrolledIdx && !_userInteracting) {
          _lastScrolledIdx = match;
          _scrollToIndex(match);
        }
      }
    });

    _durSub = _audio.durationStream.listen((dur) {
      if (!mounted || dur == null || dur.inMilliseconds <= 0) return;
      _rescaleSegmentsIfNeeded(dur.inMilliseconds);
    });
  }

  void _rescaleSegmentsIfNeeded(int actualTotalMs) {
    if (_effectiveSegments.isEmpty || actualTotalMs <= 0) return;
    final nominalEnd = _effectiveSegments.last.endMs;
    if ((nominalEnd - actualTotalMs).abs() < 1200) return;

    final ratio = actualTotalMs / nominalEnd;
    final rescaled = _effectiveSegments.map((s) {
      return DuaSegment(
        startMs: (s.startMs * ratio).round(),
        endMs: (s.endMs * ratio).round(),
        arabic: s.arabic,
        translation: s.translation,
        transliteration: s.transliteration,
      );
    }).toList();

    setState(() => _effectiveSegments = rescaled);
  }

  void _scrollToIndex(int idx) {
    if (idx < 0 || idx >= _segmentKeys.length) return;
    final ctx = _segmentKeys[idx].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.18, // Positions active segment comfortably above center
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onUserScrollStart() {
    _userInteracting = true;
    _resumeAutoScrollTimer?.cancel();
  }

  void _onUserScrollEnd() {
    _resumeAutoScrollTimer?.cancel();
    // Resume auto-scrolling 2.5 seconds after user stops manually scrolling
    _resumeAutoScrollTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() => _userInteracting = false);
        if (_activeIdx != -1) _scrollToIndex(_activeIdx);
      }
    });
  }

  void _seekToSegment(int idx) {
    if (idx < 0 || idx >= _effectiveSegments.length) return;
    HapticFeedback.selectionClick();
    final seg = _effectiveSegments[idx];
    _audio.seekMs(seg.startMs);
    setState(() {
      _currentMs = seg.startMs;
      _activeIdx = idx;
    });
    _scrollToIndex(idx);
  }

  Widget _buildArabicText({
    required DuaSegment seg,
    required int index,
    required bool isActive,
    required bool isPast,
    required double fontSize,
  }) {
    final arabicText = seg.arabic.trim();

    final textColor = isActive
        ? ThemeProvider.divineAmber
        : (isPast
            ? ThemeProvider.cream.withValues(alpha: 0.90)
            : AppColors.ink(0.40));

    final fontWeight = isActive
        ? FontWeight.w800
        : (isPast ? FontWeight.w600 : FontWeight.normal);

    final shadows = isActive
        ? [
            Shadow(
              color: ThemeProvider.divineAmber.withValues(alpha: 0.70),
              blurRadius: 12,
            ),
            Shadow(
              color: ThemeProvider.divineAmber.withValues(alpha: 0.35),
              blurRadius: 22,
            ),
          ]
        : null;

    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      textAlign: TextAlign.right,
      style: AppText.amiri(
        fontSize: fontSize,
        color: textColor,
      ).copyWith(
        fontWeight: fontWeight,
        height: 1.6,
        shadows: shadows,
      ),
      child: Text(
        arabicText,
        textDirection: TextDirection.rtl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final arabicSize = R.adaptive(23.0, 27.0, 32.0);
    final transSize = R.adaptive(12.5, 14.0, 16.0);

    return NotificationListener<ScrollNotification>(
      onNotification: (notif) {
        if (notif is ScrollStartNotification) {
          _onUserScrollStart();
        } else if (notif is ScrollEndNotification) {
          _onUserScrollEnd();
        }
        return false;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.onBackgroundTap,
        child: ListView.separated(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            R.px(20),
            R.px(12),
            R.px(20),
            R.px(240), // Extra bottom padding so last segment scrolls comfortably above mini player
          ),
          itemCount: _effectiveSegments.length,
          separatorBuilder: (_, __) => SizedBox(height: R.px(10)),
          itemBuilder: (context, i) {
            final seg = _effectiveSegments[i];
            final isActive = i == _activeIdx;
            final isPast = _activeIdx != -1 && i < _activeIdx;

            return GestureDetector(
              key: _segmentKeys[i],
              behavior: HitTestBehavior.opaque,
              onTap: () => _seekToSegment(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  horizontal: R.px(16),
                  vertical: R.px(12),
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? ThemeProvider.divineAmber.withValues(alpha: 0.14)
                      : (isPast
                          ? AppColors.ink(0.02)
                          : Colors.transparent),
                  borderRadius: BorderRadius.circular(R.px(16)),
                  border: Border.all(
                    color: isActive
                        ? ThemeProvider.divineAmber.withValues(alpha: 0.45)
                        : (isPast
                            ? AppColors.ink(0.05)
                            : Colors.transparent),
                    width: isActive ? 1.4 : 1.0,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: ThemeProvider.divineAmber
                                .withValues(alpha: 0.20),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Indicator / Sequence Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left: Active Speaker or Sequence Tag
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: isActive ? 1.0 : (isPast ? 0.35 : 0.25),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isActive
                                    ? Icons.volume_up_rounded
                                    : Icons.play_arrow_rounded,
                                size: R.sp(13),
                                color: isActive
                                    ? ThemeProvider.divineAmber
                                    : AppColors.ink(0.6),
                              ),
                              SizedBox(width: R.px(4)),
                              Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: R.sp(10),
                                  fontWeight: FontWeight.w800,
                                  color: isActive
                                      ? ThemeProvider.divineAmber
                                      : AppColors.ink(0.5),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Right: Interactive 'Tap to play from here' cue
                        if (isActive)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: R.px(8),
                              vertical: R.px(2),
                            ),
                            decoration: BoxDecoration(
                              color: ThemeProvider.divineAmber
                                  .withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'PLAYING',
                                  style: TextStyle(
                                    fontSize: R.sp(8.5),
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                    color: ThemeProvider.divineAmber,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                    SizedBox(height: R.px(6)),

                    // Arabic Text (RTL) with real-time sentence-by-sentence golden highlighting
                    _buildArabicText(
                      seg: seg,
                      index: i,
                      isActive: isActive,
                      isPast: isPast,
                      fontSize: arabicSize,
                    ),

                    // Transliteration (if enabled)
                    if (widget.showTransliteration &&
                        seg.transliteration?.isNotEmpty == true) ...[
                      SizedBox(height: R.px(8)),
                      Text(
                        seg.transliteration!,
                        textAlign: TextAlign.left,
                        style: AppText.transliteration(
                          fontSize: R.sp(R.adaptive(12.0, 13.5, 15.0)),
                          color: isActive
                              ? AppColors.textPrimary
                              : (isPast
                                  ? AppColors.textSlate400
                                  : AppColors.ink(0.35)),
                        ),
                      ),
                    ],

                    // Translation (if available)
                    if (seg.translation?.isNotEmpty == true) ...[
                      SizedBox(height: R.px(6)),
                      Text(
                        seg.translation!,
                        textAlign: TextAlign.left,
                        style: AppText.manrope(
                          fontSize: transSize,
                          height: 1.5,
                          color: isActive
                              ? ThemeProvider.cream
                              : (isPast
                                  ? ThemeProvider.cream.withValues(alpha: 0.70)
                                  : AppColors.ink(0.30)),
                        ).copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
