// ============================================================================
// test/text_scale_overflow_test.dart
//
// Widget tests verifying that main screens render cleanly without RenderFlex
// overflows on a small phone screen (360x640) at textScaleFactor 1.0 and 1.5.
//
// Main screens tested:
// 1. OnboardingScreen
// 2. HomeScreen
// 3. DhikrListScreen (Morning category)
// 4. DhikrFocusScreen (Tasbih / Focus counter)
// 5. SettingsScreen
// 6. DonationScreen
// 7. PrayerTimesScreen
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dhikr365/constants/app_theme.dart';
import 'package:dhikr365/models/dhikr.dart';
import 'package:dhikr365/providers/auth_provider.dart';
import 'package:dhikr365/providers/custom_plan_provider.dart';
import 'package:dhikr365/providers/dhikr_provider.dart';
import 'package:dhikr365/providers/language_provider.dart';
import 'package:dhikr365/providers/notification_provider.dart';
import 'package:dhikr365/providers/purchase_provider.dart';
import 'package:dhikr365/providers/theme_provider.dart';
import 'package:dhikr365/providers/user_provider.dart';
import 'package:dhikr365/screens/dhikr_focus_screen.dart';
import 'package:dhikr365/screens/dhikr_list_screen.dart';
import 'package:dhikr365/screens/donation_screen.dart';
import 'package:dhikr365/screens/dua_screen.dart';
import 'package:dhikr365/screens/home_screen.dart';
import 'package:dhikr365/screens/onboarding_screen.dart';
import 'package:dhikr365/screens/prayer_times_screen.dart';
import 'package:dhikr365/screens/settings_screen.dart';
import 'package:dhikr365/utils/responsive.dart';

final Dhikr _sampleDhikr = Dhikr(
  id: 'subhanallah_bihamdihi',
  title: 'SubhanAllahi wa bihamdihi',
  arabicText: 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
  translation: 'Glory be to Allah and His is the praise. A hundred times daily.',
  transliteration: 'SubhanAllahi wa bihamdihi',
  benefit: 'Whoever recites this 100 times in the morning and evening, their sins will be wiped away.',
  reference: 'Sahih al-Bukhari 6405',
  targetCount: 100,
  category: DhikrCategory.morning,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('home_widget'), (_) async => true);
    messenger.setMockMethodCallHandler(const MethodChannel('xyz.luan/audioplayers'), (_) async => true);
    messenger.setMockMethodCallHandler(const MethodChannel('xyz.luan/audioplayers.global'), (_) async => true);
    messenger.setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/wakelock_plus'), (_) async => true);
    messenger.setMockMethodCallHandler(const MethodChannel('flutter.baseflow.com/geolocator'), (methodCall) async {
      if (methodCall.method == 'checkPermission') return 3; // whileInUse
      if (methodCall.method == 'requestPermission') return 3;
      if (methodCall.method == 'isLocationServiceEnabled') return true;
      if (methodCall.method == 'getCurrentPosition' || methodCall.method == 'getLastKnownPosition') {
        return {
          'latitude': 23.8103,
          'longitude': 90.4125,
          'timestamp': 0,
          'accuracy': 100.0,
          'altitude': 0.0,
          'heading': 0.0,
          'speed': 0.0,
          'speed_accuracy': 0.0,
        };
      }
      return null;
    });
    messenger.setMockMethodCallHandler(const MethodChannel('flutter.baseflow.com/geocoding'), (_) async => [
          {
            'name': 'Dhaka',
            'street': '',
            'isoCountryCode': 'BD',
            'country': 'Bangladesh',
            'postalCode': '',
            'administrativeArea': 'Dhaka',
            'subAdministrativeArea': '',
            'locality': 'Dhaka',
            'subLocality': '',
            'thoroughfare': '',
            'subThoroughfare': '',
          }
        ]);
    messenger.setMockMethodCallHandler(const MethodChannel('dexterous.com/flutter/local_notifications'), (_) async => true);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'user_city': 'Dhaka',
      'user_lat': 23.8103,
      'user_lng': 90.4125,
      'user_name': 'Test User',
      'selected_palette_id': AppPalettes.emeraldNight.id,
    });
  });

  Widget createHarness({
    required Widget child,
    required double textScale,
    required Size viewportSize,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PurchaseProvider()),
        ChangeNotifierProvider(create: (_) => DhikrProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => CustomPlanProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (context, _) => MaterialApp(
          home: Builder(
            builder: (ctx) {
              R.init(ctx);
              return MediaQuery(
                data: MediaQueryData(
                  size: viewportSize,
                  textScaler: TextScaler.linear(textScale),
                ),
                child: child,
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> runOverflowTest({
    required WidgetTester tester,
    required Widget screen,
    required double textScale,
    String? screenName,
  }) async {
    const smallScreenSize = Size(360, 640);
    tester.view.physicalSize = smallScreenSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final overflowErrors = <FlutterErrorDetails>[];
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed') || details.toString().contains('RenderFlex overflowed')) {
        overflowErrors.add(details);
      }
      originalOnError?.call(details);
    };

    try {
      await tester.pumpWidget(
        createHarness(
          child: screen,
          textScale: textScale,
          viewportSize: smallScreenSize,
        ),
      );

      // Allow animations and async initializations to settle
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        overflowErrors,
        isEmpty,
        reason: 'RenderFlex overflow in $screenName at textScale $textScale: ${overflowErrors.map((e) => e.exception).toList()}',
      );
    } finally {
      FlutterError.onError = originalOnError;
    }
  }

  const scales = [1.0, 1.5];

  for (final scale in scales) {
    group('Screen Overflow Tests (360x640, textScale: $scale)', () {
      testWidgets('1. OnboardingScreen', (tester) async {
        await runOverflowTest(
          tester: tester,
          screen: const OnboardingScreen(),
          textScale: scale,
          screenName: 'OnboardingScreen',
        );
      });

      testWidgets('2. HomeScreen', (tester) async {
        await runOverflowTest(
          tester: tester,
          screen: const HomeScreen(),
          textScale: scale,
          screenName: 'HomeScreen',
        );
      });

      testWidgets('3. DhikrListScreen (Morning)', (tester) async {
        await runOverflowTest(
          tester: tester,
          screen: const DhikrListScreen(category: DhikrCategory.morning),
          textScale: scale,
          screenName: 'DhikrListScreen',
        );
      });

      testWidgets('4. DhikrFocusScreen (Tasbih/Focus)', (tester) async {
        await runOverflowTest(
          tester: tester,
          screen: DhikrFocusScreen(dhikr: _sampleDhikr),
          textScale: scale,
          screenName: 'DhikrFocusScreen',
        );
      });

      testWidgets('5. SettingsScreen', (tester) async {
        await runOverflowTest(
          tester: tester,
          screen: const SettingsScreen(),
          textScale: scale,
          screenName: 'SettingsScreen',
        );
      });

      testWidgets('6. DonationScreen', (tester) async {
        await runOverflowTest(
          tester: tester,
          screen: const DonationScreen(),
          textScale: scale,
          screenName: 'DonationScreen',
        );
      });

      testWidgets('7. PrayerTimesScreen', (tester) async {
        await runOverflowTest(
          tester: tester,
          screen: const PrayerTimesScreen(),
          textScale: scale,
          screenName: 'PrayerTimesScreen',
        );
      });

      testWidgets('8. DuaScreen', (tester) async {
        await runOverflowTest(
          tester: tester,
          screen: const DuaScreen(),
          textScale: scale,
          screenName: 'DuaScreen',
        );
      });
    });
  }
}
