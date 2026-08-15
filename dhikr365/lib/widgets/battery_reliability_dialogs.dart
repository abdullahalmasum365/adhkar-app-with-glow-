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

/// Shows the battery-optimization explainer, then the real system dialog if
/// the user taps Allow. No-op if the app is already exempt.
Future<void> showBatteryExplainerDialog(BuildContext context) async {
  final svc = NotificationService();
  if (await svc.isIgnoringBatteryOptimizations()) return;
  if (!context.mounted) return;

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
          child: Text('Keep Reminders On Time',
              style: AppText.heading(16)),
        ),
      ]),
      content: Text(
        'So your prayer and adhkar reminders aren\'t delayed or skipped by '
        'your phone\'s battery saver, please allow this app to run in the '
        'background on the next screen.\n\n'
        'This does not drain your battery — it only lets scheduled '
        'reminders fire on time.',
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
            svc.requestBatteryOptimizationExemption();
          },
          child: Text('Allow', style: AppText.manrope(fontWeight: FontWeight.w700)),
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

/// Runs both dialogs in sequence, in the order they matter (battery first,
/// then the OEM-specific step). Used by Settings' "Notification Reliability
/// Tips" entry — always re-runnable, unlike the splash's one-time auto-show.
/// If nothing is left to fix, shows a short confirmation instead of nothing.
Future<void> runNotificationReliabilityTips(BuildContext context) async {
  final svc = NotificationService();
  final alreadyExempt = await svc.isIgnoringBatteryOptimizations();
  if (!context.mounted) return;
  if (!alreadyExempt) await showBatteryExplainerDialog(context);

  if (!context.mounted) return;
  final brand = await svc.getAutostartBrand();
  if (brand != null) {
    if (!context.mounted) return;
    await showAutostartTipDialog(context);
  }

  if (alreadyExempt && brand == null && context.mounted) {
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
          'Reminders are already allowed to run reliably in the background '
          'on this device — nothing more to do.',
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
