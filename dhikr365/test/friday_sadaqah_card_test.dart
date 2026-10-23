import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
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
    GoogleFonts.config.allowRuntimeFetching = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('home_widget'),
      (MethodCall methodCall) async => true,
    );
  });

  group('FridaySadaqahCard Theme Adaptability Tests', () {
    testWidgets('Renders with high-contrast text and dynamically adapts across Light and Dark themes', (tester) async {
      SharedPreferences.setMockInitialValues({
        'app_palette': AppPalettes.royalWhite.id,
      });

      final themeProvider = ThemeProvider();
      await themeProvider.initialized;
      final userProvider = UserProvider();
      await userProvider.loadFuture;
      final langProvider = LanguageProvider();
      await langProvider.loadFuture;
      final purchaseProvider = PurchaseProvider(autoInit: false);

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
      await tester.pump(const Duration(milliseconds: 600));

      final isFriday = DateTime.now().weekday == DateTime.friday;
      if (isFriday) {
        // ── PHASE 1: Royal White (Light Theme) ──
        final titleFinder = find.text('Friday Sadaqah Barakah');
        expect(titleFinder, findsOneWidget);

        final lightTitle = tester.widget<Text>(titleFinder);
        expect(lightTitle.style?.color, equals(AppPalettes.royalWhite.textPrimary));

        final btnTextFinder = find.text('Give Sadaqah Jariyah ➔');
        expect(btnTextFinder, findsOneWidget);

        final lightBtnText = tester.widget<Text>(btnTextFinder);
        expect(lightBtnText.style?.color, equals(AppPalettes.royalWhite.onPrimary));

        // ── PHASE 2: Dynamic Switch to Emerald Night (Dark Theme) ──
        await themeProvider.setPalette(AppPalettes.emeraldNight.id);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        final darkTitle = tester.widget<Text>(titleFinder);
        expect(darkTitle.style?.color, equals(AppPalettes.emeraldNight.textPrimary));

        final darkBtnText = tester.widget<Text>(btnTextFinder);
        expect(darkBtnText.style?.color, equals(AppPalettes.emeraldNight.onPrimary));
      }
    });
  });
}
