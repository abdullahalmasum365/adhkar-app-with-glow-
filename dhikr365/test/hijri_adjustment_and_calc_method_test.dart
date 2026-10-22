import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adhan/adhan.dart';
import 'package:dhikr365/providers/user_provider.dart';
import 'package:dhikr365/utils/prayer_calculation_helper.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:dhikr365/utils/date_formatter.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Prayer Calculation Method Default & Detection Tests', () {
    test('getMethodForCountry detects country correctly', () {
      expect(getMethodForCountry('Bangladesh'), equals(CalculationMethod.karachi));
      expect(getMethodForCountry('India'), equals(CalculationMethod.karachi));
      expect(getMethodForCountry('Pakistan'), equals(CalculationMethod.karachi));
      expect(getMethodForCountry('Saudi Arabia'), equals(CalculationMethod.umm_al_qura));
      expect(getMethodForCountry('United States'), equals(CalculationMethod.north_america));
      expect(getMethodForCountry('Egypt'), equals(CalculationMethod.egyptian));
      expect(getMethodForCountry('Turkey'), equals(CalculationMethod.turkey));
      expect(getMethodForCountry('United Kingdom'), equals(CalculationMethod.muslim_world_league));
    });

    test('UserProvider defaultCalculationMethod returns location default', () async {
      final user = UserProvider();
      await user.loadFuture;

      await user.setLocation('Dhaka', 'Bangladesh');
      expect(user.defaultCalculationMethod, equals(CalculationMethod.karachi));

      await user.setLocation('Mecca', 'Saudi Arabia');
      expect(user.defaultCalculationMethod, equals(CalculationMethod.umm_al_qura));
    });

    test('UserProvider resetCalculationMethodToDefault restores default after change', () async {
      final user = UserProvider();
      await user.loadFuture;

      await user.setLocation('Dhaka', 'Bangladesh');
      // Intentionally change to another method
      await user.setCalculationMethod(CalculationMethod.egyptian);
      expect(user.calculationMethod, equals(CalculationMethod.egyptian));

      // Reset to location default
      await user.resetCalculationMethodToDefault();
      expect(user.calculationMethod, equals(CalculationMethod.karachi));
    });
  });

  group('Hijri Date Adjustment Tests', () {
    test('UserProvider hijriAdjustment defaults to 0 and clamps properly', () async {
      final user = UserProvider();
      await user.loadFuture;
      expect(user.hijriAdjustment, equals(0));

      await user.setHijriAdjustment(1);
      expect(user.hijriAdjustment, equals(1));

      await user.setHijriAdjustment(-1);
      expect(user.hijriAdjustment, equals(-1));

      // Test clamping
      await user.setHijriAdjustment(5);
      expect(user.hijriAdjustment, equals(2));

      await user.setHijriAdjustment(-5);
      expect(user.hijriAdjustment, equals(-2));
    });

    test('Hijri calendar date shifts accurately with day offset', () {
      final baseDate = DateTime(2026, 10, 22);
      final standardHijri = HijriCalendar.fromDate(baseDate);

      final nextDayDate = baseDate.add(const Duration(days: 1));
      final nextHijri = HijriCalendar.fromDate(nextDayDate);

      final prevDayDate = baseDate.add(const Duration(days: -1));
      final prevHijri = HijriCalendar.fromDate(prevDayDate);

      // Verify formatting in English and Bengali
      final standardEn = AppDateFormatter.formatHijri(standardHijri, 'en');
      final standardBn = AppDateFormatter.formatHijri(standardHijri, 'bn');

      final nextEn = AppDateFormatter.formatHijri(nextHijri, 'en');
      final prevEn = AppDateFormatter.formatHijri(prevHijri, 'en');

      expect(standardEn.isNotEmpty, isTrue);
      expect(standardBn.isNotEmpty, isTrue);
      expect(nextEn, isNot(equals(standardEn)));
      expect(prevEn, isNot(equals(standardEn)));
    });
  });
}
