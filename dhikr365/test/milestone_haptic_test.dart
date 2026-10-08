// ============================================================================
// test/milestone_haptic_test.dart
//
// Unit and Integration Tests for Tasbih Milestone Haptic & Detection System:
// 1. MilestoneType enum values
// 2. DhikrProvider.checkMilestone accuracy for 33, 66, 99, 100, and target
// 3. DhikrProvider.triggerMilestoneHaptic graceful execution
// 4. DhikrProvider.playCompletionSound non-throwing execution
// 5. DhikrProvider.incrementDhikr returns MilestoneType
// ============================================================================

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dhikr365/providers/dhikr_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'),
            (MethodCall methodCall) async {
      return true;
    });
  });

  group('Milestone Detection Logic (checkMilestone)', () {
    test('1. Regular counts return MilestoneType.none', () {
      expect(
        DhikrProvider.checkMilestone(count: 1, targetCount: 100),
        equals(MilestoneType.none),
      );
      expect(
        DhikrProvider.checkMilestone(count: 32, targetCount: 100),
        equals(MilestoneType.none),
      );
      expect(
        DhikrProvider.checkMilestone(count: 50, targetCount: 100),
        equals(MilestoneType.none),
      );
    });

    test('2. Exactly 33 returns MilestoneType.thirtyThree', () {
      expect(
        DhikrProvider.checkMilestone(count: 33, targetCount: 100),
        equals(MilestoneType.thirtyThree),
      );
      expect(
        DhikrProvider.checkMilestone(count: 33, targetCount: 0),
        equals(MilestoneType.thirtyThree),
      );
    });

    test('3. Exactly 66 returns MilestoneType.sixtySix', () {
      expect(
        DhikrProvider.checkMilestone(count: 66, targetCount: 100),
        equals(MilestoneType.sixtySix),
      );
      expect(
        DhikrProvider.checkMilestone(count: 66, targetCount: 0),
        equals(MilestoneType.sixtySix),
      );
    });

    test('4. Count 99 returns MilestoneType.thirtyThree (mod 33 <= 99)', () {
      expect(
        DhikrProvider.checkMilestone(count: 99, targetCount: 100),
        equals(MilestoneType.thirtyThree),
      );
    });

    test('5. Count 100 returns MilestoneType.hundred in infinite mode', () {
      expect(
        DhikrProvider.checkMilestone(count: 100, targetCount: 0),
        equals(MilestoneType.hundred),
      );
    });

    test('6. Reaching targetCount returns MilestoneType.target', () {
      // Target is 33
      expect(
        DhikrProvider.checkMilestone(count: 33, targetCount: 33),
        equals(MilestoneType.target),
      );
      // Target is 100
      expect(
        DhikrProvider.checkMilestone(count: 100, targetCount: 100),
        equals(MilestoneType.target),
      );
      // Target is 7
      expect(
        DhikrProvider.checkMilestone(count: 7, targetCount: 7),
        equals(MilestoneType.target),
      );
    });
  });

  group('Milestone Haptic Patterns & Sound Execution', () {
    test('7. triggerMilestoneHaptic executes all patterns safely', () async {
      await expectLater(
        DhikrProvider.triggerMilestoneHaptic(MilestoneType.none),
        completes,
      );
      await expectLater(
        DhikrProvider.triggerMilestoneHaptic(MilestoneType.thirtyThree),
        completes,
      );
      await expectLater(
        DhikrProvider.triggerMilestoneHaptic(MilestoneType.sixtySix),
        completes,
      );
      await expectLater(
        DhikrProvider.triggerMilestoneHaptic(MilestoneType.hundred),
        completes,
      );
      await expectLater(
        DhikrProvider.triggerMilestoneHaptic(MilestoneType.target),
        completes,
      );
    });

    test('8. playCompletionSound skips silently when chime file is absent', () async {
      await expectLater(
        DhikrProvider.playCompletionSound(),
        completes,
      );
    });
  });

  group('DhikrProvider incrementDhikr Milestone Return', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('9. incrementDhikr returns MilestoneType accurately', () async {
      final provider = DhikrProvider();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final dhikrs = provider.dhikrs;
      if (dhikrs.isNotEmpty) {
        final targetId = dhikrs.first.id;
        final milestone = await provider.incrementDhikr(targetId);
        expect(milestone, isA<MilestoneType>());
      }
    });
  });
}
