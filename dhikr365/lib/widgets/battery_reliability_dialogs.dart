// ============================================================================
// lib/widgets/battery_reliability_dialogs.dart
//
// Two-step, EXPLAINED flow for background-reliability permissions — the
// pattern top prayer apps (Muslim Pro, Athan) use instead of firing a raw
// system popup with no context:
//   1. Battery-optimization exemption — explained in plain language, THEN
//      the Android system dialog appears (never the reverse).
//   2. OEM Autostart tip — Xiaomi/Oppo/Vivo/Huawei/Honor ship their own
//      aggressive app-killer that the standard Android whitelist above does
//      NOT reliably stop; on those brands only, a second small dialog
//      deep-links to the manufacturer's own Autostart settings screen.
//
// Used from two places:
//   • SplashScreen — shown automatically, but only ONCE ever (a
//     SharedPreferences flag the caller manages), so it never nags.
//   • SettingsScreen — "Notification Reliability Tips", re-run manually by
//     the user any time they want, using the exact same dialogs.
// ============================================================================

import 'package:flutter/material.dart';

import '../constants/app_theme.dart';
import '../services/notification_service.dart';

const Map<String, String> _brandLabels = {
  'xiaomi': 'Xiaomi (MIUI)',
  'oppo': 'OPPO (ColorOS)',
  'vivo': 'vivo / iQOO',
  'huawei': 'Huawei',
  'honor': 'Honor',
};

Widget _stepItem(int num, String text) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 18,
        height: 18,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: Text(
          '$num',
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: AppText.body(color: AppColors.textSlate300).copyWith(fontSize: 12),
        ),
      ),
    ],
  );
}

