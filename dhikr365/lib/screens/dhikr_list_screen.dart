import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:ui';
import '../providers/dhikr_provider.dart';
import '../providers/custom_plan_provider.dart';
import '../providers/language_provider.dart';
import '../models/dhikr.dart';
import '../providers/theme_provider.dart';
import '../widgets/dhikr_card.dart';
import '../utils/responsive.dart';
import '../services/audio_service.dart';
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

  // ── Audio state ──────────────────────────────────────────────────────────
  final AudioService _audio = AudioService();
  bool _audioPlaying = false;
  bool _audioAvailable = true; // false after first failed play
  Duration _audioPosition = Duration.zero;
  Duration _audioDuration = Duration.zero;

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

    // Subscribe to audio streams
    _audio.stateStream.listen((s) {
      if (!mounted) return;
      setState(() => _audioPlaying = s == PlayerState.playing);
    });
    _audio.positionStream.listen((p) {
      if (!mounted) return;
      setState(() => _audioPosition = p);
    });
    _audio.durationStream.listen((d) {
      if (!mounted) return;
      setState(() => _audioDuration = d ?? Duration.zero);
    });
  }

  @override
  void dispose() {
    _dhikrProvider?.removeListener(_onProviderChanged);
    _audio.stop();
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

  // ── Audio player bar ─────────────────────────────────────────────────────

  Future<void> _toggleAudio() async {
    if (_audioPlaying) {
      await _audio.pause();
    } else if (_audio.isPaused &&
        _audio.currentCategory == widget.category) {
      await _audio.resume();
    } else {
      final ok = await _audio.playCategory(widget.category);
      if (!ok && mounted) {
        setState(() => _audioAvailable = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No audio file found.\nAdd ${AudioService.assetPath(widget.category)} to assets/audio/',
            ),
            backgroundColor: Colors.red.shade800,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Widget _buildAudioBar() {
    final progress = _audioDuration.inMilliseconds > 0
        ? (_audioPosition.inMilliseconds / _audioDuration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    String fmt(Duration d) {
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$m:$s';
    }

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF042F2E).withOpacity(0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: const Color(0xFFF59E0B).withOpacity(0.3), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.music_note_rounded,
                      color: Color(0xFFF59E0B), size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Audio Recitation',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  // Play / Pause
                  GestureDetector(
                    onTap: _toggleAudio,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF59E0B).withOpacity(0.4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Icon(
                        _audioPlaying ? Icons.pause : Icons.play_arrow_rounded,
                        color: Colors.black,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Stop
                  GestureDetector(
                    onTap: () => _audio.stop(),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.stop_rounded,
                          color: Colors.white54, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Seek bar
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 5),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 12),
                  activeTrackColor: const Color(0xFFF59E0B),
                  inactiveTrackColor: Colors.white12,
                  thumbColor: const Color(0xFFF59E0B),
                  overlayColor: const Color(0xFFF59E0B).withOpacity(0.2),
                ),
                child: Slider(
                  value: progress,
                  onChanged: (v) {
                    final ms = (_audioDuration.inMilliseconds * v).toInt();
                    _audio.seek(Duration(milliseconds: ms));
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(fmt(_audioPosition),
                      style: const TextStyle(
                          fontSize: 11, color: Colors.white38)),
                  Text(fmt(_audioDuration),
                      style: const TextStyle(
                          fontSize: 11, color: Colors.white38)),
                ],
              ),
            ],
          ),
        ).animate().slideY(begin: 1.0, end: 0.0, duration: 300.ms,
            curve: Curves.easeOutCubic),
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
                        padding: EdgeInsets.only(bottom: R.px(170), top: R.px(16)),
                        itemCount: displayList.length,
                        itemBuilder: (context, index) {
                          return DhikrCard(dhikr: displayList[index])
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

          // ── Audio player bar ──────────────────────────────────────────────
          if (_audioAvailable) _buildAudioBar(),

          // ── Celebration overlay (shown once when category completes) ───────
          if (_showCelebration) _buildCelebrationBanner(streak),
        ],
      ),
    );
  }
}
