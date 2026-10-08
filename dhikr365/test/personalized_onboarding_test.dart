import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dhikr365/providers/user_provider.dart';
import 'package:dhikr365/providers/language_provider.dart';
import 'package:dhikr365/screens/onboarding_screen.dart';
import 'package:provider/provider.dart';
import 'package:dhikr365/providers/notification_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Personalized Onboarding UserProvider Persistence Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('1. Onboarding goal and preferred dhikr time default to null', () async {
      final up = UserProvider();
      await up.loadFuture;

      expect(up.onboardingGoal, isNull);
      expect(up.preferredDhikrTime, isNull);
    });

    test('2. setOnboardingGoal persists to SharedPreferences', () async {
      final up = UserProvider();
      await up.loadFuture;

      await up.setOnboardingGoal('peace');
      expect(up.onboardingGoal, equals('peace'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('onboarding_goal'), equals('peace'));
    });

    test('3. setPreferredDhikrTime persists to SharedPreferences', () async {
      final up = UserProvider();
      await up.loadFuture;

      await up.setPreferredDhikrTime('sleep');
      expect(up.preferredDhikrTime, equals('sleep'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('preferred_dhikr_time'), equals('sleep'));
    });

    test('4. Reloading UserProvider restores persisted quiz answers', () async {
      SharedPreferences.setMockInitialValues({
        'onboarding_goal': 'habit',
        'preferred_dhikr_time': 'fajr',
      });

      final up = UserProvider();
      await up.loadFuture;

      expect(up.onboardingGoal, equals('habit'));
      expect(up.preferredDhikrTime, equals('fajr'));
    });
  });

  group('Localization Keys Verification', () {
    test('5. All requested onboarding keys exist in en.json and bn.json', () {
      final enRaw = File('assets/i18n/en.json').readAsStringSync();
      final bnRaw = File('assets/i18n/bn.json').readAsStringSync();

      final enMap = jsonDecode(enRaw) as Map<String, dynamic>;
      final bnMap = jsonDecode(bnRaw) as Map<String, dynamic>;

      const requiredKeys = [
        'onb_goal_title',
        'onb_goal_protection',
        'onb_goal_habit',
        'onb_goal_peace',
        'onb_goal_sunnah',
        'onb_time_title',
        'onb_time_fajr',
        'onb_time_asr',
        'onb_time_sleep',
        'onb_time_anytime',
        'onb_welcome',
        'onb_begin',
      ];

      for (final key in requiredKeys) {
        expect(enMap.containsKey(key), isTrue, reason: 'Missing $key in en.json');
        expect(bnMap.containsKey(key), isTrue, reason: 'Missing $key in bn.json');
        expect((enMap[key] as String).isNotEmpty, isTrue);
        expect((bnMap[key] as String).isNotEmpty, isTrue);
      }
    });
  });

  group('OnboardingScreen Widget Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('6. OnboardingScreen renders step 1 and skip jumps to step 4',
        (tester) async {
      final userProvider = UserProvider();
      final languageProvider = LanguageProvider();
      await languageProvider.loadFuture;
      final notificationProvider = NotificationProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<UserProvider>.value(value: userProvider),
            ChangeNotifierProvider<LanguageProvider>.value(value: languageProvider),
            ChangeNotifierProvider<NotificationProvider>.value(
                value: notificationProvider),
          ],
          child: const MaterialApp(
            home: OnboardingScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check language selection items are visible
      expect(find.text('English'), findsWidgets);
      expect(find.text('العربية'), findsWidgets);
      expect(find.text('বাংলা'), findsWidgets);

      // Check skip button is present on step 1
      final skipFinder = find.text(languageProvider.getText('skip'));
      expect(skipFinder, findsOneWidget);

      // Tap Skip and verify jump to Step 4
      await tester.tap(skipFinder);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mosque_rounded), findsOneWidget);
      expect(find.text('Step 4 of 5'), findsOneWidget);
    });
  });
}
