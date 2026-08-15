import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dhikr.dart';
import '../providers/dhikr_provider.dart';
import '../providers/language_provider.dart';
import '../providers/user_provider.dart';
import '../constants/app_theme.dart';
import '../services/notification_service.dart';
import 'dashboard_screen.dart';
import 'dhikr_list_screen.dart';
import 'language_selection_screen.dart';
import 'onboarding_screen.dart';
import '../providers/notification_provider.dart';
import '../widgets/battery_reliability_dialogs.dart';
import 'location_setup_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback so the widget is fully mounted before we call
    // Navigator.of(context) and Provider.of(context) — avoids a black screen
    // crash in release mode when context isn't ready yet in initState.
    WidgetsBinding.instance.addPostFrameCallback((_) => _navigate());
  }

  Future<void> _navigate() async {
    // Capture navigator and providers before any await to avoid using
    // BuildContext across async gaps.
    final nav = Navigator.of(context);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final notificationProvider =
        Provider.of<NotificationProvider>(context, listen: false);
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    final dhikrProvider = Provider.of<DhikrProvider>(context, listen: false);

    // Step 1 — Wait for providers to finish loading their state from storage.
    // Timeout so a storage failure never hangs the splash forever.
    await userProvider.loadFuture
        .timeout(const Duration(seconds: 5), onTimeout: () {});
    await notificationProvider.loadFuture
        .timeout(const Duration(seconds: 5), onTimeout: () {});
    await languageProvider.loadFuture
        .timeout(const Duration(seconds: 5), onTimeout: () {});

    // Step 1b — DhikrProvider's constructor always loads its FIRST batch of
    // dua content in English (a hardcoded default, since it can't await
    // LanguageProvider from its own constructor). Every cold start therefore
    // showed English dua text/translation/transliteration for one frame —
    // and on devices where the OS kills the process in the background, the
    // user would see it revert to English every time the app reopens or
    // resumes from being swiped away, even though their language/translation/
    // transliteration CHOICE was correctly saved and reloaded above. Re-sync
    // the dua content to the just-loaded saved language now, once, up front.
    if (languageProvider.locale.languageCode != 'en' ||
        languageProvider.translationCode != 'en' ||
        languageProvider.transliterationCode != 'en') {
      try {
        await dhikrProvider.reloadDhikrs(
          uiLanguageCode: languageProvider.locale.languageCode,
          transliterationCode: languageProvider.transliterationCode,
          translationCode: languageProvider.translationCode,
        );
      } catch (e) {
        debugPrint('[Splash] dua content language re-sync failed: $e');
      }
    }

    // Step 2 — Request permissions FIRST.
    await NotificationService().requestPermissions();

    // Step 3 — Wait for the splash animation.
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;

    // Step 3b — If exact alarm permission was not granted, show a clear dialog.
    // Without it every notification falls back to inexact mode which is silently
    // dropped by Samsung/Xiaomi/OPPO battery managers — "not working at all".
    final exactGranted = await NotificationService().isExactAlarmGranted();
    if (!exactGranted && mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.bgTeal,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Icon(Icons.alarm_on, color: AppColors.primary, size: 22),
            const SizedBox(width: 10),
            Text('Enable Precise Alarms',
                style: AppText.heading(16)),
          ]),
          content: Text(
            'For prayer time notifications to arrive at the exact correct '
            'moment, please enable "Alarms & Reminders" on the next screen '
            'and tap Allow.\n\n'
            'Without this, notifications may be delayed or never arrive.',
            style: AppText.body(color: AppColors.textSlate300)
                .copyWith(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Later',
                  style: AppText.body(color: AppColors.textSlate500)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () {
                Navigator.pop(ctx);
                // Fires the system Settings intent and returns immediately.
                // Do NOT reschedule here — the app's resume handler
                // (main.dart) detects the permission change when the user
                // comes back and reschedules everything in exact mode.
                // Rescheduling here raced the step-3c refresh below and
                // could wipe pending notifications.
                NotificationService().openExactAlarmSettings();
              },
              child: Text('Open Settings',
                  style: AppText.manrope(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    }

    if (!mounted) return;

    // Step 3b-2 — Battery-optimization + OEM Autostart explainers, shown
    // automatically ONLY ONCE ever (never nags on later launches — after
    // this, it's reachable any time via Settings → Notification Reliability
    // Tips). Each dialog explains itself in plain language before the real
    // system/OEM settings screen opens, matching the flow top prayer apps
    // (Muslim Pro, Athan) use instead of a raw unexplained popup.
    final reliabilityPrefs = await SharedPreferences.getInstance();
    if (!(reliabilityPrefs.getBool('battery_tips_shown') ?? false)) {
      await reliabilityPrefs.setBool('battery_tips_shown', true);
      if (mounted) await showBatteryExplainerDialog(context);
      if (mounted) await showAutostartTipDialog(context);
    }

    if (!mounted) return;

    // Step 3c — Schedule notifications NOW that permissions are confirmed.
    try {
      await notificationProvider.refreshAllSchedules(userProvider);
    } catch (e) {
      debugPrint('[Splash] refreshAllSchedules failed: $e');
    }

    // Step 4 — Check if language has been selected before.
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('language_code')) {
      nav.pushReplacement(
        MaterialPageRoute(builder: (_) => const LanguageSelectionScreen()),
      );
      return;
    }

    // Step 5 — Check if onboarding has been completed.
    if (!userProvider.hasCompletedOnboarding) {
      nav.pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
      return;
    }

    // Step 6 — Check if location has been set.
    if (!userProvider.hasSavedCoordinates) {
      nav.pushReplacement(
        MaterialPageRoute(builder: (_) => const LocationSetupScreen()),
      );
      return;
    }

    // Step 7 — Check if the app was cold-started by a notification tap.
    // If so, we go to Dashboard first, then push the target screen on top
    // so the back button returns to Dashboard naturally.
    final launchPayload = await NotificationService().getLaunchPayload();

    // Step 8 — Navigate to Dashboard.
    nav.pushReplacement(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );

    // Step 9 — If launched from a notification, push the target screen.
    if (launchPayload != null && launchPayload.isNotEmpty) {
      // Small delay so Dashboard finishes building before we push on top.
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      if (launchPayload == 'morning' || launchPayload == 'prayer:sunrise') {
        nav.push(MaterialPageRoute(
          builder: (_) => const DhikrListScreen(category: DhikrCategory.morning),
        ));
      } else if (launchPayload == 'evening' || launchPayload == 'prayer:maghrib') {
        nav.push(MaterialPageRoute(
          builder: (_) => const DhikrListScreen(category: DhikrCategory.evening),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // listen: true so build() re-runs when LanguageProvider finishes loading
    // the saved language from SharedPreferences after a cold start.
    final lp = Provider.of<LanguageProvider>(context);
    final greeting = lp.greeting;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.4,
            colors: [AppColors.bgTeal, AppColors.bgDark],
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                          width: 1.5),
                    ),
                    child: Icon(Icons.mosque,
                        size: 52, color: AppColors.primary),
                  )
                      .animate()
                      .fadeIn(duration: 600.ms)
                      .scale(begin: const Offset(0.8, 0.8), delay: 200.ms),
                  const SizedBox(height: 28),
                  Text(
                    greeting,
                    textAlign: TextAlign.center,
                    style: AppText.amiri(fontSize: 36),
                  ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),
                  const SizedBox(height: 8),
                  Text(lp.getText('app_title').toUpperCase(),
                          style: AppText.label(color: AppColors.primary))
                      .animate()
                      .fadeIn(delay: 700.ms),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 48),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary.withOpacity(0.6),
                  ),
                ).animate().fadeIn(delay: 1200.ms),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
