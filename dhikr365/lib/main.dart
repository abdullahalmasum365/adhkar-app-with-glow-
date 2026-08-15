// ============================================================================
// lib/main.dart — Adhkaar 365
// ============================================================================

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import 'constants/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/custom_plan_provider.dart';
import 'providers/dhikr_provider.dart';
import 'providers/language_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/purchase_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/user_provider.dart';
import 'screens/splash_screen.dart';
import 'services/audio_service.dart';
import 'services/notification_service.dart';
import 'utils/app_navigator.dart';
import 'utils/responsive.dart';

// ─────────────────────────────────────────────────────────────────────────────
// main()
// ─────────────────────────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Apply the user's saved color theme before the first frame so Royal
  // White users never see a dark flash on startup.
  await ThemeProvider.applySavedPalette();

  // 3. Initialize the full notification system
  //    (local channels + timezone db)
  //    Wrapped in try-catch: a timezone lookup failure must never crash the app
  //    before runApp() — that causes a permanent black screen.
  try {
    await NotificationService().init();
  } catch (e) {
    debugPrint('[main] NotificationService init failed: $e');
  }

  // 4. Initialize Firebase for account sign-in + cloud plan sync.
  //    Wrapped in try-catch: until the Firebase project is configured
  //    (google-services.json / GoogleService-Info.plist added), this throws
  //    — and the app must keep working fully offline exactly as before,
  //    not crash on a black screen. AuthService checks Firebase.apps before
  //    touching any Firebase API, so a failed init here just means the
  //    Account screen shows "not configured" and everything else is normal.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('[main] Firebase init skipped (not configured yet): $e');
  }

  runApp(const MyApp());
}

// ─────────────────────────────────────────────────────────────────────────────
// MyApp
// ─────────────────────────────────────────────────────────────────────────────
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AudioService().dispose();
    super.dispose();
  }

  /// Like every top audio app, recitation KEEPS PLAYING when the user
  /// switches apps or locks the screen — audio only stops when the app is
  /// actually closed (detached). On resume, re-check notification
  /// permissions and top up schedules — this is what makes an "Alarms &
  /// Reminders" grant from system Settings take effect without a restart.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      AudioService().stop();
    } else if (state == AppLifecycleState.resumed) {
      _refreshNotificationsOnResume();
    }
  }

  Future<void> _refreshNotificationsOnResume() async {
    // Providers live below this widget, so reach them through the navigator's
    // context. Null until the MaterialApp has built — nothing to refresh then.
    final ctx = appNavigatorKey.currentContext;
    if (ctx == null) return;
    try {
      final np = Provider.of<NotificationProvider>(ctx, listen: false);
      final up = Provider.of<UserProvider>(ctx, listen: false);
      await np.refreshIfNeeded(up);
    } catch (e) {
      debugPrint('[main] Notification refresh on resume failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DhikrProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        // Linked to AuthProvider: whenever the signed-in account changes,
        // the plan/favorites are merged with (and then kept in sync with)
        // that account's cloud copy. Untouched (stays local-only) for
        // users who never sign in.
        ChangeNotifierProxyProvider<AuthProvider, CustomPlanProvider>(
          create: (_) => CustomPlanProvider(),
          update: (_, auth, previous) {
            final plan = previous ?? CustomPlanProvider();
            plan.attachUser(auth.user?.uid);
            return plan;
          },
        ),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => PurchaseProvider()),
      ],
      child: Consumer2<ThemeProvider, LanguageProvider>(
        builder: (context, themeProvider, langProvider, child) {
          // ScreenUtilInit wraps the entire app.
          // designSize = iPhone 14 logical pixels (390 × 844).
          // All .sp / .w / .h / .r extensions scale from this baseline.
          return ScreenUtilInit(
            designSize: const Size(390, 844),
            minTextAdapt: true,
            splitScreenMode: true, // correct layout on tablets / foldables
            builder: (_, __) => MaterialApp(
              title: 'Adhkaar 365',
              debugShowCheckedModeBanner: false,
              navigatorKey: appNavigatorKey,
              themeMode: themeProvider.themeMode,
              // ── Light theme ────────────────────────────────────────────────
              // Built from the ACTIVE palette (Royal White / Rose Dawn /
              // Desert Mushaf) — only used when a light palette is selected,
              // so AppColors always matches.
              theme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.light,
                colorScheme: ColorScheme.light(
                  primary: AppColors.primary,
                  secondary: AppColors.accent,
                  surface: AppColors.bgDark,
                  onSurface: AppColors.textPrimary,
                ),
                scaffoldBackgroundColor: AppColors.bgDark,
                appBarTheme: AppBarTheme(
                  backgroundColor: AppColors.bgDeep,
                  foregroundColor: AppColors.textPrimary,
                  elevation: 0,
                ),
                cardColor: AppColors.bgTeal,
                switchTheme: SwitchThemeData(
                  thumbColor: WidgetStateProperty.resolveWith(
                    (s) => s.contains(WidgetState.selected)
                        ? Colors.white
                        : Colors.grey,
                  ),
                  trackColor: WidgetStateProperty.resolveWith(
                    (s) => s.contains(WidgetState.selected)
                        ? AppColors.primary
                        : Colors.black12,
                  ),
                ),
              ),
              locale: langProvider.locale,
              supportedLocales: LanguageProvider.supportedLanguages
                  .map((l) => Locale(l['code']!))
                  .toList(),
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
              ],
              // ── Dark theme ─────────────────────────────────────────────────
              // Built from the ACTIVE palette (Emerald Night / Sapphire Gold /
              // Midnight Black) — only used when a dark palette is selected.
              darkTheme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.dark,
                colorScheme: ColorScheme.dark(
                  primary: AppColors.primary,
                  secondary: AppColors.accent,
                  surface: AppColors.bgDark,
                ),
                scaffoldBackgroundColor: AppColors.bgDark,
                textTheme: ThemeData.dark().textTheme,
                switchTheme: SwitchThemeData(
                  thumbColor: WidgetStateProperty.resolveWith(
                    (s) => s.contains(WidgetState.selected)
                        ? Colors.white
                        : Colors.grey,
                  ),
                  trackColor: WidgetStateProperty.resolveWith(
                    (s) => s.contains(WidgetState.selected)
                        ? AppColors.primary
                        : Colors.white12,
                  ),
                ),
              ),
              // MediaQuery builder — caps system text scaling at 1.1×
              // so accessibility "Large Text" doesn't break the UI.
              builder: (context, child) {
                R.init(context); // initialise R.* responsive system
                return Directionality(
                  textDirection: langProvider.isRTL
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(
                        MediaQuery.of(context)
                            .textScaler
                            .scale(1.0)
                            .clamp(0.9, 1.1),
                      ),
                    ),
                    child: child!,
                  ),
                );
              },
              home: const SplashScreen(),
            ),
          );
        },
      ),
    );
  }
}
