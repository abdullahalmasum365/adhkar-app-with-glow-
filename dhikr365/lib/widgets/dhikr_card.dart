import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/dhikr.dart';
import '../providers/dhikr_provider.dart';
import '../providers/language_provider.dart';
import '../providers/theme_provider.dart';
import '../constants/app_theme.dart';
import '../utils/responsive.dart';
import '../screens/dhikr_focus_screen.dart';
import 'social_share_card.dart';

class DhikrCard extends StatefulWidget {
  final Dhikr dhikr;

  /// Called when the user taps the play button on this card.
  final void Function(Dhikr)? onPlayTapped;

  /// True when this card's audio is loaded in the mini player.
  final bool isActive;

  /// True when this card's audio is actively playing (subset of isActive).
  final bool isPlaying;

  /// Whether to display a category pill above the title.
  final bool showCategoryBadge;

  const DhikrCard({
    super.key,
    required this.dhikr,
    this.onPlayTapped,
    this.isActive = false,
    this.isPlaying = false,
    this.showCategoryBadge = false,
  });

  @override
  State<DhikrCard> createState() => _DhikrCardState();
}

class _DhikrCardState extends State<DhikrCard> {
  int _scaleAnimKey = 0;
  bool _isGlowActive = false;

  /// Builds the plain-text blob that gets sent to the OS share sheet.
  String _buildShareText(LanguageProvider lp, bool showTranslit) {
    final d = widget.dhikr;
    final buf = StringBuffer();
    buf.writeln(d.title);
    buf.writeln();
    buf.writeln(d.arabicText);
    if (showTranslit && d.transliteration?.isNotEmpty == true) {
      buf.writeln();
      buf.writeln(d.transliteration);
    }
    if (d.translation.isNotEmpty) {
      buf.writeln();
      buf.writeln('"${d.translation}"');
    }
    if (d.reference?.isNotEmpty == true) {
      buf.writeln();
      buf.writeln('— ${d.reference}');
    }
    buf.writeln();
    buf.write(lp.getText('share_footer'));
    return buf.toString();
  }