/// Shows the battery-optimization guide, directing the user safely to the
/// App Info / Settings screen without using restricted system intents.
/// Complies 100% with Google Play policy.
Future<void> showBatteryExplainerDialog(BuildContext context) async {
  final svc = NotificationService();
  if (await svc.isIgnoringBatteryOptimizations()) return;
  if (!context.mounted) return;

  final isBn = Localizations.localeOf(context).languageCode == 'bn';

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.bgTeal,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        Icon(Icons.battery_charging_full_rounded,
            color: AppColors.primary, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            isBn ? 'নামাজের রিমাইন্ডার সচল রাখুন' : 'Keep Reminders Reliable',
            style: AppText.heading(16),
          ),
        ),
      ]),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isBn
                  ? 'ফোনের ব্যাকগ্রাউন্ড ব্যাটারি সেভার যাতে নামাজের ওয়াক্ত ও আযকার রিমাইন্ডার বন্ধ না করে, তার জন্য অ্যাপ সেটিংসে ব্যাটারি অপটিমাইজেশন বন্ধ রাখুন:'
                  : 'To ensure scheduled prayer alerts and adhkar reminders are never delayed or stopped by Android\'s battery saver, please configure App Settings:',
              style: AppText.body(color: AppColors.textSlate300).copyWith(height: 1.5),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.ink(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.ink(0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _stepItem(1, isBn ? 'নিচের "সেটিংস খুলুন" বাটনে ট্যাপ করুন' : 'Tap "Open Settings" below'),
                  const SizedBox(height: 8),
                  _stepItem(2, isBn ? '"Battery" বা "App battery usage"-এ যান' : 'Go to "Battery" or "App battery usage"'),
                  const SizedBox(height: 8),
                  _stepItem(3, isBn ? '"Unrestricted" নির্বাচন করুন' : 'Select "Unrestricted" / Allow in Background'),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isBn
                  ? 'এটি অপ্রয়োজনীয় চার্জ খরচ করে না — শুধু নির্ধারিত সময়ে আযানের নোটিফিকেশন বাজতে সাহায্য করে।'
                  : 'This does not drain excess battery — it only allows scheduled prayer alarms to wake the device on time.',
              style: AppText.body(color: AppColors.textSlate400).copyWith(fontSize: 11.5, height: 1.4),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(isBn ? 'পরে' : 'Later', style: AppText.body(color: AppColors.textSlate500)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            Navigator.pop(ctx);
            svc.openBatterySettings();
          },
          child: Text(
            isBn ? 'সেটিংস খুলুন' : 'Open Settings',
            style: AppText.manrope(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

/// Shows the OEM-specific Autostart tip when this device's brand is known to
/// need it (Xiaomi/Oppo/Vivo/Huawei/Honor). No-op on other brands.
Future<void> showAutostartTipDialog(BuildContext context) async {
  final svc = NotificationService();
  final brand = await svc.getAutostartBrand();
  if (brand == null || !context.mounted) return;
  final label = _brandLabels[brand] ?? brand;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.bgTeal,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        Icon(Icons.phone_android_rounded, color: AppColors.primary, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Text('One More Step for $label', style: AppText.heading(15))),
      ]),
      content: Text(
        '$label phones have their own battery manager that can stop '
        'reminder apps even after Android\'s own permission is granted.\n\n'
        'Please turn ON "Autostart" for this app on the next screen so '
        'reminders keep arriving on time.',
        style: AppText.body(color: AppColors.textSlate300).copyWith(height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Later', style: AppText.body(color: AppColors.textSlate500)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            Navigator.pop(ctx);
            svc.openAutostartSettings();
          },
          child: Text('Open Settings', style: AppText.manrope(fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

/// Shows the Exact Alarms explainer on Android 13/14+ if not already granted.
Future<void> showExactAlarmExplainerDialog(BuildContext context) async {
  final svc = NotificationService();
  if (await svc.isExactAlarmGranted()) return;
  if (!context.mounted) return;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.bgTeal,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        Icon(Icons.alarm_on_rounded, color: AppColors.primary, size: 24),
        const SizedBox(width: 10),
        Expanded(
          child: Text('On-Time Prayer Alarms', style: AppText.heading(16)),
        ),
      ]),
      content: Text(
        'Android requires explicit permission to sound prayer alerts and '
        'morning/evening adhkar reminders at the exact prescribed minute.\n\n'
        'Please allow "Alarms & Reminders" on the next screen.',
        style: AppText.body(color: AppColors.textSlate300).copyWith(height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Later', style: AppText.body(color: AppColors.textSlate500)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () async {
            Navigator.pop(ctx);
            await svc.openExactAlarmSettings();
          },
          child: Text('Allow in Settings', style: AppText.manrope(fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

/// Runs dialogs in sequence, in the order they matter:
/// 1. Exact Alarms permission (Android 13/14+)
/// 2. Battery-optimization exemption
/// 3. OEM-specific Autostart step (Xiaomi/Oppo/Vivo/Huawei/Honor)
/// If nothing is left to fix, shows a short confirmation instead of nothing.
Future<void> runNotificationReliabilityTips(BuildContext context) async {
  final svc = NotificationService();

  // 1. Exact alarms check (Android 12/13/14+)
  final canExact = await svc.isExactAlarmGranted();
  if (!canExact && context.mounted) {
    await showExactAlarmExplainerDialog(context);
  }

  // 2. Battery optimization exemption check
  final alreadyExempt = await svc.isIgnoringBatteryOptimizations();
  if (!context.mounted) return;
  if (!alreadyExempt) await showBatteryExplainerDialog(context);

  // 3. OEM Autostart check
  if (!context.mounted) return;
  final brand = await svc.getAutostartBrand();
  if (brand != null) {
    if (!context.mounted) return;
    await showAutostartTipDialog(context);
  }

  if (canExact && alreadyExempt && brand == null && context.mounted) {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgTeal,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22),
          const SizedBox(width: 10),
          Text('All Set', style: AppText.heading(16)),
        ]),
        content: Text(
          'Reminders and exact alarms are already configured to run reliably '
          'in the background on this device — nothing more to do.',
          style: AppText.body(color: AppColors.textSlate300).copyWith(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK', style: AppText.body(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}
