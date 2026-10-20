import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:adhan/adhan.dart';
import '../providers/dhikr_provider.dart';
import '../providers/language_provider.dart';
import '../providers/user_provider.dart';
import '../providers/custom_plan_provider.dart';
import '../providers/purchase_provider.dart';
import '../models/dhikr.dart';
import '../constants/app_theme.dart';
import '../utils/responsive.dart';
import '../utils/date_formatter.dart';
import 'dhikr_list_screen.dart';
import 'donation_screen.dart';
import 'location_setup_screen.dart';
import '../services/notification_service.dart';
import '../widgets/battery_reliability_dialogs.dart';
import '../widgets/friday_sadaqah_card.dart';
import '../widgets/muhsin_badge.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  bool _isListening = false;
  late final AnimationController _pulseCtrl;
  bool _notifGranted = true;
  bool _exactGranted = true;
  bool _batteryExempt = true;

  bool get _hasReminderWarning =>
      !_notifGranted || !_exactGranted || !_batteryExempt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _checkNotificationStatus();
  }

  Future<void> _checkNotificationStatus() async {
    try {
      final notif = await NotificationService().areNotificationsEnabled();
      final exact = await NotificationService().isExactAlarmGranted();
      final battery =
          await NotificationService().isIgnoringBatteryOptimizations();
      if (mounted) {
        setState(() {
          _notifGranted = notif;
          _exactGranted = exact;
          _batteryExempt = battery;
        });
      }
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkNotificationStatus();
      if (_isListening && !_pulseCtrl.isAnimating && mounted) {
        _pulseCtrl.repeat();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      if (_isListening && _pulseCtrl.isAnimating) {
        _pulseCtrl.stop();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _toggleListening() {
    setState(() => _isListening = !_isListening);
    if (_isListening) {
      _pulseCtrl.repeat();
    } else {
      _pulseCtrl.stop();
      _pulseCtrl.reset();
    }
  }

  void _showLocationPicker(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LocationPickerSheet(userProvider: userProvider),
    );
  }

  bool _isMorningTime(UserProvider userProvider, DateTime now) {
    if (userProvider.hasSavedCoordinates) {
      try {
        final coords = Coordinates(userProvider.lat!, userProvider.lng!);
        final params = userProvider.calculationMethod.getParameters()
          ..madhab = userProvider.madhab.toLowerCase() == 'hanafi'
              ? Madhab.hanafi
              : Madhab.shafi;
        final date = DateComponents.from(now);
        final times = PrayerTimes(coords, date, params);

        // Morning adhkar: From Fajr time until Asr prayer time starts
        // Evening adhkar: From Asr time until next Fajr
        return now.isAfter(times.fajr) && now.isBefore(times.asr);
      } catch (_) {}
    }
    // Fallback if coordinates are not available:
    // Islamic morning starts at dawn (~4:00 AM) until Asr (~3:30 PM / 15:30)
    return now.hour >= 4 && (now.hour < 15 || (now.hour == 15 && now.minute < 30));
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);

    final lp = Provider.of<LanguageProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final customPlanProvider = Provider.of<CustomPlanProvider>(context);
    final pp = Provider.of<PurchaseProvider>(context);
    final now = DateTime.now();
    final isMorning = _isMorningTime(userProvider, now);
    final langCode = lp.locale.languageCode;
    // Fully localized Gregorian and Hijri dates
    final formattedDate =
        AppDateFormatter.formatGregorian(now, langCode, pattern: 'EEEE, d MMMM yyyy');
    final hijriDate =
        AppDateFormatter.formatHijri(HijriCalendar.now(), langCode);

    final displayName = (userProvider.userName?.isNotEmpty == true)
        ? userProvider.userName!
        : lp.getText('guest');
    final initials = displayName
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    final location = (userProvider.city?.isNotEmpty == true)
        ? '${userProvider.city}, ${userProvider.country}'
        : lp.getText('tap_to_set_location');

    // Responsive sizes
    final avatarSize = R.adaptive(36.0, 40.0, 52.0);
    final ringSize = R.adaptive(120.0, 150.0, 200.0);
    final ringStroke = R.adaptive(6.0, 8.0, 10.0);
    final ringFontSize = R.adaptive(28.0, 36.0, 44.0);
    final arabicSize = R.adaptive(22.0, 28.0, 34.0);
    final btnHeight = R.adaptive(48.0, 56.0, 64.0);
    final hPad = R.adaptive(14.0, 20.0, 28.0);
    final vGap = R.adaptive(12.0, 20.0, 28.0);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Stack(
        children: [
          // ── Layer 1: green → dark-green → black radial background ────────
          // Matches: radial-gradient(circle at top, #133a36 0%, #0a1f1d 70%,
          //          #000000 100%)
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.4,
                colors: AppColors.homeGradient,
                stops: const [0.0, 0.7, 1.0],
              ),
            ),
          ),
          // ── Layer 2: UI content ───────────────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              padding:
                  EdgeInsets.symmetric(horizontal: hPad, vertical: R.px(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Location setup banner ─────────────────────────────────
                  // Visible only when no coordinates are saved — zero height
                  // when hasSavedCoordinates is true.
                  if (!userProvider.hasSavedCoordinates)
                    _LocationBanner(
                      onSetNow: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LocationSetupScreen()),
                      ),
                    ),

                  // ── Header ──────────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Container(
                          width: avatarSize,
                          height: avatarSize,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color:
                                    AppColors.primary.withValues(alpha: 0.4)),
                          ),
                          child: Center(
                              child: Text(
                            initials.isEmpty ? '?' : initials,
                            style: AppText.manrope(
                              fontSize: R.adaptive(11, 14, 16),
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          )),
                        ),
                        SizedBox(width: R.px(10)),
                        Text(displayName,
                            style: AppText.manrope(
                                fontSize: R.adaptive(12, 14, 16),
                                color: AppColors.textSlate400)),
                        if (userProvider.isMuhsin(pp)) ...[
                          SizedBox(width: R.px(8)),
                          const MuhsinBadge(isSmall: true),
                        ],
                      ]),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const DonationScreen())),
                        child: Container(
                          width: avatarSize,
                          height: avatarSize,
                          decoration: BoxDecoration(
                            color: AppColors.ink(0.05),
                            borderRadius: BorderRadius.circular(R.px(10)),
                            border: Border.all(color: AppColors.ink(0.08)),
                          ),
                          child: Icon(Icons.volunteer_activism,
                              color: AppColors.primary, size: R.sp(18)),
                        ),
                      )
                          .animate()
                          .fadeIn()
                          .animate(onPlay: (controller) => controller.repeat())
                          .shimmer(
                              duration: 2000.ms,
                              color: AppColors.ink(0.2),
                              delay: 1500.ms),
                    ],
                  ).animate().fadeIn(),

                  SizedBox(height: vGap),

                  // ── Date ─────────────────────────────────────────────────────
                  Text(formattedDate,
                          style: AppText.manrope(
                              fontSize: R.adaptive(11, 14, 16),
                              fontWeight: FontWeight.w600))
                      .animate()
                      .fadeIn(delay: 100.ms),
                  SizedBox(height: R.px(2)),
                  Text(hijriDate,
                          style: AppText.body(color: AppColors.textSlate400)
                              .copyWith(fontSize: R.sp(R.adaptive(10, 12, 14))))
                      .animate()
                      .fadeIn(delay: 150.ms),
                  SizedBox(height: R.px(4)),

                  // ── Tappable location row ─────────────────────────────────────
                  // When no location is saved, "Tap to set location" goes straight
                  // to LocationSetupScreen instead of the edit sheet — that screen
                  // is designed for first-time setup and handles GPS + manual entry.
                  GestureDetector(
                    onTap: () => userProvider.hasSavedCoordinates
                        ? _showLocationPicker(context)
                        : Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const LocationSetupScreen()),
                          ),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: R.px(3)),
                      child: Row(children: [
                        Icon(Icons.location_on,
                            color: AppColors.primary, size: R.sp(13)),
                        SizedBox(width: R.px(4)),
                        Flexible(
                          child: Text(
                            location,
                            style: AppText.manrope(
                                fontSize: R.adaptive(10, 11, 13),
                                color: AppColors.textSlate400),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: R.px(4)),
                        Icon(Icons.edit_outlined,
                            size: R.sp(11), color: AppColors.textSlate500),
                      ]),
                    ),
                  ).animate().fadeIn(delay: 200.ms),

                  // ── Friday Sadaqah Barakah Card (Jumu'ah exclusive) ───────────
                  const FridaySadaqahCard(),

                  SizedBox(height: vGap),

                  // ── Streak chip ──────────────────────────────────────────────
                  // Shown only when the user has an active streak (≥ 1 day).
                  Consumer<DhikrProvider>(
                    builder: (context, dp, _) {
                      if (dp.streakDays <= 0) return const SizedBox.shrink();
                      return Padding(
                        padding: EdgeInsets.only(bottom: vGap),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFF97316),
                                    Color(0xFFEA580C)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFF97316)
                                        .withValues(alpha: 0.35),
                                    blurRadius: 12,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('🔥',
                                      style: TextStyle(fontSize: 16)),
                                  const SizedBox(width: 6),
                                  Text(
                                    R.localizeDigits(
                                        '${dp.streakDays}', langCode),
                                    style: AppText.manrope(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    lp.getText('day_streak'),
                                    style: AppText.manrope(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.ink(0.85),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 220.ms)
                          .slideY(begin: 0.3, end: 0);
                    },
                  ),

                  // ── Plan Switcher ────────────────────────────────────────────
                  Center(
                    child: Container(
                      padding: EdgeInsets.all(R.px(4)),
                      decoration: BoxDecoration(
                        color: AppColors.ink(0.05),
                        borderRadius: BorderRadius.circular(R.px(30)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        _Tab(
                          label: lp.getText('plan_standard'),
                          isActive: !customPlanProvider.useCustomPlan,
                          onTap: () =>
                              customPlanProvider.setUseCustomPlan(false),
                        ),
                        _Tab(
                          label: lp.getText('plan_my'),
                          isActive: customPlanProvider.useCustomPlan,
                          onTap: () => customPlanProvider.setUseCustomPlan(true),
                        ),
                      ]),
                    ),
                  ).animate().fadeIn(delay: 300.ms),

                  SizedBox(height: vGap),

                  // ── Progress Ring + Pulse Glow ────────────────────────────────
                  // Tap the ring to toggle the listening/glow animation.
                  Consumer2<DhikrProvider, CustomPlanProvider>(
                    builder: (context, dp, cp, _) {
                      List<Dhikr> activeDhikrs = dp.dhikrs;
                      if (cp.useCustomPlan) {
                        activeDhikrs = activeDhikrs
                            .where((d) => cp.isDhikrEnabled(d.id))
                            .toList();
                      }
                      final progress = dp.calculateProgressFor(activeDhikrs);

                      return Center(
                        child: GestureDetector(
                          onTap: _toggleListening,
                          behavior: HitTestBehavior.opaque,
                          child: _PulseGlow(
                            controller: _pulseCtrl,
                            isListening: _isListening,
                            ringSize: ringSize,
                            color: AppColors.primary,
                            child: SizedBox(
                              width: ringSize,
                              height: ringSize,
                              child: Stack(fit: StackFit.expand, children: [
                                CircularProgressIndicator(
                                  value: progress,
                                  strokeWidth: ringStroke,
                                  backgroundColor: AppColors.ink(0.05),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.primary),
                                ),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      R.localizeDigits(
                                          '${(progress * 100).toInt()}%',
                                          langCode),
                                      style: AppText.manrope(
                                          fontSize: ringFontSize,
                                          fontWeight: FontWeight.w800),
                                    ),
                                    Text(
                                      lp.getText('completed'),
                                      style: AppText.body(
                                              color: AppColors.textSlate400)
                                          .copyWith(
                                              fontSize:
                                                  R.sp(R.adaptive(10, 12, 14))),
                                    ),
                                    // Listening hint label
                                    AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      child: _isListening
                                          ? Padding(
                                              key: const ValueKey('on'),
                                              padding:
                                                  const EdgeInsets.only(top: 6),
                                              child: Text(
                                                '● LISTENING',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.primary
                                                      .withValues(alpha: 0.8),
                                                  letterSpacing: 1.5,
                                                ),
                                              ),
                                            )
                                          : const SizedBox.shrink(
                                              key: ValueKey('off')),
                                    ),
                                  ],
                                ),
                              ]),
                            ),
                          ),
                        ),
                      );
                    },
                  ).animate().scale(
                      delay: 400.ms,
                      duration: 600.ms,
                      curve: Curves.easeOutBack),

                  SizedBox(height: vGap),

                  // ── Dua Card ──────────────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                        vertical: R.px(16), horizontal: R.px(14)),
                    decoration: AppDeco.glassCard(
                        borderRadius: BorderRadius.circular(R.px(20))),
                    child: Column(children: [
                      Text(
                        isMorning ? 'اللهم بك اصبحنا' : 'اللهم بك امسينا',
                        style: AppText.amiri(fontSize: arabicSize),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: R.px(10)),
                      Text(
                        isMorning
                            ? lp.getText('morning_dua_trans')
                            : lp.getText('evening_dua_trans'),
                        style: AppText.body(color: AppColors.textSlate400)
                            .copyWith(fontSize: R.sp(R.adaptive(12, 14, 16))),
                        textAlign: TextAlign.center,
                      ),
                    ]),
                  ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),

                  SizedBox(height: R.px(14)),

                  // ── Action Button ─────────────────────────────────────────────
                  GestureDetector(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => DhikrListScreen(
                                category: isMorning
                                    ? DhikrCategory.morning
                                    : DhikrCategory.evening))),
                    child: Container(
                      width: double.infinity,
                      height: btnHeight,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(R.px(32)),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 5))
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // onPrimary (not textPrimary): this row sits on a
                          // solid AppColors.primary fill. On monochrome themes
                          // (E Ink Reader, Pencil Sketch) primary and
                          // textPrimary are both near-black, so textPrimary
                          // renders invisible text on a black button.
                          Icon(isMorning ? Icons.wb_sunny : Icons.nights_stay,
                              color: AppColors.onPrimary, size: R.sp(18)),
                          SizedBox(width: R.px(8)),
                          Text(
                            // Use morning_adhkar / evening_adhkar — these keys
                            // are already translated in all 19 language files.
                            // morning_dhikr / evening_dhikr were missing from
                            // most language files and always fell back to English.
                            isMorning
                                ? lp.getText('morning_adhkar')
                                : lp.getText('evening_adhkar'),
                            style: AppText.manrope(
                                fontSize: R.adaptive(14, 16, 18),
                                fontWeight: FontWeight.w700,
                                color: AppColors.onPrimary),
                          ),
                        ],
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 600.ms)
                      .slideY(begin: 0.2)
                      .animate(onPlay: (controller) => controller.repeat())
                      .shimmer(
                          duration: 2500.ms,
                          color: AppColors.ink(0.3),
                          delay: 1000.ms),

                  SizedBox(height: R.px(12)),

                  // ── Category Cards (Personalized by Onboarding Goal) ───────────
                  Builder(builder: (context) {
                    final goal = userProvider.onboardingGoal;
                    final DhikrCategory primaryCat = (goal == 'peace')
                        ? DhikrCategory.distress
                        : DhikrCategory.protection;
                    final DhikrCategory secondaryCat = (goal == 'habit')
                        ? DhikrCategory.focus
                        : (goal == 'sunnah')
                            ? DhikrCategory.afterSalah
                            : (goal == 'peace')
                                ? DhikrCategory.protection
                                : DhikrCategory.focus;

                    return Row(children: [
                      Expanded(
                          child: _CategoryCard(
                        icon: primaryCat.icon,
                        label: lp.getText(primaryCat.titleKey),
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    DhikrListScreen(category: primaryCat))),
                      )),
                      SizedBox(width: R.px(12)),
                      Expanded(
                        child: _hasReminderWarning
                            ? _ReminderWarningCard(
                                onTap: () =>
                                    _showReminderReliabilitySheet(context, lp),
                              )
                            : _CategoryCard(
                                icon: secondaryCat.icon,
                                label: lp.getText(secondaryCat.titleKey),
                                isHealthy: true,
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => DhikrListScreen(
                                            category: secondaryCat))),
                              ),
                      ),
                    ]).animate().fadeIn(delay: 700.ms).slideY(begin: 0.2);
                  }),

                  SizedBox(height: R.px(100)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReminderReliabilitySheet(
      BuildContext context, LanguageProvider lp) {
    final isBn = lp.locale.languageCode == 'bn';
    const warningAmber = Color(0xFFF59E0B);
    const emeraldGreen = Color(0xFF10B981);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final allSet = _notifGranted && _exactGranted && _batteryExempt;

            return Container(
              padding: EdgeInsets.fromLTRB(
                R.px(20),
                R.px(16),
                R.px(20),
                R.px(28) + MediaQuery.paddingOf(context).bottom,
              ),
              decoration: BoxDecoration(
                color: AppColors.bgTeal,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: AppColors.ink(0.12)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.ink(0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    SizedBox(height: R.px(16)),

                    // Header with Icon
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: (allSet ? emeraldGreen : warningAmber)
                                .withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: (allSet ? emeraldGreen : warningAmber)
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Icon(
                            allSet
                                ? Icons.verified_rounded
                                : Icons.notification_important_rounded,
                            color: allSet ? emeraldGreen : warningAmber,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: R.px(12)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                allSet
                                    ? (isBn
                                        ? 'আজান ও রিমাইন্ডার সক্রিয়'
                                        : 'All Reminders Active')
                                    : (isBn
                                        ? 'রিমাইন্ডার ও আজান সেটআপ'
                                        : 'Reminder & Azan Setup'),
                                style: AppText.heading(17),
                              ),
                              SizedBox(height: R.px(2)),
                              Text(
                                allSet
                                    ? (isBn
                                        ? 'আপনার ফোনে সব অ্যালার্ম ১০০% প্রস্তুত'
                                        : 'Your phone is 100% ready for on-time alerts')
                                    : (isBn
                                        ? 'কেন এই পারমিশনগুলো জরুরি?'
                                        : 'Why are these permissions essential?'),
                                style: AppText.manrope(
                                  fontSize: 12,
                                  color: allSet
                                      ? emeraldGreen
                                      : AppColors.textSlate400,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: R.px(14)),

                    // Explainer paragraph
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.ink(0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.ink(0.08)),
                      ),
                      child: Text(
                        isBn
                            ? 'অ্যান্ড্রয়েড ফোন (বিশেষ করে Samsung, Xiaomi, Vivo, Oppo) ব্যাটারি বাঁচাতে ব্যাকগ্রাউন্ডের অ্যাপ বন্ধ করে দেয়। নিচের ৩টি সেটিংস অন রাখলে প্রতিটি ওয়াক্তের আজান ও সকাল-সন্ধ্যার জিকির সঠিক সেকেন্ডে আপনার ফোনে বাজবে।'
                            : 'Android battery savers often silence prayer apps in the background. Enabling these 3 settings guarantees every Azan and Adhkar alarm arrives exactly on time without delay.',
                        style: AppText.body(color: AppColors.textSlate300)
                            .copyWith(height: 1.45, fontSize: 12),
                      ),
                    ),
                    SizedBox(height: R.px(16)),

                    // Item 1: Notification Permission
                    _buildPermissionItem(
                      icon: Icons.notifications_active_rounded,
                      title: isBn ? 'নোটিফিকেশন অ্যালার্ট' : 'Notification Alerts',
                      desc: isBn
                          ? 'আজানের বার্তা ও স্ক্রিন নোটিফিকেশন প্রদর্শন'
                          : 'Show azan popups & status bar banners',
                      isGranted: _notifGranted,
                      actionLabel: isBn ? 'অনুমতি দিন' : 'Allow',
                      onAction: () async {
                        await NotificationService().requestPermissions();
                        final granted =
                            await NotificationService().areNotificationsEnabled();
                        if (!granted && context.mounted) {
                          await NotificationService().openNotificationSettings();
                        }
                        await _checkNotificationStatus();
                        setModalState(() {});
                      },
                    ),
                    SizedBox(height: R.px(10)),

                    // Item 2: Exact Alarm Permission
                    _buildPermissionItem(
                      icon: Icons.alarm_on_rounded,
                      title: isBn ? 'সঠিক সময়ের অ্যালার্ম' : 'Exact Alarms',
                      desc: isBn
                          ? 'নির্ধারিত সঠিক মিনিটে আজান বাজার অনুমতি'
                          : 'Sound azan at the precise prescribed minute',
                      isGranted: _exactGranted,
                      actionLabel: isBn ? 'অনুমতি দিন' : 'Allow',
                      onAction: () async {
                        await NotificationService().openExactAlarmSettings();
                        await _checkNotificationStatus();
                        setModalState(() {});
                      },
                    ),
                    SizedBox(height: R.px(10)),

                    // Item 3: Battery Optimization Unrestricted
                    _buildPermissionItem(
                      icon: Icons.battery_charging_full_rounded,
                      title: isBn ? 'ব্যাকগ্রাউন্ড ব্যাটারি সচল' : 'Battery Unrestricted',
                      desc: isBn
                          ? 'স্যামসাং/শাওমি যাতে ঘুমন্ত অবস্থায় আজান না থামায়'
                          : 'Prevent phone OS from killing background azan',
                      isGranted: _batteryExempt,
                      actionLabel: isBn ? 'গাইড দেখুন' : 'Configure',
                      onAction: () async {
                        await showBatteryExplainerDialog(context);
                        await _checkNotificationStatus();
                        setModalState(() {});
                      },
                    ),
                    SizedBox(height: R.px(20)),

                    // Bottom Action / Close Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              allSet ? emeraldGreen : AppColors.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          allSet
                              ? (isBn ? 'সম্পন্ন (Done)' : 'Done')
                              : (isBn ? 'ঠিক আছে / বন্ধ করুন' : 'Done for now'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String desc,
    required bool isGranted,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    const emeraldGreen = Color(0xFF10B981);
    const warningAmber = Color(0xFFF59E0B);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isGranted
            ? emeraldGreen.withValues(alpha: 0.08)
            : warningAmber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isGranted
              ? emeraldGreen.withValues(alpha: 0.25)
              : warningAmber.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isGranted ? emeraldGreen : warningAmber,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: AppText.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (isGranted)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: emeraldGreen,
                        size: 15,
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: AppText.manrope(
                    fontSize: 11,
                    color: AppColors.textSlate400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isGranted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: emeraldGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '✓ Active',
                style: TextStyle(
                  color: emeraldGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                backgroundColor: warningAmber,
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _PulseGlow — scoped entirely to HomeScreen (private, not exported)
//
// Wraps any child with a continuously-animated glow effect.
// The controller lifecycle is owned by _HomeScreenState, so this widget is
// purely presentational — no animation state or timers of its own.
// ══════════════════════════════════════════════════════════════════════════════

class _PulseGlow extends StatelessWidget {
  final AnimationController controller;
  final bool isListening;
  final Widget child;
  final double ringSize;
  final Color color;

  const _PulseGlow({
    required this.controller,
    required this.isListening,
    required this.child,
    required this.ringSize,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // When not listening, render the child with zero overhead.
    if (!isListening) return child;

    // glowArea is larger than ringSize so the expanding rings have room to
    // grow without being clipped by the parent layout.
    final glowArea = ringSize * 1.7;

    return SizedBox(
      width: glowArea,
      height: glowArea,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Two rings with a 0.5 phase offset create a natural breathing rhythm.
          AnimatedBuilder(
            animation: controller,
            builder: (_, __) => Stack(
              alignment: Alignment.center,
              children: [
                _PulseRing(
                  t: controller.value,
                  size: ringSize,
                  color: color,
                ),
                _PulseRing(
                  t: (controller.value + 0.5) % 1.0,
                  size: ringSize,
                  color: color,
                ),
              ],
            ),
          ),
          // Child sits on top of the rings, centred.
          child,
        ],
      ),
    );
  }
}

/// A single expanding, fading ring driven by a normalised [t] value (0 → 1).
/// Stateless — the parent AnimatedBuilder owns the rebuild cycle.
class _PulseRing extends StatelessWidget {
  final double t; // animation progress 0.0 – 1.0
  final double size; // base diameter (matches the progress ring)
  final Color color;

  const _PulseRing({
    required this.t,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Scale: ring starts at 80% of the base size and expands to 145%.
    final scale = 0.80 + (t * 0.65);

    // Opacity: full at t=0, eases out to transparent at t=1.
    // CurveTween applied manually for smooth fade without extra allocations.
    final opacity = (Curves.easeOut.transform(1.0 - t) * 0.55).clamp(0.0, 1.0);

    return Transform.scale(
      scale: scale,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // Soft blur-based glow — two layered shadows give depth.
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: opacity * 0.6),
              blurRadius: 28,
              spreadRadius: 6,
            ),
            BoxShadow(
              color: color.withValues(alpha: opacity * 0.3),
              blurRadius: 56,
              spreadRadius: 14,
            ),
          ],
          border: Border.all(
            color: color.withValues(alpha: opacity),
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

// ── Location Picker Bottom Sheet ───────────────────────────────────────────────

class _LocationPickerSheet extends StatefulWidget {
  final UserProvider userProvider;
  const _LocationPickerSheet({required this.userProvider});

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  late TextEditingController _cityCtrl;
  late TextEditingController _countryCtrl;
  bool _loading = false;
  String? _error;
  bool _showSettingsLink = false;
  // Tracks coords obtained from the GPS button in this session
  double? _gpsLat;
  double? _gpsLng;

  @override
  void initState() {
    super.initState();
    _cityCtrl = TextEditingController(text: widget.userProvider.city ?? '');
    _countryCtrl =
        TextEditingController(text: widget.userProvider.country ?? '');
    // If user edits text manually, drop any GPS coords we got this session
    _cityCtrl.addListener(_onTextEdited);
    _countryCtrl.addListener(_onTextEdited);
  }

  void _onTextEdited() {
    if (_gpsLat != null) {
      setState(() {
        _gpsLat = null;
        _gpsLng = null;
      });
    }
  }

  @override
  void dispose() {
    _cityCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  Future<void> _useGPS() async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    setState(() {
      _loading = true;
      _error = null;
      _showSettingsLink = false;
    });
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        setState(() {
          _showSettingsLink = true;
        });
        throw Exception(lp.getText('location_perm_denied_forever'));
      }
      if (perm == LocationPermission.denied) {
        throw Exception(lp.getText('location_perm_denied'));
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 12),
        ),
      );

      final placemarks =
          await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final city = p.locality?.isNotEmpty == true
            ? p.locality!
            : (p.administrativeArea ?? '');
        final country = p.country ?? '';
        setState(() {
          _cityCtrl.text = city;
          _countryCtrl.text = country;
          _gpsLat = pos.latitude;
          _gpsLng = pos.longitude;
        });
      } else {
        throw Exception(lp.getText('location_city_not_found'));
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final nav = Navigator.of(context);
    final city = _cityCtrl.text.trim();
    final country = _countryCtrl.text.trim();

    if (city.isEmpty) {
      setState(() => _error = lp.getText('error_enter_city'));
      return;
    }

    if (_gpsLat != null && _gpsLng != null) {
      // GPS was used — save exact coordinates so prayer times is instant
      await widget.userProvider.setCoordinates(_gpsLat!, _gpsLng!);
    } else {
      // Manual entry — clear saved coordinates so prayer times re-geocodes
      await widget.userProvider.clearCoordinates();
    }
    await widget.userProvider.setLocation(city, country);
    if (mounted) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final lp = Provider.of<LanguageProvider>(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgTeal,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding:
                EdgeInsets.fromLTRB(R.px(20), R.px(12), R.px(20), R.px(24)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Handle ────────────────────────────────────────────────────
                Center(
                  child: Container(
                    width: R.px(40),
                    height: R.px(4),
                    decoration: BoxDecoration(
                        color: AppColors.ink(0.24),
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                SizedBox(height: R.px(20)),

                // ── Title ─────────────────────────────────────────────────────
                Row(children: [
                  Container(
                    padding: EdgeInsets.all(R.px(8)),
                    decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(R.px(10))),
                    child: Icon(Icons.location_on,
                        color: AppColors.primary, size: R.sp(18)),
                  ),
                  SizedBox(width: R.px(12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lp.getText('set_location'),
                            style: AppText.heading(R.adaptive(16, 18, 22))),
                        Text(lp.getText('location_for_prayer'),
                            style: AppText.body(color: AppColors.textSlate500)
                                .copyWith(fontSize: R.sp(11))),
                      ],
                    ),
                  ),
                ]),

                SizedBox(height: R.px(24)),

                // ── GPS Button ────────────────────────────────────────────────
                GestureDetector(
                  onTap: _loading ? null : _useGPS,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: R.px(14)),
                    decoration: BoxDecoration(
                      gradient: _loading
                          ? null
                          : const LinearGradient(
                              colors: [Color(0xFFF97316), Color(0xFFEA580C)]),
                      color: _loading ? AppColors.ink(0.05) : null,
                      borderRadius: BorderRadius.circular(R.px(14)),
                      border: _loading
                          ? Border.all(color: AppColors.ink(0.12))
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_loading)
                          SizedBox(
                            width: R.sp(16),
                            height: R.sp(16),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.primary),
                          )
                        else
                          Icon(Icons.my_location,
                              color: Colors.white, size: R.sp(17)),
                        SizedBox(width: R.px(8)),
                        Text(
                          _loading
                              ? lp.getText('detecting_location')
                              : lp.getText('use_gps_location'),
                          style: AppText.manrope(
                              fontSize: R.sp(13),
                              fontWeight: FontWeight.w700,
                              color: _loading ? AppColors.textSlate400 : Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: R.px(20)),

                // ── Divider ───────────────────────────────────────────────────
                Row(children: [
                  Expanded(child: Divider(color: AppColors.ink(0.08))),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: R.px(12)),
                    child: Text(lp.getText('or_enter_manually'),
                        style: AppText.label(color: AppColors.textSlate500)
                            .copyWith(fontSize: R.sp(9))),
                  ),
                  Expanded(child: Divider(color: AppColors.ink(0.08))),
                ]),

                SizedBox(height: R.px(20)),

                // ── City field ────────────────────────────────────────────────
                _Field(
                  controller: _cityCtrl,
                  label: lp.getText('city'),
                  hint: lp.getText('city_hint'),
                  icon: Icons.location_city,
                ),
                SizedBox(height: R.px(12)),

                // ── Country field ─────────────────────────────────────────────
                _Field(
                  controller: _countryCtrl,
                  label: lp.getText('country'),
                  hint: lp.getText('country_hint'),
                  icon: Icons.flag_outlined,
                ),

                // ── GPS coords indicator ──────────────────────────────────────
                if (_gpsLat != null) ...[
                  SizedBox(height: R.px(10)),
                  Row(children: [
                    Icon(Icons.check_circle,
                        color: const Color(0xFF10B981), size: R.sp(13)),
                    SizedBox(width: R.px(6)),
                    Text(lp.getText('gps_coords_saved'),
                        style: AppText.body(color: const Color(0xFF10B981))
                            .copyWith(fontSize: R.sp(11))),
                  ]),
                ],

                // ── Error ─────────────────────────────────────────────────────
                if (_error != null) ...[
                  SizedBox(height: R.px(10)),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.error_outline,
                        color: Colors.redAccent, size: R.sp(14)),
                    SizedBox(width: R.px(6)),
                    Flexible(
                      child: Text(_error!,
                          style: AppText.body(color: Colors.redAccent)
                              .copyWith(fontSize: R.sp(11))),
                    ),
                  ]),
                  if (_showSettingsLink)
                    TextButton(
                      onPressed: () => Geolocator.openAppSettings(),
                      child: Text(lp.getText('open_settings'),
                          style: AppText.body(color: AppColors.primary)
                              .copyWith(fontSize: R.sp(12))),
                    ),
                ],

                SizedBox(height: R.px(24)),

                // ── Save Button ───────────────────────────────────────────────
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: R.px(14)),
                        decoration: BoxDecoration(
                          color: AppColors.ink(0.06),
                          borderRadius: BorderRadius.circular(R.px(14)),
                          border: Border.all(color: AppColors.ink(0.12)),
                        ),
                        child: Center(
                          child: Text(lp.getText('cancel'),
                              style: AppText.manrope(
                                  fontSize: R.sp(13),
                                  color: AppColors.textSlate400)),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: R.px(12)),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: _loading ? null : _save,
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: R.px(14)),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFFF97316), Color(0xFFEA580C)]),
                          borderRadius: BorderRadius.circular(R.px(14)),
                          boxShadow: [
                            BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 12)
                          ],
                        ),
                        child: Center(
                          child: Text(lp.getText('save_location'),
                              style: AppText.manrope(
                                  fontSize: R.sp(13),
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Reusable input field ───────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: AppText.label(color: AppColors.textSlate500)
                .copyWith(fontSize: R.sp(9))),
        SizedBox(height: R.px(6)),
        TextField(
          controller: controller,
          style: AppText.manrope(fontSize: R.sp(14)),
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppText.body(color: AppColors.textSlate500)
                .copyWith(fontSize: R.sp(13)),
            prefixIcon:
                Icon(icon, color: AppColors.textSlate500, size: R.sp(17)),
            filled: true,
            fillColor: AppColors.ink(0.05),
            contentPadding:
                EdgeInsets.symmetric(horizontal: R.px(16), vertical: R.px(14)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(R.px(12)),
              borderSide: BorderSide(color: AppColors.ink(0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(R.px(12)),
              borderSide: BorderSide(color: AppColors.ink(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(R.px(12)),
              borderSide: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.6), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Inline widgets ─────────────────────────────────────────────────────────────

class _Tab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: R.px(16), vertical: R.px(8)),
        decoration: BoxDecoration(
          color: isActive ? AppColors.ink(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(R.px(20)),
        ),
        child: Text(label,
            style: AppText.manrope(
              fontSize: R.adaptive(12, 13, 15),
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color:
                  isActive ? AppColors.textPrimary : AppColors.textSlate400,
            )),
      ),
    );
  }
}

// ── Location setup banner ──────────────────────────────────────────────────────
// Shown at the very top of the home screen when hasSavedCoordinates is false.
// Completely absent from the widget tree (no space) when the condition is true.

class _LocationBanner extends StatelessWidget {
  final VoidCallback onSetNow;
  const _LocationBanner({required this.onSetNow});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: R.px(12)),
      padding: EdgeInsets.symmetric(horizontal: R.px(14), vertical: R.px(10)),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(R.px(12)),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.location_off_outlined,
              color: AppColors.primary, size: R.sp(18)),
          SizedBox(width: R.px(10)),
          Expanded(
            child: Text(
              'Set your location for prayer times',
              style: AppText.manrope(
                  fontSize: R.adaptive(11, 12, 14),
                  color: AppColors.textSlate300),
            ),
          ),
          SizedBox(width: R.px(8)),
          GestureDetector(
            onTap: onSetNow,
            child: Container(
              padding:
                  EdgeInsets.symmetric(horizontal: R.px(12), vertical: R.px(6)),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(R.px(8)),
              ),
              child: Text(
                'Set Now',
                style: AppText.manrope(
                    fontSize: R.adaptive(10, 11, 13),
                    fontWeight: FontWeight.w700,
                    color: AppColors.onPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isHealthy;
  const _CategoryCard({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isHealthy = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: R.px(16)),
        decoration:
            AppDeco.glassCard(borderRadius: BorderRadius.circular(R.px(20))),
        child: Column(children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(icon, color: AppColors.primary, size: R.sp(26)),
              if (isHealthy)
                Positioned(
                  top: -2,
                  right: -6,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: R.px(8)),
          Text(label,
              style: AppText.manrope(
                  fontSize: R.adaptive(12, 14, 16),
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _ReminderWarningCard extends StatelessWidget {
  final VoidCallback onTap;
  const _ReminderWarningCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isBn = Localizations.localeOf(context).languageCode == 'bn';
    const warningAmber = Color(0xFFF59E0B);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: R.px(14), horizontal: R.px(8)),
        decoration: BoxDecoration(
          color: warningAmber.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(R.px(20)),
          border: Border.all(
            color: warningAmber.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: warningAmber.withValues(alpha: 0.18),
              blurRadius: 14,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.notifications_active_outlined,
                  color: warningAmber,
                  size: R.sp(26),
                ),
                Positioned(
                  top: -2,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.priority_high_rounded,
                      color: Colors.white,
                      size: 9,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: R.px(6)),
            Text(
              isBn ? 'সেটআপ প্রয়োজন' : 'Setup Required',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.manrope(
                fontSize: R.adaptive(12, 13, 14),
                fontWeight: FontWeight.w800,
                color: warningAmber,
              ),
            ),
            SizedBox(height: R.px(2)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: warningAmber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                isBn ? '⚠️ আজান ঠিক করুন' : '⚠️ Fix Reminders',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: R.adaptive(9, 10, 11),
                  fontWeight: FontWeight.w600,
                  color: warningAmber,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