  void _showShareSheet(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final showTranslit =
        Provider.of<ThemeProvider>(context, listen: false).showTransliteration;
    final shareText = _buildShareText(lp, showTranslit);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: AppColors.playerSurface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.ink(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Handle ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.ink(0.24),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // ── Title row ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.share_rounded,
                        color: AppColors.accent, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      lp.getText('share_dhikr'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.ink(0.10)),
            // ── Preview ──────────────────────────────────────────────
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.ink(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.ink(0.08)),
              ),
              child: Text(
                shareText,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.ink(0.70),
                  height: 1.6,
                ),
                maxLines: 10,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // ── Action buttons ────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 16, 16, MediaQuery.of(context).padding.bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // Copy
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: shareText));
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              lp.getText('copied'),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            backgroundColor: AppColors.playerSurface,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(milliseconds: 1600),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.ink(0.07),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.ink(0.1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.copy_rounded,
                                color: AppColors.ink(0.70), size: 18),
                            const SizedBox(width: 8),
                            Text(lp.getText('copy'),
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink(0.70))),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Share
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        Share.share(shareText);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary, AppColors.accent],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.share_rounded,
                                color: AppColors.textPrimary, size: 18),
                            const SizedBox(width: 8),
                            Text(lp.getText('share_dhikr'),
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Share as Image Card Option
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  SocialShareCard.shareDhikrAsImage(
                    context: context,
                    dhikr: widget.dhikr,
                    showTransliteration: showTranslit,
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_rounded,
                          color: AppColors.primary, size: 19),
                      const SizedBox(width: 8),
                      Text(
                        lp.getText('share_as_image'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
          ],
        ),
      ),
    );
  }

  void _onPlayTapped() => widget.onPlayTapped?.call(widget.dhikr);

  Widget _buildRemainingText({
    required int remaining,
    required bool isDone,
    required double counterNum,
  }) {
    Widget text = Text(
      '$remaining',
      style: TextStyle(
        fontSize: counterNum,
        fontWeight: FontWeight.w900,
        height: 1.0,
        color: (_isGlowActive || isDone)
            ? ThemeProvider.divineAmber
            : AppColors.textPrimary,
      ),
    );

    if (_scaleAnimKey > 0) {
      text = text
          .animate(key: ValueKey('card_milestone_$_scaleAnimKey'))
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

  @override
  Widget build(BuildContext context) {
    R.init(context);

    final lp = Provider.of<LanguageProvider>(context);
    final dhikrProvider = Provider.of<DhikrProvider>(context, listen: false);
    final showTranslit =
        Provider.of<ThemeProvider>(context).showTransliteration;
    final remaining =
        (widget.dhikr.targetCount - widget.dhikr.currentCount).clamp(0, 9999);
    final isDone = widget.dhikr.isCompleted;

    final cardPad = R.px(18);
    final arabicSize = R.adaptive(22.0, 26.0, 30.0);
    final transSize = R.adaptive(13.0, 15.0, 17.0);
    final btnSize = R.adaptive(32.0, 36.0, 42.0);
    final counterNum = R.adaptive(38.0, 44.0, 52.0);
    final countBtnV = R.adaptive(16.0, 20.0, 26.0);

    final isBookmarked = context.select<DhikrProvider, bool>(
      (dp) => dp.isBookmarked(widget.dhikr.id),
    );

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _showShareSheet(context);
      },
      child: Container(
        margin: EdgeInsets.symmetric(vertical: R.px(10), horizontal: R.px(14)),
        decoration: BoxDecoration(
          color: AppColors.ink(0.03),
          borderRadius: BorderRadius.circular(R.px(20)),
          border: Border.all(color: AppColors.ink(0.08)),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(cardPad),
          child: Column(
            children: [
              // ── Optional Category Badge ─────────────────────────────────────
              if (widget.showCategoryBadge) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.only(bottom: R.px(10)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.dhikr.category.color
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: widget.dhikr.category.color
                            .withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(widget.dhikr.category.icon,
                            size: 13, color: widget.dhikr.category.color),
                        const SizedBox(width: 6),
                        Text(
                          lp.getText(widget.dhikr.category.titleKey),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: widget.dhikr.category.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // ── Header ──────────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.dhikr.title.toUpperCase(),
                          style: TextStyle(
                            // Plain TextStyle — system font handles Arabic, Bengali,
                            // Hindi, etc. when the dhikr title is in a non-Latin script.
                            fontWeight: FontWeight.w900,
                            fontSize: R.sp(11),
                            letterSpacing: 1.6,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                        if (widget.dhikr.hasTimestamps) ...[
                          SizedBox(height: R.px(2)),
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
                                'SYNCED',
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
                  // Audio is shown for every dhikr that has an audio recording available.
                  // If no audio is available for a dhikr, the button is omitted.
                  if (widget.dhikr.hasAudio) ...[
                    SizedBox(width: R.px(8)),
                    GestureDetector(
                      onTap: _onPlayTapped,
                      child: Container(
                        height: btnSize,
                        width: btnSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.isActive
                              ? ThemeProvider.divineAmber
                              : ThemeProvider.divineAmber
                                  .withValues(alpha: 0.72),
                          boxShadow: [
                            BoxShadow(
                              color: ThemeProvider.divineAmber.withValues(
                                  alpha: widget.isActive ? 0.55 : 0.22),
                              blurRadius: widget.isActive ? 16 : 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          widget.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: AppColors.textPrimary,
                          size: R.sp(18),
                        ),
                      ),
                    ),
                  ],
                  SizedBox(width: R.px(8)),
                  // Bookmark button
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      dhikrProvider.toggleBookmark(widget.dhikr.id);
                    },
                    child: Container(
                      height: btnSize,
                      width: btnSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isBookmarked
                            ? AppColors.primary.withValues(alpha: 0.16)
                            : AppColors.ink(0.06),
                        border: Border.all(
                          color: isBookmarked
                              ? AppColors.primary.withValues(alpha: 0.40)
                              : AppColors.ink(0.10),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        isBookmarked
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        color: isBookmarked
                            ? AppColors.primary
                            : AppColors.textSlate400,
                        size: R.sp(18),
                      )
                          .animate(key: ValueKey(isBookmarked))
                          .scale(
                            duration: 250.ms,
                            curve: Curves.easeOutBack,
                            begin: const Offset(0.7, 0.7),
                            end: const Offset(1.0, 1.0),
                          ),
                    ),
                  ),
                  SizedBox(width: R.px(8)),
                  // Share button
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _showShareSheet(context);
                    },
                    child: Container(
                      height: btnSize,
                      width: btnSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.ink(0.06),
                        border: Border.all(
                          color: AppColors.ink(0.10),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.share_rounded,
                        color: AppColors.textSlate400,
                        size: R.sp(16),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: R.px(14)),
              Divider(color: AppColors.ink(0.05)),
              SizedBox(height: R.px(14)),

              // ── Arabic Text ──────────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.only(bottom: R.px(14)),
                child: Text(
                  widget.dhikr.arabicText,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.amiri(
                    fontSize: arabicSize,
                    height: 1.6,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),

              // ── Transliteration (hidden when user turns off global toggle) ───
              if (showTranslit &&
                  widget.dhikr.transliteration?.isNotEmpty == true)
                Padding(
                  padding: EdgeInsets.only(bottom: R.px(14)),
                  child: Text(
                    widget.dhikr.transliteration!,
                    textAlign: TextAlign.center,
                    style: AppText.transliteration(
                      fontSize: R.sp(12),
                      color: AppColors.ink(0.60),
                    ),
                  ),
                ),

              // ── Translation ──────────────────────────────────────────────────
              if (widget.dhikr.translation.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: R.px(20)),
                  child: Text(
                    '"${widget.dhikr.translation}"',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      // System font — translations can be in any of the 19
                      // supported languages; no fontFamily constraint needed.
                      fontSize: transSize,
                      fontStyle: FontStyle.italic,
                      color: ThemeProvider.cream,
                      height: 1.6,
                    ),
                  ),
                ),

              // ── Reference ───────────────────────────────────────────────────
              if (widget.dhikr.reference != null)
                Padding(
                  padding: EdgeInsets.only(bottom: R.px(20)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_stories,
                          size: R.sp(13), color: AppColors.ink(0.54)),
                      SizedBox(width: R.px(6)),
                      Flexible(
                        child: Text(
                          '${lp.getText('source').toUpperCase()}: ${widget.dhikr.reference!.toUpperCase()}',
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                          style: TextStyle(
                            fontSize: R.sp(9),
                            color: AppColors.ink(0.54),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Benefit ─────────────────────────────────────────────────────
              if (widget.dhikr.benefit != null)
                Container(
                  margin: EdgeInsets.only(bottom: R.px(20)),
                  padding: EdgeInsets.symmetric(
                      vertical: R.px(14), horizontal: R.px(16)),
                  decoration: BoxDecoration(
                    color: AppColors.ink(0.03),
                    borderRadius: BorderRadius.circular(R.px(14)),
                    border: Border.all(color: AppColors.ink(0.08)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.stars,
                              size: R.sp(14), color: AppColors.textPrimary),
                          SizedBox(width: R.px(6)),
                          Text(
                            lp.getText('benefit').toUpperCase(),
                            style: TextStyle(
                              fontSize: R.sp(9),
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.8,
                              color: AppColors.ink(0.54),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: R.px(8)),
                      Text(
                        widget.dhikr.benefit!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          // System font — benefit text can be in any language.
                          fontSize: R.sp(12),
                          height: 1.4,
                          color: AppColors.ink(0.8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (widget.dhikr.category == DhikrCategory.shifa ||
                          widget.dhikr.category == DhikrCategory.distress) ...[
                        SizedBox(height: R.px(10)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.health_and_safety_outlined,
                                size: R.sp(12),
                                color: Colors.amber.shade400.withValues(alpha: 0.9)),
                            SizedBox(width: R.px(6)),
                            Flexible(
                              child: Text(
                                lp.getText('health_disclaimer_short'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: R.sp(9.5),
                                  height: 1.25,
                                  color: AppColors.ink(0.55),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

              // ── Counter Button ───────────────────────────────────────────────
              Semantics(
                button: true,
                enabled: !isDone,
                label: isDone
                    ? '${lp.getText('completed')} ${widget.dhikr.targetCount}'
                    : '${lp.getText('tap_to_count')}, $remaining ${lp.getText('remaining')}',
                child: GestureDetector(
                  onTap: isDone
                      ? null
                      : () async {
                          final milestone = await dhikrProvider
                              .incrementDhikr(widget.dhikr.id);
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
                              Future.delayed(
                                  const Duration(milliseconds: 600), () {
                                if (mounted) {
                                  setState(() => _isGlowActive = false);
                                }
                              });
                            }
                          }
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: countBtnV),
                    decoration: BoxDecoration(
                      gradient: (_isGlowActive || isDone)
                          ? null
                          : LinearGradient(
                              colors: [AppColors.primary, AppColors.accent],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                      color: _isGlowActive
                          ? ThemeProvider.divineAmber
                          : (isDone ? AppColors.ink(0.05) : null),
                      borderRadius: BorderRadius.circular(R.px(18)),
                      border: (_isGlowActive || isDone)
                          ? Border.all(
                              color: _isGlowActive
                                  ? ThemeProvider.divineAmber
                                  : AppColors.ink(0.1),
                            )
                          : null,
                      boxShadow: _isGlowActive
                          ? [
                              BoxShadow(
                                color: ThemeProvider.divineAmber
                                    .withValues(alpha: 0.65),
                                blurRadius: 36,
                                spreadRadius: 4,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : (isDone
                              ? []
                              : [
                                  BoxShadow(
                                    color: AppColors.accent
                                        .withValues(alpha: 0.3),
                                    blurRadius: 30,
                                    offset: const Offset(0, 8),
                                  ),
                                ]),
                    ),
                    child: Column(
                      children: [
                        Text(
                          isDone
                              ? '${lp.getText('completed').toUpperCase()} ✓'
                              : lp.getText('tap_to_count').toUpperCase(),
                          style: TextStyle(
                            fontSize: R.sp(10),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.8,
                            color: _isGlowActive
                                ? AppColors.textPrimary
                                : (isDone
                                    ? AppColors.ink(0.54)
                                    : AppColors.ink(0.7)),
                          ),
                        ),
                        SizedBox(height: R.px(6)),
                        // Flexible row prevents overflow if count digits are wide
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: _buildRemainingText(
                                  remaining: remaining,
                                  isDone: isDone,
                                  counterNum: counterNum,
                                ),
                              ),
                            ),
                            SizedBox(width: R.px(4)),
                            Text(
                              '/ ${widget.dhikr.targetCount}',
                              style: TextStyle(
                                fontSize: R.sp(13),
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary
                                    .withValues(alpha: isDone ? 0.3 : 0.5),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            SizedBox(height: R.px(20)),

              // ── Focus Mode ───────────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.ink(0.05)),
                  ),
                ),
                padding: EdgeInsets.only(top: R.px(14)),
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => DhikrFocusScreen(dhikr: widget.dhikr)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.filter_center_focus,
                          color: AppColors.ink(0.54), size: R.sp(17)),
                      SizedBox(width: R.px(8)),
                      Text(
                        lp.getText('focus_mode').toUpperCase(),
                        style: TextStyle(
                          color: AppColors.ink(0.54),
                          fontSize: R.sp(10),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ), // closes child: Container
    ); // closes GestureDetector
  }
}
