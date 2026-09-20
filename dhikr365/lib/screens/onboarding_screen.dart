import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../providers/user_provider.dart';
import '../providers/language_provider.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import 'dart:math' as math;
import 'location_setup_screen.dart';
import '../utils/first_launch_navigation.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentPage = 0;
  bool _isLoading = false;

  static const int _totalPages = 3;

  // ── navigation ────────────────────────────────────────────────────────────
  void _onNext() {
    if (_currentPage < _totalPages - 1) {
      setState(() => _currentPage++);
    } else {
      _finishOnboarding();
    }
  }

  void _onBack() {
    if (_currentPage > 0) setState(() => _currentPage--);
  }

  Future<void> _finishOnboarding() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    // Persist onboarding completion in the background.
    Provider.of<UserProvider>(context, listen: false)
        .completeOnboarding()
        .catchError((_) {});

    // Capture context-dependent objects before any await.
    final nav = Navigator.of(context);
    final up = Provider.of<UserProvider>(context, listen: false);
    final np = Provider.of<NotificationProvider>(context, listen: false);

    bool gpsSucceeded = false;

    try {
      final gpsResult = await LocationService().tryGps();
      if (!mounted) return;

      if (gpsResult.succeeded) {
        gpsSucceeded = true;
        final lat = gpsResult.coords!.lat;
        final lng = gpsResult.coords!.lng;

        final place = await LocationService().reverseGeocode(lat, lng);
        if (!mounted) return;

        await up.setCoordinates(lat, lng);
        await up.setLocation(place.city, place.country);
        // GPS pick → device timezone is the location's timezone.
        try {
          await up.setTimezone(await FlutterTimezone.getLocalTimezone());
        } catch (_) {}
        if (!mounted) return;

        await NotificationService().requestPermissions();
        try {
          await np.refreshAllSchedules(up);
        } catch (_) {}
        if (!mounted) return;
      }
    } catch (_) {
      // GPS / geocode failure → send to LocationSetupScreen
    }

    if (!mounted) return;
    if (gpsSucceeded) {
      await enterAppForFirstTime(context);
    } else {
      nav.pushReplacement(
        MaterialPageRoute(builder: (_) => const LocationSetupScreen()),
      );
    }
  }

  // ── shared dot indicator ──────────────────────────────────────────────────
  Widget _dots(Color active) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalPages, (i) {
        final isActive = i == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 32 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? active : active.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  // ── shared skip button ────────────────────────────────────────────────────
  Widget _skipBtn(LanguageProvider lp) => GestureDetector(
        onTap: _finishOnboarding,
        child: Text(
          lp.getText('skip'),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.ink(0.4),
          ),
        ),
      );

  // ── primary button (shared) ───────────────────────────────────────────────
  Widget _primaryBtn({
    required String text,
    required VoidCallback onTap,
    required Color color,
    Color? gradientEnd,
  }) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: _isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(100),
        splashColor: AppColors.ink(0.15),
        highlightColor: AppColors.ink(0.08),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, gradientEnd ?? color]),
            borderRadius: BorderRadius.circular(100),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 8)
            ],
          ),
          child: _isLoading && _currentPage == _totalPages - 1
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: AppColors.onPrimary,
                        strokeWidth: 2.5,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('Setting up…',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(text,
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward,
                        color: AppColors.textPrimary, size: 20),
                  ],
                ),
        ),
      ),
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
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
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          layoutBuilder: (currentChild, previousChildren) => Stack(
            fit: StackFit.expand,
            children: [
              ...previousChildren,
              if (currentChild != null) currentChild
            ],
          ),
          child: KeyedSubtree(
            key: ValueKey<int>(_currentPage),
            child: switch (_currentPage) {
              0 => _page0(lp),
              1 => _page1(lp),
              _ => _page2(lp),
            },
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PAGE 0 — Stay Consistent  (ring illustration)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _page0(LanguageProvider lp) {
    const primaryColor = Color(0xFFF49D25);
    final bgDark = AppColors.bgDeep;
    final bgTeal = AppColors.bgTeal;

    return LayoutBuilder(builder: (context, constraints) {
      final h = constraints.maxHeight;
      final w = constraints.maxWidth;
      final isSmall = h < 700;
      final ringSize = (h * 0.32).clamp(180.0, 275.0);
      final strokeW = (ringSize * 0.058).clamp(10.0, 16.0);
      final iconSize = ringSize * 0.185;

      return Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.2,
            colors: [bgTeal, bgDark],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── top bar: no back button on page 0, skip on right ──
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: 24, vertical: isSmall ? 8 : 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 48),
                    Text('1 / $_totalPages',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2.0,
                            color: AppColors.ink(0.4))),
                    _skipBtn(lp),
                  ],
                ),
              ),
              // ── illustration ──
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: ringSize + 40,
                      height: ringSize + 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primaryColor.withValues(alpha: 0.1),
                        boxShadow: [
                          BoxShadow(
                              color: primaryColor.withValues(alpha: 0.1),
                              blurRadius: 10)
                        ],
                      ),
                    ),
                    Positioned(
                        top: 0,
                        right: w * 0.05,
                        child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: primaryColor.withValues(alpha: 0.3),
                                boxShadow: const [
                                  BoxShadow(color: primaryColor, blurRadius: 8)
                                ]))),
                    Positioned(
                        bottom: 0,
                        left: w * 0.1,
                        child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.teal.withValues(alpha: 0.3),
                                boxShadow: const [
                                  BoxShadow(color: Colors.teal, blurRadius: 8)
                                ]))),
                    SizedBox(
                      width: ringSize,
                      height: ringSize,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: primaryColor.withValues(alpha: 0.2),
                                    width: strokeW)),
                          ),
                          Positioned.fill(
                            child: Transform.rotate(
                              angle: -math.pi / 2,
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.0, end: 0.7),
                                duration: const Duration(seconds: 1),
                                curve: Curves.easeOutCubic,
                                builder: (_, value, __) =>
                                    CircularProgressIndicator(
                                  value: value,
                                  strokeWidth: strokeW,
                                  backgroundColor: Colors.transparent,
                                  valueColor: const AlwaysStoppedAnimation(
                                      primaryColor),
                                  strokeCap: StrokeCap.round,
                                ),
                              ),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.flare,
                                  color: primaryColor, size: iconSize),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(lp.getText('sun_morning'),
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 2.0,
                                        color: primaryColor)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // ── bottom content ──
              Flexible(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(32, 0, 32, isSmall ? 24 : 48),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(lp.getText('onboarding_title_1'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: isSmall ? 26 : 32,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    height: 1.2,
                                    letterSpacing: -0.5))
                            .animate()
                            .fadeIn(delay: 300.ms)
                            .moveY(begin: 20, end: 0),
                        SizedBox(height: isSmall ? 8 : 16),
                        Text(lp.getText('onboarding_desc_1'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: isSmall ? 13 : 16,
                                    color: AppColors.ink(0.7),
                                    height: 1.5))
                            .animate()
                            .fadeIn(delay: 500.ms)
                            .moveY(begin: 20, end: 0),
                        SizedBox(height: isSmall ? 16 : 32),
                        _dots(primaryColor),
                        SizedBox(height: isSmall ? 16 : 32),
                        _primaryBtn(
                            text: lp.getText('continue'),
                            onTap: _onNext,
                            color: primaryColor,
                            gradientEnd: const Color(0xFFF97316)),
                        SizedBox(height: isSmall ? 16 : 32),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PAGE 1 — Purify Your Heart  (mosque illustration)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _page1(LanguageProvider lp) {
    const primaryColor = Color(0xFFEC7F13);
    final bgDark = AppColors.bgDark;
    const bgTeal = Color(0xFF002B2B);

    return LayoutBuilder(builder: (context, constraints) {
      final h = constraints.maxHeight;
      final isSmall = h < 700;

      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgTeal, bgDark],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── top bar: back button + page counter + skip ──
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: 24, vertical: isSmall ? 8 : 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: _onBack,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primaryColor.withValues(alpha: 0.1),
                        ),
                        child: Icon(Icons.chevron_left,
                            color: AppColors.textPrimary),
                      ),
                    ),
                    Text('2 / $_totalPages',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2.0,
                            color: AppColors.ink(0.4))),
                    _skipBtn(lp),
                  ],
                ),
              ),
              // ── illustration ──
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 256,
                      height: 256,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primaryColor.withValues(alpha: 0.2),
                        boxShadow: [
                          BoxShadow(
                              color: primaryColor.withValues(alpha: 0.2),
                              blurRadius: 10)
                        ],
                      ),
                    ),
                    Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        color: AppColors.shadow(0.3),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: primaryColor.withValues(alpha: 0.35),
                              blurRadius: 10),
                          const BoxShadow(
                              color: Color(0xFFFF9D3F), blurRadius: 8),
                        ],
                      ),
                      child: Center(
                        child: Icon(Icons.mosque,
                            color: AppColors.textPrimary, size: 110),
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 800.ms)
                        .scale(begin: const Offset(0.9, 0.9)),
                  ],
                ),
              ),
              // ── bottom content ──
              Flexible(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(32, 0, 32, isSmall ? 24 : 48),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(lp.getText('onboarding_title_2'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: isSmall ? 26 : 32,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    height: 1.2,
                                    letterSpacing: -0.5))
                            .animate()
                            .fadeIn(delay: 300.ms)
                            .moveY(begin: 20, end: 0),
                        SizedBox(height: isSmall ? 8 : 16),
                        Text(lp.getText('onboarding_desc_2'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: isSmall ? 14 : 16,
                                    color: AppColors.ink(0.7),
                                    height: 1.5))
                            .animate()
                            .fadeIn(delay: 500.ms)
                            .moveY(begin: 20, end: 0),
                        SizedBox(height: isSmall ? 16 : 32),
                        _dots(primaryColor),
                        SizedBox(height: isSmall ? 16 : 32),
                        _primaryBtn(
                            text: lp.getText('continue'),
                            onTap: _onNext,
                            color: primaryColor,
                            gradientEnd: const Color(0xFFFF9D3F)),
                        SizedBox(height: isSmall ? 16 : 32),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PAGE 2 — Your Plan, Your Way  (cards illustration) — LAST PAGE
  // No skip button. "Get Started" shows loading spinner.
  // ══════════════════════════════════════════════════════════════════════════
  Widget _page2(LanguageProvider lp) {
    const primaryColor = Color(0xFFEC7F13);
    const bgDark = Color(0xFF120D08);

    return LayoutBuilder(builder: (context, constraints) {
      final h = constraints.maxHeight;
      final isSmall = h < 700;
      final cardSize = (h * 0.36).clamp(220.0, 310.0);

      return Container(
        color: bgDark,
        child: SafeArea(
          child: Column(
            children: [
              // ── top bar: back button + page counter, NO skip on last page ──
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: 24, vertical: isSmall ? 8 : 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: _isLoading ? null : _onBack,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primaryColor.withValues(alpha: 0.1),
                        ),
                        child: Icon(Icons.chevron_left,
                            color: AppColors.textPrimary),
                      ),
                    ),
                    Text('3 / 3',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2.0,
                            color: AppColors.textPrimary)),
                    // Empty space where skip was — keeps title centred
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              // ── illustration ──
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            primaryColor.withValues(alpha: 0.05),
                            Colors.transparent
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: cardSize,
                      height: cardSize,
                      child: Stack(
                        children: [
                          Positioned(
                            top: cardSize * 0.033,
                            left: cardSize * 0.133,
                            right: cardSize * 0.133,
                            bottom: cardSize * 0.167,
                            child: Transform(
                              transform: Matrix4.identity()..rotateZ(-0.08),
                              alignment: Alignment.center,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF1E293B),
                                        Color(0xFF0F172A)
                                      ]),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.ink(0.1)),
                                  boxShadow: [
                                    BoxShadow(
                                        color: AppColors.shadow(0.54),
                                        blurRadius: 8)
                                  ],
                                ),
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                          width: 48,
                                          height: 8,
                                          decoration: BoxDecoration(
                                              color: primaryColor.withValues(
                                                  alpha: 0.4),
                                              borderRadius:
                                                  BorderRadius.circular(4))),
                                      const SizedBox(height: 16),
                                      Container(
                                          width: 150,
                                          height: 16,
                                          decoration: BoxDecoration(
                                              color: AppColors.ink(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8))),
                                      const SizedBox(height: 8),
                                      Container(
                                          width: 100,
                                          height: 16,
                                          decoration: BoxDecoration(
                                              color: AppColors.ink(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8))),
                                      const Spacer(),
                                      Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                    color: primaryColor
                                                        .withValues(alpha: 0.2),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8)),
                                                child: const Icon(
                                                    Icons.settings_suggest,
                                                    color: primaryColor,
                                                    size: 16)),
                                            Container(
                                                width: 64,
                                                height: 24,
                                                decoration: BoxDecoration(
                                                    color: primaryColor
                                                        .withValues(alpha: 0.8),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12))),
                                          ]),
                                    ]),
                              ),
                            ),
                          )
                              .animate()
                              .fadeIn(duration: 800.ms)
                              .slideY(begin: 0.1),
                          Positioned(
                            top: cardSize * 0.133,
                            left: cardSize * 0.067,
                            right: cardSize * 0.067,
                            bottom: cardSize * 0.067,
                            child: Transform(
                              transform: Matrix4.identity()..rotateZ(0.06),
                              alignment: Alignment.center,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF1E293B),
                                        Color(0xFF0F172A)
                                      ]),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color:
                                          primaryColor.withValues(alpha: 0.3)),
                                  boxShadow: [
                                    BoxShadow(
                                        color: AppColors.shadow(0.54),
                                        blurRadius: 8)
                                  ],
                                ),
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                                width: 48,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                    color: primaryColor,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4))),
                                            const Icon(Icons.check_circle,
                                                color: primaryColor, size: 20),
                                          ]),
                                      const SizedBox(height: 16),
                                      Container(
                                          width: double.infinity,
                                          height: 16,
                                          decoration: BoxDecoration(
                                              color: AppColors.ink(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8))),
                                      const SizedBox(height: 8),
                                      Container(
                                          width: 200,
                                          height: 16,
                                          decoration: BoxDecoration(
                                              color: AppColors.ink(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8))),
                                      const SizedBox(height: 8),
                                      Container(
                                          width: 150,
                                          height: 16,
                                          decoration: BoxDecoration(
                                              color: AppColors.ink(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8))),
                                      const Spacer(),
                                      Row(children: [
                                        Container(
                                            width: 48,
                                            height: 24,
                                            decoration: BoxDecoration(
                                                color: primaryColor.withValues(
                                                    alpha: 0.2),
                                                borderRadius:
                                                    BorderRadius.circular(12))),
                                        const SizedBox(width: 8),
                                        Container(
                                            width: 48,
                                            height: 24,
                                            decoration: BoxDecoration(
                                                color: primaryColor.withValues(
                                                    alpha: 0.2),
                                                borderRadius:
                                                    BorderRadius.circular(12))),
                                      ]),
                                    ]),
                              ),
                            ),
                          )
                              .animate()
                              .fadeIn(duration: 800.ms, delay: 200.ms)
                              .slideY(begin: 0.1),
                          Positioned(
                            bottom: cardSize * 0.033,
                            right: cardSize * 0.033,
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                      color:
                                          primaryColor.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4))
                                ],
                              ),
                              child: Icon(Icons.tune,
                                  color: AppColors.textPrimary, size: 32),
                            ).animate().fadeIn(duration: 600.ms, delay: 400.ms),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // ── bottom content ──
              Flexible(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        32, isSmall ? 8 : 16, 32, isSmall ? 24 : 48),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(lp.getText('onboarding_title_3'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: isSmall ? 26 : 32,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    height: 1.2,
                                    letterSpacing: -0.5))
                            .animate()
                            .fadeIn(delay: 300.ms)
                            .moveY(begin: 20, end: 0),
                        SizedBox(height: isSmall ? 8 : 16),
                        Text(lp.getText('onboarding_desc_3'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: isSmall ? 13 : 16,
                                    color: AppColors.ink(0.7),
                                    height: 1.5))
                            .animate()
                            .fadeIn(delay: 500.ms)
                            .moveY(begin: 20, end: 0),
                        SizedBox(height: isSmall ? 16 : 32),
                        _dots(primaryColor),
                        SizedBox(height: isSmall ? 16 : 32),
                        _primaryBtn(
                          text: lp.getText('get_started'),
                          onTap: _finishOnboarding,
                          color: primaryColor,
                        ),
                        SizedBox(height: isSmall ? 16 : 32),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
