import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dhikr365/models/dhikr.dart';
import 'package:dhikr365/constants/app_theme.dart';
import 'package:dhikr365/widgets/social_share_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleDhikr = Dhikr(
    id: 'test_dhikr_1',
    title: 'Morning Protection Dua',
    arabicText: 'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ',
    translation: 'We have entered the morning and kingdom belongs to Allah.',
    transliteration: 'Asbahna wa-asbahal mulku lillah',
    reference: 'Sahih Muslim 2723',
    targetCount: 1,
    category: DhikrCategory.morning,
  );

  group('SocialShareCard Widget Structure & Theme Rendering', () {
    testWidgets('1. SocialShareCard renders brand, Arabic, translation, reference, and watermark',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SocialShareCard(
              dhikr: sampleDhikr,
              palette: AppPalettes.emeraldNight,
              showTransliteration: true,
              showWatermark: true,
              categoryLabel: 'Morning Adhkar',
            ),
          ),
        ),
      );

      // Verify Brand header
      expect(find.text('ADHKAR 365'), findsOneWidget);
      expect(find.text('Daily Islamic Remembrance'), findsOneWidget);
      expect(find.text('MORNING ADHKAR'), findsOneWidget);

      // Verify Content
      expect(find.text('Morning Protection Dua'), findsOneWidget);
      expect(find.text('أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ'), findsOneWidget);
      expect(
          find.text('We have entered the morning and kingdom belongs to Allah.'),
          findsOneWidget);
      expect(find.text('Asbahna wa-asbahal mulku lillah'), findsOneWidget);
      expect(find.text('📖  Sahih Muslim 2723'), findsOneWidget);

      // Verify Watermark
      expect(find.text('adhkar365.app'), findsOneWidget);
    });

    testWidgets('2. Pro users can omit watermark and disable transliteration',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SocialShareCard(
              dhikr: sampleDhikr,
              palette: AppPalettes.royalWhite,
              showTransliteration: false,
              showWatermark: false,
            ),
          ),
        ),
      );

      // Watermark should not be displayed
      expect(find.text('adhkar365.app'), findsNothing);

      // Transliteration should not be displayed
      expect(find.text('Asbahna wa-asbahal mulku lillah'), findsNothing);

      // Arabic & Translation remain present
      expect(find.text('أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ'), findsOneWidget);
      expect(
          find.text('We have entered the morning and kingdom belongs to Allah.'),
          findsOneWidget);
    });
  });

  group('Localization Keys Verification', () {
    test('3. Social share card localization keys exist in en.json and bn.json', () {
      final enRaw = File('assets/i18n/en.json').readAsStringSync();
      final bnRaw = File('assets/i18n/bn.json').readAsStringSync();

      final enMap = jsonDecode(enRaw) as Map<String, dynamic>;
      final bnMap = jsonDecode(bnRaw) as Map<String, dynamic>;

      const requiredKeys = [
        'share_as_image',
        'generating_card',
        'card_ready',
      ];

      for (final key in requiredKeys) {
        expect(enMap.containsKey(key), isTrue, reason: 'Missing $key in en.json');
        expect(bnMap.containsKey(key), isTrue, reason: 'Missing $key in bn.json');
        expect((enMap[key] as String).isNotEmpty, isTrue);
        expect((bnMap[key] as String).isNotEmpty, isTrue);
      }
    });
  });
}
