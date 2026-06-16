// ============================================================================
// lib/main.dart — Adhkaar 365
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import 'constants/app_theme.dart';
import 'providers/custom_plan_provider.dart';
import 'providers/dhikr_provider.dart';
import 'providers/language_provider.dart';
import 'providers/notification_provider.dart';
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

  // 3. Initialize the full notification system
  //    (local channels + timezone db)
  //    Wrapped in try-catch: a timezone lookup failure must never crash the app
  //    before runApp() — that causes a permanent black screen.
  try {
    await NotificationService().init();
  } catch (e) {
    debugPrint('[main] NotificationService init failed: $e');
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

  /// Stop audio when the user backgrounds the app so it doesn't keep playing.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      AudioService().stop();
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
        ChangeNotifierProvider(create: (_) => CustomPlanProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
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
              // Used when the user toggles dark mode OFF in Settings.
              // Keeps the Islamic aesthetic (teal + amber) on a light background.
              theme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.light,
                colorScheme: const ColorScheme.light(
                  primary: AppColors.primary,
                  surface: Color(0xFFF0F4F4),
                  onSurface: Color(0xFF1A2E2E),
                ),
                scaffoldBackgroundColor: const Color(0xFFF0F4F4),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Color(0xFFE0ECEC),
                  foregroundColor: Color(0xFF1A2E2E),
                  elevation: 0,
                ),
                cardColor: const Color(0xFFE4EFEF),
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
              darkTheme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.dark,
                colorScheme: const ColorScheme.dark(
                  primary: AppColors.primary,
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
