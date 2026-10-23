import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dhikr365/constants/app_theme.dart';
import 'package:dhikr365/providers/language_provider.dart';
import 'package:dhikr365/providers/purchase_provider.dart';
import 'package:dhikr365/providers/theme_provider.dart';
import 'package:dhikr365/providers/user_provider.dart';
import 'package:dhikr365/utils/responsive.dart';
import 'package:dhikr365/widgets/friday_sadaqah_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('home_widget'),
      (MethodCall methodCall) async => true,
    );
  });

  group('FridaySadaqahCard Theme Adaptability Tests', () {
    testWidgets('Renders with high-contrast text in Royal White (Light theme)', (tester) async {
      SharedPreferences.setMockInitialValues({
        'app_palette': AppPalettes.royalWhite.id,
      });

      final themeProvider = ThemeProvider();
      await themeProvider.initialized;
      final userProvider = UserProvider();
      await userProvider.loadFuture;
      final langProvider = LanguageProvider();
      final purchaseProvider = PurchaseProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: userProvider),
            ChangeNotifierProvider.value(value: langProvider),
            ChangeNotifierProvider.value(value: purchaseProvider),
            ChangeNotifierProvider.value(value: themeProvider),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                R.init(context);
                return const Scaffold(
                  body: SingleChildScrollView(
                    child: FridaySadaqahCard(),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final isFriday = DateTime.now().weekday == DateTime.friday;
      if (isFriday) {
        // Check title exists
        final titleFinder = find.text('Friday Sadaqah Barakah');
        expect(titleFinder, findsOneWidget);

        final titleWidget = tester.widget<Text>(titleFinder);
        // Title must use textPrimary (deep purple in royalWhite, NOT hardcoded white)
        expect(titleWidget.style?.color, equals(AppPalettes.royalWhite.textPrimary));

        // Check button exists
        final btnTextFinder = find.text('Give Sadaqah Jariyah ➔');
        expect(btnTextFinder, findsOneWidget);

        final btnTextWidget = tester.widget<Text>(btnTextFinder);
        // Button text must use onPrimary (pure white on royal purple button)
        expect(btnTextWidget.style?.color, equals(AppPalettes.royalWhite.onPrimary));
      }
    });

    testWidgets('Renders with high-contrast text in Emerald Night (Dark theme)', (tester) async {
      SharedPreferences.setMockInitialValues({
        'app_palette': AppPalettes.emeraldNight.id,
      });

      final themeProvider = ThemeProvider();
      await themeProvider.initialized;
      final userProvider = UserProvider();
      await userProvider.loadFuture;
      final langProvider = LanguageProvider();
      final purchaseProvider = PurchaseProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: userProvider),
            ChangeNotifierProvider.value(value: langProvider),
            ChangeNotifierProvider.value(value: purchaseProvider),
            ChangeNotifierProvider.value(value: themeProvider),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                R.init(context);
                return const Scaffold(
                  body: SingleChildScrollView(
                    child: FridaySadaqahCard(),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final isFriday = DateTime.now().weekday == DateTime.friday;
      if (isFriday) {
        final titleFinder = find.text('Friday Sadaqah Barakah');
        expect(titleFinder, findsOneWidget);

        final titleWidget = tester.widget<Text>(titleFinder);
        expect(titleWidget.style?.color, equals(AppPalettes.emeraldNight.textPrimary));
      }
    });
  });
}
