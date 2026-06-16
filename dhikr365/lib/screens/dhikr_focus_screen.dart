import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/dhikr.dart';
import '../providers/dhikr_provider.dart';
import '../providers/language_provider.dart';
import '../providers/theme_provider.dart';
import '../services/audio_service.dart';
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
  bool _audioOn = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
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

  void _toggleAudio() {
    final path = widget.dhikr.audioPath;
    if (path == null || path.isEmpty) return;
    if (_audioOn) {
      AudioService().stop();
      setState(() => _audioOn = false);
    } else {
      AudioService().play(path);
      setState(() => _audioOn = true);
    }
  }

  @override
  void dispose() {
    if (_audioOn) AudioService().stop();
    WakelockPlus.disable();
    super.dispose();
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
                    _Btn(_audioOn ? Icons.stop : Icons.play_arrow,
                        color: AppColors.primary.withOpacity(0.2),
                        border: AppColors.primary.withOpacity(0.3),
                        iconColor: AppColors.primary,
                        onTap: _toggleAudio),
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
