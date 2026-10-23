import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dhikr365/providers/language_provider.dart';
import 'package:dhikr365/providers/theme_provider.dart';
import 'package:dhikr365/providers/user_provider.dart';
import 'package:dhikr365/widgets/font_size_sheet.dart';
import 'package:dhikr365/utils/responsive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('UserProvider Font Size Customization Tests', () {
    test('Default values are correct (Arabic: 26.0, Translation: 14.5)', () async {
      final up = UserProvider();
      await up.loadFuture;
      expect(up.arabicFontSize, equals(UserProvider.defaultArabicFontSize));
      expect(up.translationFontSize, equals(UserProvider.defaultTranslationFontSize));
      expect(up.arabicFontScale, closeTo(1.0, 0.001));
      expect(up.translationFontScale, closeTo(1.0, 0.001));
      expect(up.isDefaultFontSize, isTrue);
    });

    test('setArabicFontSize updates value and scale within clamped limits', () async {
      final up = UserProvider();
      await up.loadFuture;
      await up.setArabicFontSize(32.0);
      expect(up.arabicFontSize, equals(32.0));
      expect(up.arabicFontScale, closeTo(32.0 / 26.0, 0.001));
      expect(up.isDefaultFontSize, isFalse);

      // Clamping test - above max
      await up.setArabicFontSize(50.0);
      expect(up.arabicFontSize, equals(UserProvider.maxArabicFontSize));

      // Clamping test - below min
      await up.setArabicFontSize(10.0);
      expect(up.arabicFontSize, equals(UserProvider.minArabicFontSize));
    });

    test('setTranslationFontSize updates value within clamped limits', () async {
      final up = UserProvider();
      await up.loadFuture;
      await up.setTranslationFontSize(18.0);
      expect(up.translationFontSize, equals(18.0));
      expect(up.translationFontScale, closeTo(18.0 / 14.5, 0.001));
      expect(up.isDefaultFontSize, isFalse);

      // Clamping test - above max
      await up.setTranslationFontSize(30.0);
      expect(up.translationFontSize, equals(UserProvider.maxTranslationFontSize));

      // Clamping test - below min
      await up.setTranslationFontSize(5.0);
      expect(up.translationFontSize, equals(UserProvider.minTranslationFontSize));
    });

    test('resetFontSizes returns all values to defaults', () async {
      final up = UserProvider();
      await up.loadFuture;
      await up.setFontSizes(arabicSize: 34.0, translationSize: 18.0);
      expect(up.isDefaultFontSize, isFalse);

      await up.resetFontSizes();
      expect(up.arabicFontSize, equals(UserProvider.defaultArabicFontSize));
      expect(up.translationFontSize, equals(UserProvider.defaultTranslationFontSize));
      expect(up.isDefaultFontSize, isTrue);
    });
  });

  group('FontSizeSheet Widget Tests', () {
    testWidgets('FontSizeSheet renders preview and controls properly', (tester) async {
      final userProvider = UserProvider();
      final langProvider = LanguageProvider();
      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: userProvider),
            ChangeNotifierProvider.value(value: langProvider),
            ChangeNotifierProvider.value(value: themeProvider),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                R.init(context);
                return const Scaffold(
                  body: FontSizeSheet(),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check preview text is rendered
      expect(find.text('سُبْحَانَ اللَّهِ وَبِحَمْدِهِ'), findsOneWidget);

      // Check sliders are present
      expect(find.byType(Slider), findsNWidgets(2));

      // Check Done button
      expect(find.text('Done'), findsOneWidget);
    });
  });
}
