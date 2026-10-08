import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:provider/provider.dart';

import '../constants/app_theme.dart';
import '../providers/language_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/user_provider.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../utils/first_launch_navigation.dart';
import '../utils/responsive.dart';
import 'location_setup_screen.dart';

/// 5-Step Personalized Interactive Onboarding Quiz for Adhkar 365.
/// 
/// Step 1: Language Selection (6 most popular languages, pre-selects device locale)
/// Step 2: "What is your main goal?" (protection, habit, peace, sunnah)
/// Step 3: "When is your best time for Dhikr?" (fajr, asr, sleep, anytime)
/// Step 4: Location & Prayer Times Setup (GPS detection with animated mosque)
/// Step 5: Welcome & Personalized Summary + "Begin My Journey →"
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _totalPages = 5;

  bool _isLoading = false;
  bool _isLocating = false;
  bool _gpsSucceeded = false;
  String? _detectedCity;
  String? _detectedCountry;

  String _selectedGoal = 'protection';
  String _selectedTime = 'fajr';
  String? _selectedLang;

  // 6 Most popular languages for Step 1
  static const List<Map<String, String>> _popularLanguages = [
    {'code': 'en', 'name': 'English', 'native': 'English', 'flag': '🇬🇧'},
    {'code': 'ar', 'name': 'Arabic', 'native': 'العربية', 'flag': '🇸🇦'},
    {'code': 'bn', 'name': 'Bengali', 'native': 'বাংলা', 'flag': '🇧🇩'},
    {'code': 'ur', 'name': 'Urdu', 'native': 'اردو', 'flag': '🇵🇰'},
    {'code': 'id', 'name': 'Indonesian', 'native': 'Bahasa Indonesia', 'flag': '🇮🇩'},
    {'code': 'tr', 'name': 'Turkish', 'native': 'Türkçe', 'flag': '🇹🇷'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final up = Provider.of<UserProvider>(context, listen: false);
      final lp = Provider.of<LanguageProvider>(context, listen: false);
      if (up.onboardingGoal != null && up.onboardingGoal!.isNotEmpty) {
        _selectedGoal = up.onboardingGoal!;
      }
      if (up.preferredDhikrTime != null && up.preferredDhikrTime!.isNotEmpty) {
        _selectedTime = up.preferredDhikrTime!;
      }
      _selectedLang = lp.locale.languageCode;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    if (page < 0 || page >= _totalPages) return;
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  void _onNext() {
    if (_currentPage < _totalPages - 1) {
      _goToPage(_currentPage + 1);
    } else {
      _finishOnboarding();
    }
  }

  void _onBack() {
    if (_currentPage > 0) {
      _goToPage(_currentPage - 1);
    }
  }

  void _onSkipToLocation() {
    // Skip button jumps directly to Step 4 (index 3)
    if (_pageController.hasClients) {
      _pageController.jumpToPage(3);
    }
  }

  // ── Step 4: GPS Location Setup ─────────────────────────────────────────────
  Future<void> _requestLocation() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);

    final up = Provider.of<UserProvider>(context, listen: false);
    final np = Provider.of<NotificationProvider>(context, listen: false);

    try {
      final gpsResult = await LocationService().tryGps();
      if (!mounted) return;

      if (gpsResult.succeeded) {
        final lat = gpsResult.coords!.lat;
        final lng = gpsResult.coords!.lng;

        final place = await LocationService().reverseGeocode(lat, lng);
        if (!mounted) return;

        await up.setCoordinates(lat, lng);
        await up.setLocation(place.city, place.country);

        try {
          await up.setTimezone(await FlutterTimezone.getLocalTimezone());
        } catch (_) {}
        if (!mounted) return;

        await NotificationService().requestPermissions();
        try {
          await np.refreshAllSchedules(up);
        } catch (_) {}
        if (!mounted) return;

        setState(() {
          _gpsSucceeded = true;
          _detectedCity = place.city;
          _detectedCountry = place.country;
          _isLocating = false;
        });

        // Auto-advance to summary after brief feedback
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted && _currentPage == 3) {
          _goToPage(4);
        }
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLocating = false);
    }
  }

  // ── Step 5: Finish Onboarding ─────────────────────────────────────────────
  Future<void> _finishOnboarding() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final up = Provider.of<UserProvider>(context, listen: false);
    final np = Provider.of<NotificationProvider>(context, listen: false);
    final nav = Navigator.of(context);

    // Save quiz answers permanently
    await up.setOnboardingGoal(_selectedGoal);
    await up.setPreferredDhikrTime(_selectedTime);
    await up.completeOnboarding().catchError((_) {});

    // If GPS wasn't run or completed yet, attempt a silent GPS fallback
    if (!_gpsSucceeded && !up.hasSavedCoordinates) {
      try {
        final gpsResult = await LocationService().tryGps();
        if (gpsResult.succeeded && mounted) {
          _gpsSucceeded = true;
          final lat = gpsResult.coords!.lat;
          final lng = gpsResult.coords!.lng;
          final place = await LocationService().reverseGeocode(lat, lng);
          if (mounted) {
            await up.setCoordinates(lat, lng);
            await up.setLocation(place.city, place.country);
            try {
              await up.setTimezone(await FlutterTimezone.getLocalTimezone());
            } catch (_) {}
            await NotificationService().requestPermissions();
            try {
              await np.refreshAllSchedules(up);
            } catch (_) {}
          }
        }
      } catch (_) {}
    }

    if (!mounted) return;

    if (_gpsSucceeded || up.hasSavedCoordinates) {
      await enterAppForFirstTime(context);
    } else {
      nav.pushReplacement(
        MaterialPageRoute(builder: (_) => const LocationSetupScreen()),
      );
    }
  }

  // ── Top Header with 5-dot Amber Glow Progress Indicator ───────────────────
  Widget _buildTopBar(LanguageProvider lp) {
    const amberColor = Color(0xFFF59E0B);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left back button or spacer
          if (_currentPage > 0)
            InkWell(
              onTap: _onBack,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.ink(0.08),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Icon(Icons.arrow_back_rounded,
                    color: AppColors.textPrimary, size: 18),
              ),
            )
          else
            const SizedBox(width: 38),

          // 5 Elegant Dots with Active Amber Glow
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(_totalPages, (i) {
              final isActive = i == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 26 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: isActive ? amberColor : AppColors.ink(0.2),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: amberColor.withValues(alpha: 0.5),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              );
            }),
          ),

          // Right Skip Button (active on Steps 1–3, jumps to Step 4)
          if (_currentPage < 3)
            GestureDetector(
              onTap: _onSkipToLocation,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.ink(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.ink(0.1)),
                ),
                child: Text(
                  lp.getText('skip'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSlate400,
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: 38),
        ],
      ),
    );
  }

  // ── Primary Action Button ─────────────────────────────────────────────────
  Widget _primaryBtn({
    required String text,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    const amberStart = Color(0xFFF59E0B);
    const amberEnd = Color(0xFFD97706);

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: (_isLoading || isLoading) ? null : onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [amberStart, amberEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(100),
            boxShadow: [
              BoxShadow(
                color: amberStart.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: isLoading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: AppColors.onPrimary,
                          strokeWidth: 2.5,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Setting up…',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        text,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          color: AppColors.onPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded,
                          color: AppColors.onPrimary, size: 18),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 1 — Language Selection
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStep1(LanguageProvider lp) {
    final currentCode = _selectedLang ?? lp.locale.languageCode;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 12),
          Text(
            'بِسْمِ اللَّهِ',
            style: AppText.amiri(
              fontSize: 26,
              color: const Color(0xFFF59E0B),
            ),
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 8),
          Text(
            lp.getText('onb_step_lang'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ).animate().fadeIn(delay: 150.ms).moveY(begin: 10, end: 0),
          const SizedBox(height: 8),
          Text(
            lp.getText('select_language_desc'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSlate400,
              height: 1.4,
            ),
          ).animate().fadeIn(delay: 250.ms),
          const SizedBox(height: 28),

          // 2-column Grid of Top 6 Languages
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.35,
            ),
            itemCount: _popularLanguages.length,
            itemBuilder: (context, index) {
              final item = _popularLanguages[index];
              final isSelected = item['code'] == currentCode;
              const amberColor = Color(0xFFF59E0B);

              return GestureDetector(
                onTap: () async {
                  final code = item['code']!;
                  setState(() => _selectedLang = code);
                  await lp.setLanguage(code);
                  // Smooth auto-advance
                  await Future.delayed(const Duration(milliseconds: 320));
                  if (mounted && _currentPage == 0) {
                    _goToPage(1);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? amberColor.withValues(alpha: 0.12)
                        : AppColors.bgCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? amberColor : AppColors.glassBorder,
                      width: isSelected ? 2.0 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: amberColor.withValues(alpha: 0.25),
                              blurRadius: 12,
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(item['flag'] ?? '',
                              style: const TextStyle(fontSize: 24)),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded,
                                color: amberColor, size: 18)
                          else
                            const SizedBox(width: 18),
                        ],
                      ),
                      const Spacer(),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          item['native'] ?? '',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? amberColor : AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          item['name'] ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSlate400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.1),

          const SizedBox(height: 32),
          _primaryBtn(
            text: lp.getText('continue'),
            onTap: _onNext,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 2 — "What is your main goal?"
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStep2(LanguageProvider lp) {
    final up = Provider.of<UserProvider>(context, listen: false);

    final goals = [
      {
        'id': 'protection',
        'emoji': '🌅',
        'title': lp.getText('onb_goal_protection'),
        'sub': 'Shield your day with authentic morning & evening adhkar',
      },
      {
        'id': 'habit',
        'emoji': '📿',
        'title': lp.getText('onb_goal_habit'),
        'sub': 'Build consistency with tasbih counter & streak tracking',
      },
      {
        'id': 'peace',
        'emoji': '🕊️',
        'title': lp.getText('onb_goal_peace'),
        'sub': 'Soothing duas for anxiety, distress & tranquil serenity',
      },
      {
        'id': 'sunnah',
        'emoji': '🤲',
        'title': lp.getText('onb_goal_sunnah'),
        'sub': 'Revive daily Sunnah prayers from sunrise to bedtime',
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 12),
          const Text(
            'Step 2 of 5',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
              color: Color(0xFFF59E0B),
            ),
          ).animate().fadeIn(duration: 300.ms),
          const SizedBox(height: 8),
          Text(
            lp.getText('onb_goal_title'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ).animate().fadeIn(delay: 150.ms).moveY(begin: 10, end: 0),
          const SizedBox(height: 8),
          Text(
            'Select your focus to personalize your daily remembrance.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSlate400,
            ),
          ).animate().fadeIn(delay: 250.ms),
          const SizedBox(height: 24),

          // Goal Option Cards
          ...goals.map((item) {
            final isSelected = item['id'] == _selectedGoal;
            const amberColor = Color(0xFFF59E0B);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedGoal = item['id']!);
                  up.setOnboardingGoal(item['id']!);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? amberColor.withValues(alpha: 0.12)
                        : AppColors.bgCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? amberColor : AppColors.glassBorder,
                      width: isSelected ? 2.0 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: amberColor.withValues(alpha: 0.25),
                              blurRadius: 12,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? amberColor.withValues(alpha: 0.2)
                              : AppColors.ink(0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            item['emoji']!,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['title']!,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? amberColor
                                    : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item['sub']!,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSlate400,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: isSelected ? amberColor : AppColors.ink(0.3),
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 24),
          _primaryBtn(
            text: lp.getText('continue'),
            onTap: _onNext,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 3 — "When is your best time for Dhikr?"
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStep3(LanguageProvider lp) {
    final up = Provider.of<UserProvider>(context, listen: false);

    final times = [
      {
        'id': 'fajr',
        'icon': Icons.wb_twilight_rounded,
        'title': lp.getText('onb_time_fajr'),
        'sub': 'Start your day with dawn barakah and tranquil presence',
      },
      {
        'id': 'asr',
        'icon': Icons.wb_sunny_outlined,
        'title': lp.getText('onb_time_asr'),
        'sub': 'Unwind and reconnect during blessed late afternoon hours',
      },
      {
        'id': 'sleep',
        'icon': Icons.bedtime_outlined,
        'title': lp.getText('onb_time_sleep'),
        'sub': 'End your evening in divine peace, protection and gratitude',
      },
      {
        'id': 'anytime',
        'icon': Icons.all_inclusive_rounded,
        'title': lp.getText('onb_time_anytime'),
        'sub': 'Flexible micro-moments throughout your daily schedule',
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 12),
          const Text(
            'Step 3 of 5',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
              color: Color(0xFFF59E0B),
            ),
          ).animate().fadeIn(duration: 300.ms),
          const SizedBox(height: 8),
          Text(
            lp.getText('onb_time_title'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ).animate().fadeIn(delay: 150.ms).moveY(begin: 10, end: 0),
          const SizedBox(height: 8),
          Text(
            'We will gently align your reminders to suit your natural routine.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSlate400,
            ),
          ).animate().fadeIn(delay: 250.ms),
          const SizedBox(height: 24),

          // Time Option Cards
          ...times.map((item) {
            final isSelected = item['id'] == _selectedTime;
            const amberColor = Color(0xFFF59E0B);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedTime = item['id'] as String);
                  up.setPreferredDhikrTime(item['id'] as String);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? amberColor.withValues(alpha: 0.12)
                        : AppColors.bgCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? amberColor : AppColors.glassBorder,
                      width: isSelected ? 2.0 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: amberColor.withValues(alpha: 0.25),
                              blurRadius: 12,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? amberColor.withValues(alpha: 0.2)
                              : AppColors.ink(0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Icon(
                            item['icon'] as IconData,
                            color: isSelected
                                ? amberColor
                                : AppColors.textPrimary,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['title'] as String,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? amberColor
                                    : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item['sub'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSlate400,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: isSelected ? amberColor : AppColors.ink(0.3),
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 24),
          _primaryBtn(
            text: lp.getText('continue'),
            onTap: _onNext,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 4 — Location & Prayer Times Setup (Animated Mosque Illustration)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStep4(LanguageProvider lp) {
    const primaryColor = Color(0xFFF59E0B);
    final up = Provider.of<UserProvider>(context);

    final isAlreadySaved = up.hasSavedCoordinates || _gpsSucceeded;
    final cityText = _detectedCity ?? (up.city?.isNotEmpty == true ? up.city! : '');
    final countryText = _detectedCountry ?? (up.country?.isNotEmpty == true ? up.country! : '');

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 12),
          const Text(
            'Step 4 of 5',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
              color: primaryColor,
            ),
          ).animate().fadeIn(duration: 300.ms),
          const SizedBox(height: 8),
          Text(
            lp.getText('onb_loc_title'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ).animate().fadeIn(delay: 150.ms).moveY(begin: 10, end: 0),
          const SizedBox(height: 8),
          Text(
            lp.getText('onb_loc_subtitle'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSlate400,
              height: 1.4,
            ),
          ).animate().fadeIn(delay: 250.ms),
          const SizedBox(height: 32),

          // Animated Mosque Illustration
          Center(
            child: SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Glow Ring
                  Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primaryColor.withValues(alpha: 0.1),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.2),
                          blurRadius: 30,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 800.ms)
                      .scale(begin: const Offset(0.95, 0.95), end: const Offset(1.0, 1.0), duration: 800.ms),

                  // Middle Circle
                  Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.bgTeal.withValues(alpha: 0.7),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.35),
                        width: 2,
                      ),
                    ),
                  ),

                  // Mosque Icon
                  Center(
                    child: Icon(
                      Icons.mosque_rounded,
                      color: isAlreadySaved
                          ? const Color(0xFF10B981)
                          : primaryColor,
                      size: 84,
                    ),
                  ).animate().fadeIn(duration: 800.ms),

                  // Locating Spinner
                  if (_isLocating)
                    const Positioned.fill(
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation(primaryColor),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Location Status Card
          if (isAlreadySaved)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF10B981), size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      cityText.isNotEmpty
                          ? '$cityText, $countryText'
                          : lp.getText('onb_loc_success'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95))
          else if (_isLocating)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(primaryColor),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    lp.getText('onb_loc_detecting'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn()
          else
            const SizedBox.shrink(),

          const SizedBox(height: 28),

          // Action Buttons
          if (isAlreadySaved)
            _primaryBtn(
              text: lp.getText('continue'),
              onTap: _onNext,
            )
          else ...[
            _primaryBtn(
              text: lp.getText('onb_loc_enable'),
              onTap: _requestLocation,
              isLoading: _isLocating,
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _onNext,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  lp.getText('onb_loc_manual'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSlate400,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 5 — Welcome & Summary
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStep5(LanguageProvider lp) {
    const primaryColor = Color(0xFFF59E0B);
    final up = Provider.of<UserProvider>(context);

    final name = up.userName?.trim();
    final hasName = name != null && name.isNotEmpty;
    final welcomeText = hasName
        ? 'بِسْمِ اللَّهِ — ${lp.getText('onb_welcome')}, $name!'
        : 'بِسْمِ اللَّهِ — ${lp.getText('onb_welcome')}!';

    // Goal display text
    final goalLabels = {
      'protection': lp.getText('onb_goal_protection'),
      'habit': lp.getText('onb_goal_habit'),
      'peace': lp.getText('onb_goal_peace'),
      'sunnah': lp.getText('onb_goal_sunnah'),
    };
    final goalIcons = {
      'protection': '🌅',
      'habit': '📿',
      'peace': '🕊️',
      'sunnah': '🤲',
    };

    // Time display text
    final timeLabels = {
      'fajr': lp.getText('onb_time_fajr'),
      'asr': lp.getText('onb_time_asr'),
      'sleep': lp.getText('onb_time_sleep'),
      'anytime': lp.getText('onb_time_anytime'),
    };

    final cityText = _detectedCity ?? (up.city?.isNotEmpty == true ? up.city! : '');
    final countryText = _detectedCountry ?? (up.country?.isNotEmpty == true ? up.country! : '');
    final locDisplay = cityText.isNotEmpty
        ? '$cityText, $countryText'
        : 'Set in app';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 12),
          // Bismillah Calligraphy Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
              style: AppText.amiri(
                fontSize: 18,
                color: primaryColor,
              ),
            ),
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 14),

          // Personalized Welcome
          Text(
            welcomeText,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ).animate().fadeIn(delay: 150.ms).moveY(begin: 10, end: 0),
          const SizedBox(height: 8),

          Text(
            'Your tailored spiritual sanctuary is ready.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSlate400,
            ),
          ).animate().fadeIn(delay: 250.ms),
          const SizedBox(height: 24),

          // Summary Glass Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.12),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      lp.getText('onb_summary_title'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Goal summary row
                _buildSummaryRow(
                  iconEmoji: goalIcons[_selectedGoal] ?? '📿',
                  label: lp.getText('onb_summary_goal'),
                  value: goalLabels[_selectedGoal] ?? _selectedGoal,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: Color(0x15FFFFFF)),
                ),

                // Preferred time summary row
                _buildSummaryRow(
                  iconData: Icons.schedule_rounded,
                  label: lp.getText('onb_summary_time'),
                  value: timeLabels[_selectedTime] ?? _selectedTime,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: Color(0x15FFFFFF)),
                ),

                // Location summary row
                _buildSummaryRow(
                  iconData: Icons.location_on_rounded,
                  label: lp.getText('onb_summary_location'),
                  value: locDisplay,
                ),
                const SizedBox(height: 18),

                // Quranic Inspiration Verse
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.ink(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.ink(0.08)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ',
                        textAlign: TextAlign.center,
                        style: AppText.amiri(
                          fontSize: 18,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lp.getText('quran_dhikr_verse'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textSlate400,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.1),

          const SizedBox(height: 32),

          // Begin My Journey CTA Button
          _primaryBtn(
            text: '${lp.getText('onb_begin')} →',
            onTap: _finishOnboarding,
            isLoading: _isLoading,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    String? iconEmoji,
    IconData? iconData,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: iconEmoji != null
                ? Text(iconEmoji, style: const TextStyle(fontSize: 18))
                : Icon(iconData, color: const Color(0xFFF59E0B), size: 18),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSlate400,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MAIN BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    R.init(context);
    final lp = Provider.of<LanguageProvider>(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentPage > 0) {
          _onBack();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.bgDark,
        body: Container(
          decoration: AppDeco.radialBg(
            center: Alignment.topCenter,
            radius: 1.4,
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildTopBar(lp),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const BouncingScrollPhysics(),
                    onPageChanged: (page) => setState(() => _currentPage = page),
                    children: [
                      _buildStep1(lp),
                      _buildStep2(lp),
                      _buildStep3(lp),
                      _buildStep4(lp),
                      _buildStep5(lp),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
