import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
import '../providers/dhikr_provider.dart';
import '../providers/user_provider.dart';
import '../providers/auth_provider.dart';
import '../constants/app_theme.dart';
import '../utils/responsive.dart';
import 'account_screen.dart';
import 'edit_profile_screen.dart';
import 'splash_screen.dart';
import '../providers/purchase_provider.dart';
import '../providers/notification_provider.dart';
import '../services/notification_service.dart';
import '../models/dhikr.dart';
import '../widgets/pro_paywall_sheet.dart';
import '../widgets/battery_reliability_dialogs.dart';
import 'donation_screen.dart';
import '../services/purchase_service.dart';
import 'widget_preview_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotificationService().invalidateExactAlarmCache();
      if (mounted) setState(() {});
    }
  }
  void _langSheet(
      {required String title,
      required String current,
      required void Function(String) onPick}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        decoration: BoxDecoration(
          color: AppColors.bgTeal,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.ink(0.24),
                  borderRadius: BorderRadius.circular(2))),
          Padding(
              padding: const EdgeInsets.all(20),
              child: Text(title, style: AppText.heading(18))),
          Flexible(
              child: ListView.builder(
            shrinkWrap: true,
            itemCount: LanguageProvider.supportedLanguages.length,
            itemBuilder: (_, i) {
              final lang = LanguageProvider.supportedLanguages[i];
              final sel = lang['code'] == current;
              return ListTile(
                leading: Text(sel ? '●' : '○',
                    style: TextStyle(
                        color: sel ? AppColors.primary : AppColors.ink(0.24),
                        fontSize: 16)),
                title: Text(lang['nativeName']!,
                    style: AppText.manrope(
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                        color:
                            sel ? AppColors.textPrimary : AppColors.ink(0.70))),
                subtitle: Text(lang['name']!,
                    style: AppText.body(color: AppColors.ink(0.38))),
                onTap: () {
                  onPick(lang['code']!);
                  Navigator.pop(context);
                },
              );
            },
          )),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Future<void> _logout() async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgTeal,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(lp.getText('logout'), style: AppText.heading(18)),
        content: Text(lp.getText('are_you_sure'),
            style: AppText.body(color: AppColors.textSlate300)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(lp.getText('cancel'),
                  style: AppText.body(color: AppColors.textSlate400))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(lp.getText('logout'),
                  style: AppText.body(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final u = Provider.of<UserProvider>(context, listen: false);
    await u.resetProfile();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SplashScreen()),
        (_) => false,
      );
    }
  }

  void _showAboutCreditsDialog(BuildContext context, LanguageProvider lp) {
    final isBn = lp.locale.languageCode == 'bn';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgTeal,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.info_outline_rounded,
                color: AppColors.primary, size: 22),
            const SizedBox(width: 10),
            Text(
              isBn ? 'অ্যাপ পরিচিতি ও উৎস' : 'About & Attributions',
              style: AppText.heading(18),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Adhkar 365 (v1.0.0)',
                style: AppText.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isBn
                    ? 'ডেভেলপার: আব্দুল্লাহ আল মাসুম\nএকটি সম্পূর্ণ বিজ্ঞাপনমুক্ত ইসলামিক অ্যাপ।'
                    : 'Developer: Abdullah Al Masum\nA 100% ad-free, spiritual companion for daily dhikr.',
                style: AppText.manrope(
                    fontSize: 13, color: AppColors.textSlate300),
              ),
              const SizedBox(height: 14),
              const Divider(color: Colors.white12),
              const SizedBox(height: 8),
              Text(
                isBn
                    ? '📖 দোয়ার উৎস ও সত্যতা:'
                    : '📖 Islamic Texts & Authenticity:',
                style: AppText.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isBn
                    ? 'সকল দোয়া ও যিকির সংকলিত হয়েছে শায়খ সাঈদ বিন আলী বিন ওয়াহফ আল-কাহত্বানী (রহি.) রচিত "হিসনুল মুসলিম" কিতাব থেকে, সহীহ বুখারী, সহীহ মুসলিম ও সুনানের সনদসহ।'
                    : 'All supplications are compiled from "Hisn al-Muslim" (Fortress of the Muslim) by Sheikh Saeed bin Ali bin Wahf Al-Qahtani, cross-referenced with Sahih al-Bukhari, Sahih Muslim, and classical Sunan.',
                style: AppText.manrope(
                    fontSize: 12, color: AppColors.textSlate400),
              ),
              const SizedBox(height: 12),
              Text(
                isBn ? '🎙️ অডিও তিলাওয়াত:' : '🎙️ Audio Recitations:',
                style: AppText.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isBn
                    ? 'হিসনুল মুসলিম দোয়ার অডিও ও নির্বাচিত কুরআনিক আয়াতসমূহ আত্মিক ও শিক্ষামূলক উদ্দেশ্যে সকল ব্যবহারকারীর জন্য উন্মুক্ত।'
                    : 'Hisn al-Muslim supplications and selected Qur\'anic audio recitations are freely accessible to all users for educational and spiritual guidance.',
                style: AppText.manrope(
                    fontSize: 12, color: AppColors.textSlate400),
              ),
              const SizedBox(height: 12),
              Text(
                isBn ? '🌍 অবস্থান ও ম্যাপিং ডেটা:' : '🌍 Location & Geodata:',
                style: AppText.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isBn
                    ? 'নামাজের ওয়াক্ত হিসাব: Adhan Library। রিভার্স জিওকোডিং: ডিভাইস নেটিভ সার্ভিস (Google Play Services / Apple CoreLocation)। শহর অনুসন্ধান ও ভৌগোলিক তথ্য: GeoNames (geonames.org) ও © OpenStreetMap contributors (ODbL)।'
                    : 'Prayer calculations by Adhan Library. Reverse geocoding by native device geocoder. City search & geographic data by GeoNames (geonames.org) and © OpenStreetMap contributors (ODbL).',
                style: AppText.manrope(
                    fontSize: 12, color: AppColors.textSlate400),
              ),
              const SizedBox(height: 12),
              Text(
                isBn ? '⚖️ ফন্ট ও লাইব্রেরি:' : '⚖️ Fonts & Open Source:',
                style: AppText.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Amiri, Space Mono, Manrope, Public Sans (SIL Open Font License). Built with Flutter & open-source community libraries.',
                style: AppText.manrope(
                    fontSize: 12, color: AppColors.textSlate400),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            icon: Icon(Icons.description_outlined, size: 16, color: AppColors.primary),
            label: Text(
              isBn ? 'লাইসেন্সসমূহ' : 'Licenses',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              showLicensePage(
                context: context,
                applicationName: 'Adhkar 365',
                applicationVersion: '1.0.0',
                applicationLegalese: '© ${DateTime.now().year} Abdullah Al Masum. All rights reserved.',
              );
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              isBn ? 'ঠিক আছে' : 'Close',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final lp = Provider.of<LanguageProvider>(context);
    final tp = Provider.of<ThemeProvider>(context);
    final up = Provider.of<UserProvider>(context);
    final np = Provider.of<NotificationProvider>(context);
    final ap = Provider.of<AuthProvider>(context);
    final pp = Provider.of<PurchaseProvider>(context);

    final name = (up.userName?.isNotEmpty == true)
        ? up.userName!
        : lp.getText('guest_user');
    final initials = name
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Container(
        decoration: AppDeco.radialBg(center: Alignment.topLeft),
        child: SafeArea(
            child: Column(children: [
          Padding(
              padding: EdgeInsets.symmetric(vertical: R.px(16)),
              child: Text(lp.getText('settings'), style: AppText.heading(20))),
          Expanded(
              child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            physics: const BouncingScrollPhysics(),
            children: [
              // ── Profile ──
              _Card(
                  child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3))),
                      child: Center(
                          child: Text(initials.isEmpty ? '?' : initials,
                              style: AppText.manrope(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary)))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(name,
                            style: AppText.manrope(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                        Text(lp.getText('active_member'),
                            style: AppText.body(color: AppColors.textSlate400)),
                      ])),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const EditProfileScreen()));
                    },
                    child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(lp.getText('edit'),
                            style: AppText.body(color: AppColors.primary))),
                  ),
                ]),
              )),
              const SizedBox(height: 22),

              // ── Account & Sync ──
              _Lbl(lp.getText('account_title')),
              _Card(
                child: _Tile(
                  icon: ap.isSignedIn
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_outlined,
                  color: ap.isSignedIn ? Colors.greenAccent : Colors.blueAccent,
                  title: ap.isSignedIn
                      ? (ap.displayName.isNotEmpty
                          ? ap.displayName
                          : lp.getText('account_title'))
                      : lp.getText('account_signed_out_title'),
                  subtitle: ap.isSignedIn
                      ? lp.getText('account_sync_active')
                      : lp.getText('account_tile_subtitle'),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AccountScreen())),
                ),
              ),
              const SizedBox(height: 22),

              // ── Notifications ──
              _Lbl(lp.getText('notifications')),
              FutureBuilder<List<bool>>(
                future: Future.wait([
                  NotificationService().areNotificationsEnabled(),
                  NotificationService().isExactAlarmGranted(),
                ]),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  final notifEnabled = snapshot.data![0];
                  final exactEnabled = snapshot.data![1];

                  if (!notifEnabled) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade900.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber.shade700, width: 1.2),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lp.getText('notif_status_disabled'),
                                  style: AppText.body(color: Colors.amberAccent)
                                      .copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  lp.getText('notif_status_disabled_sub'),
                                  style: AppText.manrope(
                                      fontSize: 12, color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () async {
                              await NotificationService().openNotificationSettings();
                              if (context.mounted) setState(() {});
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(
                              lp.getText('notif_fix_btn'),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (!exactEnabled) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade900.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.tealAccent.shade400, width: 1.2),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.alarm_on_rounded, color: Colors.tealAccent, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lp.locale.languageCode == 'bn'
                                      ? 'সঠিক সময়ে অ্যালার্ম পারমিশন'
                                      : 'Exact Alarms Permission',
                                  style: AppText.body(color: Colors.tealAccent)
                                      .copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  lp.locale.languageCode == 'bn'
                                      ? 'নামাজের ওয়াক্তে সঠিক সময়ে অ্যালার্ম বাজতে Alarms & Reminders চালু করুন'
                                      : 'Allow Alarms & Reminders so prayer alerts ring precisely on time',
                                  style: AppText.manrope(
                                      fontSize: 12, color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () async {
                              await NotificationService().openExactAlarmSettings();
                              NotificationService().invalidateExactAlarmCache();
                              if (context.mounted) setState(() {});
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(
                              lp.locale.languageCode == 'bn' ? 'অনুমতি দিন' : 'Allow',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),
              _Card(
                  child: Column(children: [
                _Tile(
                    icon: Icons.wb_twilight,
                    color: Colors.orangeAccent,
                    title: lp.getText('morning_notif'),
                    subtitle: lp.getText('daily_at_sunrise'),
                    trailing: Switch(
                        value: np.morningEnabled,
                        onChanged: (v) => np.toggleMorning(v, up))),
                _div(),
                _Tile(
                    icon: Icons.nights_stay,
                    color: Colors.purpleAccent,
                    title: lp.getText('evening_notif'),
                    subtitle: lp.getText('daily_at_maghrib'),
                    trailing: Switch(
                        value: np.eveningEnabled,
                        onChanged: (v) => np.toggleEvening(v, up))),
                _div(),
                _Tile(
                    icon: Icons.auto_awesome,
                    color: AppColors.primary,
                    title: lp.getText('special_times'),
                    subtitle: lp.getText('accepted_dua_times'),
                    trailing: Switch(
                        value: np.specialTimesEnabled,
                        onChanged: (v) => np.toggleSpecialTimes(v))),
                _div(),
                _Tile(
                    icon: Icons.notifications_active_rounded,
                    color: Colors.tealAccent,
                    title: lp.getText('notif_test_btn'),
                    subtitle: lp.getText('notif_test_sub'),
                    onTap: () async {
                      final svc = NotificationService();
                      final hasPermission = await svc.areNotificationsEnabled();
                      if (!hasPermission) {
                        await svc.requestPermissions();
                        final stillOff = !(await svc.areNotificationsEnabled());
                        if (stillOff) {
                          if (context.mounted) {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: AppColors.bgTeal,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                title: Text(lp.getText('notif_status_disabled'), style: AppText.heading(18)),
                                content: Text(lp.getText('notif_permission_body'), style: AppText.body(color: Colors.white70)),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: Text(lp.getText('cancel'), style: AppText.body(color: AppColors.textSlate400)),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      svc.openNotificationSettings();
                                    },
                                    child: Text(lp.getText('notif_fix_btn'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            );
                          }
                          return;
                        }
                      }

                      final canExact = await svc.isExactAlarmGranted();
                      if (!canExact && context.mounted) {
                        final proceed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: AppColors.bgTeal,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: Row(
                              children: [
                                const Icon(Icons.alarm_on_rounded, color: Colors.amberAccent, size: 24),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    lp.locale.languageCode == 'bn'
                                        ? 'অ্যালার্ম ও রিমাইন্ডার পারমিশন'
                                        : 'Alarms & Reminders Permission',
                                    style: AppText.heading(16),
                                  ),
                                ),
                              ],
                            ),
                            content: Text(
                              lp.locale.languageCode == 'bn'
                                  ? '১০ সেকেন্ডের শিডিউল অ্যালার্ম ও নামাজের ওয়াক্তের সঠিক নোটিফিকেশনের জন্য "Alarms & Reminders" পারমিশন অন করতে হবে। আপনি কি সেটিংস ওপেন করতে চান?'
                                  : 'Exact alarm permission is required for on-time prayer alerts and the 10-second test alarm. Would you like to open Settings to allow it?',
                              style: AppText.body(color: AppColors.textSlate300).copyWith(height: 1.4),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: Text(
                                  lp.locale.languageCode == 'bn' ? 'এমনিতেই টেস্ট করুন' : 'Test Anyway',
                                  style: AppText.body(color: AppColors.textSlate400),
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                                onPressed: () async {
                                  Navigator.pop(ctx, false);
                                  await svc.openExactAlarmSettings();
                                },
                                child: Text(
                                  lp.locale.languageCode == 'bn' ? 'অনুমতি দিন (Allow)' : 'Allow in Settings',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (proceed != true) return;
                      }

                      final success = await svc.showInstantTestNotification();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: success ? AppColors.primary : Colors.red.shade700,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            content: Text(
                              success
                                  ? (canExact
                                      ? lp.getText('notif_test_sent')
                                      : (lp.locale.languageCode == 'bn'
                                          ? 'ইনস্ট্যান্ট নোটিফিকেশন পাঠানো হয়েছে। Alarms & Reminders পারমিশন ছাড়া ১০ সেকেন্ডের অ্যালার্ম বিলম্বিত হতে পারে।'
                                          : 'Instant test sent. Without Exact Alarms permission, scheduled alarms may be delayed.'))
                                  : (lp.locale.languageCode == 'bn'
                                      ? 'নোটিফিকেশন পাঠানো সম্ভব হয়নি। অনুগ্রহ করে ফোনের সেটিংসে নোটিফিকেশন অন আছে কিনা চেক করুন।'
                                      : 'Could not send notification. Please check system notification permission.'),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        );
                      }
                    }),
                _div(),
                _Tile(
                    icon: Icons.battery_saver_rounded,
                    color: Colors.amberAccent,
                    title: lp.getText('notif_battery_fix'),
                    subtitle: lp.getText('notif_battery_fix_sub'),
                    onTap: () => runNotificationReliabilityTips(context)),
                _div(),
                _Tile(
                    icon: Icons.workspace_premium_rounded,
                    color: ThemeProvider.divineAmber,
                    title: lp.locale.languageCode == 'bn'
                        ? 'আযকার ৩৬৫ প্রো'
                        : 'Adhkar 365 PRO',
                    subtitle: pp.isPro
                        ? (pp.hasLifetimePro
                            ? (lp.locale.languageCode == 'bn'
                                ? 'সক্রিয় (লাইফটাইম প্রো)'
                                : 'Active (Lifetime Pro)')
                            : (pp.activeProTierId == DonationProductIds.pro1Year
                                ? (lp.locale.languageCode == 'bn'
                                    ? 'সক্রিয় (১ বছরের প্ল্যান)'
                                    : 'Active (1 Year Plan)')
                                : (pp.activeProTierId == DonationProductIds.pro6Months
                                    ? (lp.locale.languageCode == 'bn'
                                        ? 'সক্রিয় (৬ মাসের প্ল্যান)'
                                        : 'Active (6 Months Plan)')
                                    : (lp.locale.languageCode == 'bn'
                                        ? 'সক্রিয় (১ মাসের প্ল্যান)'
                                        : 'Active (1 Month Plan)'))))
                        : (lp.locale.languageCode == 'bn'
                            ? '১ মাস, ৬ মাস বা ১ বছরের প্ল্যান'
                            : '1 Month, 6 Months or 1 Year plan'),
                    trailing: pp.isPro
                        ? const Icon(Icons.check_circle_rounded,
                            color: Colors.green, size: 20)
                        : const Icon(Icons.arrow_forward_ios_rounded,
                            size: 14, color: Colors.grey),
                    onTap: pp.isPro
                        ? null
                        : () => showProPaywallModal(context)),
                _div(),
                _Tile(
                    icon: Icons.volunteer_activism_rounded,
                    color: Colors.pinkAccent,
                    title: lp.locale.languageCode == 'bn'
                        ? 'সাদাকায়ে জারিয়া ও ডোনেশন'
                        : 'Sadaqah Jariyah & Donate',
                    subtitle: lp.locale.languageCode == 'bn'
                        ? (pp.hasActiveDonation
                            ? 'আপনার সক্রিয় সাদাকায়ে জারিয়া চলমান'
                            : 'প্রো ও রেগুলার সবার জন্য উন্মুক্ত • যেকোনো সময়')
                        : (pp.hasActiveDonation
                            ? 'Your ongoing Sadaqah Jariyah is active'
                            : 'Open to Pro & regular users • Anytime'),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded,
                        size: 14, color: Colors.grey),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const DonationScreen()))),
              ])),
              const SizedBox(height: 22),

              // ── Prayer Alerts ──
              _Lbl(lp.getText('prayer_alerts')),
              _Card(
                  child: Column(children: [
                _Tile(
                    icon: Icons.wb_twilight,
                    color: Colors.blueAccent,
                    title: lp.getText('fajr'),
                    trailing: Switch(
                        value: np.fajrEnabled,
                        onChanged: (v) =>
                            np.toggleSpecificPrayer('Fajr', v, up))),
                _div(),
                _Tile(
                    icon: Icons.wb_sunny_outlined,
                    color: Colors.orangeAccent,
                    title: lp.getText('sunrise'),
                    trailing: Switch(
                        value: np.sunriseEnabled,
                        onChanged: (v) =>
                            np.toggleSpecificPrayer('Sunrise', v, up))),
                _div(),
                _Tile(
                    icon: Icons.wb_sunny,
                    color: Colors.yellowAccent,
                    title: lp.getText('dhuhr'),
                    trailing: Switch(
                        value: np.dhuhrEnabled,
                        onChanged: (v) =>
                            np.toggleSpecificPrayer('Dhuhr', v, up))),
                _div(),
                _Tile(
                    icon: Icons.wb_cloudy_outlined,
                    color: Colors.amberAccent,
                    title: lp.getText('asr'),
                    trailing: Switch(
                        value: np.asrEnabled,
                        onChanged: (v) =>
                            np.toggleSpecificPrayer('Asr', v, up))),
                _div(),
                _Tile(
                    icon: Icons.nights_stay_outlined,
                    color: Colors.deepOrangeAccent,
                    title: lp.getText('maghrib'),
                    trailing: Switch(
                        value: np.maghribEnabled,
                        onChanged: (v) =>
                            np.toggleSpecificPrayer('Maghrib', v, up))),
                _div(),
                _Tile(
                    icon: Icons.nights_stay,
                    color: Colors.indigoAccent,
                    title: lp.getText('isha'),
                    trailing: Switch(
                        value: np.ishaEnabled,
                        onChanged: (v) =>
                            np.toggleSpecificPrayer('Isha', v, up))),
              ])),
              const SizedBox(height: 22),

              // ── Language ──
              _Lbl(lp.getText('localization')),
              _Card(
                  child: Column(children: [
                _Tile(
                    icon: Icons.language,
                    color: Colors.blueAccent,
                    title: lp.getText('app_language'),
                    subtitle: _native(lp.locale.languageCode),
                    onTap: () => _langSheet(
                        title: lp.getText('app_language'),
                        current: lp.locale.languageCode,
                        onPick: (c) async {
                          final dp = Provider.of<DhikrProvider>(context, listen: false);
                          final up = Provider.of<UserProvider>(context, listen: false);
                          final np = Provider.of<NotificationProvider>(context, listen: false);
                          await lp.setLanguage(c);
                          await dp.reloadDhikrs(
                              uiLanguageCode: c,
                              transliterationCode: lp.transliterationCode,
                              translationCode: lp.translationCode);
                          await np.refreshAllSchedules(up);
                        })),
                _div(),
                _Tile(
                    icon: Icons.translate,
                    color: Colors.tealAccent,
                    title: lp.getText('translation_lang'),
                    subtitle: _native(lp.translationCode),
                    onTap: () => _langSheet(
                        title: lp.getText('translation_lang'),
                        current: lp.translationCode,
                        onPick: (c) async {
                          await lp.setTranslationLanguage(c);
                          if (context.mounted) {
                            await Provider.of<DhikrProvider>(context,
                                    listen: false)
                                .reloadDhikrs(
                                    uiLanguageCode: lp.locale.languageCode,
                                    transliterationCode: lp.transliterationCode,
                                    translationCode: c);
                          }
                        })),
                _div(),
                _Tile(
                    icon: Icons.spellcheck,
                    color: Colors.amberAccent,
                    title: lp.getText('transliteration_lang'),
                    subtitle: _native(lp.transliterationCode),
                    onTap: () => _langSheet(
                        title: lp.getText('transliteration_lang'),
                        current: lp.transliterationCode,
                        onPick: (c) async {
                          await lp.setTransliterationLanguage(c);
                          if (context.mounted) {
                            await Provider.of<DhikrProvider>(context,
                                    listen: false)
                                .reloadDhikrs(
                                    uiLanguageCode: lp.locale.languageCode,
                                    transliterationCode: c,
                                    translationCode: lp.translationCode);
                          }
                        })),
              ])),
              const SizedBox(height: 22),

              // ── Notification Reliability Tips ──
              // Re-runnable any time — battery-optimization + OEM Autostart


              // ── Appearance ──
              _Lbl(lp.getText('appearance')),
              _Card(
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                    child: Row(children: [
                      Icon(Icons.palette_rounded,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Text('App Theme',
                          style: AppText.manrope(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(children: [
                      // Two theme cards per row, generated from the palette
                      // registry — adding a palette adds a card automatically.
                      // After a switch, notifications are re-scheduled so
                      // their accent color follows the new theme too.
                      for (int i = 0; i < AppPalettes.all.length; i += 2)
                        Padding(
                          padding: EdgeInsets.only(
                              bottom: i + 2 < AppPalettes.all.length ? 12 : 0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                  child: _ThemeChoice.fromPalette(
                                      AppPalettes.all[i], tp,
                                      isUserPro: pp.isPro,
                                      context: context,
                                      onSelected: () =>
                                          np.refreshAllSchedules(up))),
                              const SizedBox(width: 12),
                              Expanded(
                                child: i + 1 < AppPalettes.all.length
                                    ? _ThemeChoice.fromPalette(
                                        AppPalettes.all[i + 1], tp,
                                        isUserPro: pp.isPro,
                                        context: context,
                                        onSelected: () =>
                                            np.refreshAllSchedules(up))
                                    : const SizedBox(),
                              ),
                            ],
                          ),
                        ),
                    ]),
                  ),
                  _div(),
                  _Tile(
                    icon: Icons.widgets_rounded,
                    color: Colors.amberAccent,
                    title: lp.locale.languageCode == 'bn'
                        ? 'হোম স্ক্রিন উইজেট'
                        : 'Home Screen Widgets',
                    subtitle: lp.locale.languageCode == 'bn'
                        ? 'কাস্টম থিমযুক্ত উইজেট প্রিভিউ ও পিন করুন'
                        : 'Live-themed widget preview & setup',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const WidgetPreviewScreen()),
                    ),
                  ),
                  _div(),
                  _Tile(
                    icon: Icons.spellcheck_rounded,
                    color: Colors.tealAccent,
                    title: lp.getText('show_transliteration'),
                    subtitle: lp.getText('show_transliteration_desc'),
                    trailing: Switch(
                      value: tp.showTransliteration,
                      onChanged: tp.toggleTransliteration,
                    ),
                  ),
                  _div(),
                  _Tile(
                    icon: Icons.insights_rounded,
                    color: AppColors.primary,
                    title: lp.getText('habit_tracker'),
                    subtitle: lp.getText('habit_tracker_desc'),
                    trailing: Switch(
                      value: tp.showHabitTracker,
                      onChanged: tp.toggleHabitTracker,
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 22),

              // ── Footer ──
              _Card(
                  child: Column(children: [
                _Tile(
                    icon: Icons.description_outlined,
                    color: AppColors.textSlate400,
                    title: lp.getText('terms_of_service'),
                    onTap: () => launchUrl(
                        Uri.parse(
                            'https://abdullahalmasum365.github.io/adhkar-app-with-glow-/terms-of-service.html'),
                        mode: LaunchMode.externalApplication)),
                _div(),
                _Tile(
                    icon: Icons.policy_outlined,
                    color: AppColors.textSlate400,
                    title: lp.getText('privacy_policy'),
                    onTap: () => launchUrl(
                        Uri.parse(
                            'https://abdullahalmasum365.github.io/adhkar-app-with-glow-/privacy-policy.html'),
                        mode: LaunchMode.externalApplication)),
                _div(),
                _Tile(
                    icon: Icons.assignment_return_outlined,
                    color: AppColors.textSlate400,
                    title: lp.getText('refund_policy'),
                    onTap: () => launchUrl(
                        Uri.parse(
                            'https://abdullahalmasum365.github.io/adhkar-app-with-glow-/refund-policy.html'),
                        mode: LaunchMode.externalApplication)),
                _div(),
                _Tile(
                    icon: Icons.cookie_outlined,
                    color: AppColors.textSlate400,
                    title: lp.getText('cookie_policy'),
                    onTap: () => launchUrl(
                        Uri.parse(
                            'https://abdullahalmasum365.github.io/adhkar-app-with-glow-/cookie-policy.html'),
                        mode: LaunchMode.externalApplication)),
                _div(),
                _Tile(
                    icon: Icons.info_outline_rounded,
                    color: AppColors.primary,
                    title: lp.locale.languageCode == 'bn'
                        ? 'অ্যাপ পরিচিতি ও উৎস (ক্রেডিট)'
                        : 'About & Attributions',
                    onTap: () => _showAboutCreditsDialog(context, lp)),
                _div(),
                _Tile(
                    icon: Icons.logout,
                    color: Colors.redAccent,
                    title: lp.getText('logout'),
                    titleColor: Colors.redAccent,
                    onTap: _logout),
              ])),
              const SizedBox(height: 14),
              const _DevVersionTap(),
              const SizedBox(height: 32),
            ],
          )),
        ])),
      ),
    );
  }

  String _native(String code) {
    final m = LanguageProvider.supportedLanguages
        .where((l) => l['code'] == code)
        .toList();
    return m.isNotEmpty ? m.first['nativeName']! : code;
  }

  Widget _div() => Divider(
      height: 1,
      thickness: 1,
      color: AppColors.ink(0.05),
      indent: 14,
      endIndent: 14);
}

/// A tappable theme preview card: three color swatches, name, and a
/// check ring when active. Designed to sell the theme at a glance.
class _ThemeChoice extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final List<Color> swatches; // [background, surface, accent]
  final Color previewText;
  final bool isPro;
  final bool isLocked;
  final VoidCallback onTap;

  const _ThemeChoice({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.swatches,
    required this.previewText,
    this.isPro = false,
    this.isLocked = false,
    required this.onTap,
  });

  /// Builds a preview card directly from a palette definition.
  /// [onSelected] runs after the palette is applied (e.g. rescheduling
  /// notifications so their accent color matches the new theme).
  factory _ThemeChoice.fromPalette(
    AppPalette p,
    ThemeProvider tp, {
    required bool isUserPro,
    required BuildContext context,
    Future<void> Function()? onSelected,
  }) {
    final locked = p.isPro && !isUserPro;
    return _ThemeChoice(
      title: p.label,
      subtitle: p.tagline,
      selected: tp.paletteId == p.id,
      swatches: [p.homeGradient[0], p.homeGradient[1], p.primary],
      previewText: p.textPrimary,
      isPro: p.isPro,
      isLocked: locked,
      onTap: () async {
        if (locked) {
          showProPaywallModal(context);
          return;
        }
        if (tp.paletteId == p.id) return;
        await tp.setPalette(p.id);
        await onSelected?.call();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.10)
              : AppColors.ink(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : (isLocked
                    ? ThemeProvider.divineAmber.withValues(alpha: 0.3)
                    : AppColors.ink(0.10)),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mini mockup: background with a floating accent pill
            Container(
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [swatches[0], swatches[1]],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.ink(0.08)),
              ),
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 44,
                        height: 7,
                        decoration: BoxDecoration(
                          color: previewText.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      if (isPro)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: ThemeProvider.divineAmber
                                .withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: ThemeProvider.divineAmber, width: 0.8),
                          ),
                          child: Text(
                            'PRO',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              color: ThemeProvider.divineAmber,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Row(children: [
                    Container(
                      width: 26,
                      height: 12,
                      decoration: BoxDecoration(
                        color: swatches[2],
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: previewText.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.manrope(
                        fontSize: 12.5, fontWeight: FontWeight.w800)),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : (isLocked
                        ? Icons.lock_rounded
                        : Icons.circle_outlined),
                size: 16,
                color: selected
                    ? AppColors.primary
                    : (isLocked
                        ? ThemeProvider.divineAmber
                        : AppColors.ink(0.25)),
              ),
            ]),
            const SizedBox(height: 2),
            Text(subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(color: AppColors.textSlate400)
                    .copyWith(fontSize: 10.5)),
          ],
        ),
      ),
    );
  }
}

class _Lbl extends StatelessWidget {
  final String text;
  const _Lbl(this.text);
  @override
  Widget build(_) => Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(text.toUpperCase(), style: AppText.label()));
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(_) => Container(
        decoration: AppDeco.glassCard(borderRadius: BorderRadius.circular(14)),
        child: child,
      );
}

class _IBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _IBox(this.icon, this.color);
  @override
  Widget build(_) => Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: color, size: 17));
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final Color? titleColor;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _Tile(
      {required this.icon,
      required this.color,
      required this.title,
      this.titleColor,
      this.subtitle,
      this.trailing,
      this.onTap});

  @override
  Widget build(_) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: _IBox(icon, color),
        title: Text(title,
            style: AppText.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: titleColor ?? AppColors.textPrimary)),
        subtitle: subtitle != null
            ? Text(subtitle!,
                style: AppText.body(color: AppColors.textSlate400)
                    .copyWith(fontSize: 12))
            : null,
        trailing: trailing ??
            (onTap != null
                ? Icon(Icons.chevron_right,
                    color: AppColors.textSlate500, size: 20)
                : null),
        onTap: onTap,
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// DEV PANEL — tap version text 7 times to unlock
// ═══════════════════════════════════════════════════════════════════════════

class _DevVersionTap extends StatefulWidget {
  const _DevVersionTap();
  @override
  State<_DevVersionTap> createState() => _DevVersionTapState();
}

class _DevVersionTapState extends State<_DevVersionTap> {
  int _taps = 0;
  static const _required = 7;

  void _onTap() {
    setState(() => _taps++);
    if (_taps >= _required) {
      _taps = 0;
      _openDevPanel(context);
    }
  }

  void _openDevPanel(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _DevPanelSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Text('VERSION 1.0.0',
              style: AppText.label(color: AppColors.textSlate500)),
        ),
      );
    }
    final remaining = _required - _taps;
    return GestureDetector(
      onTap: _onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Column(
            children: [
              Text('VERSION 1.0.0',
                  style: AppText.label(color: AppColors.textSlate500)),
              if (_taps > 0 && _taps < _required)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '🔧 $remaining more taps for Dev Panel',
                    style: AppText.label(color: AppColors.primary)
                        .copyWith(fontSize: 10),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Dev Panel bottom sheet ──────────────────────────────────────────────────
class _DevPanelSheet extends StatelessWidget {
  const _DevPanelSheet();

  @override
  Widget build(BuildContext context) {
    return Consumer2<PurchaseProvider, DhikrProvider>(
      builder: (ctx, pp, dp, _) {
        final isPro = pp.isPro;
        final streak = dp.streakDays;
        final totalTaps = dp.totalDhikrCount;
        final completed = dp.completedSets;
        final earlyBird = dp.earlyBirdBadge;
        final nightPrayer = dp.nightPrayerBadge;
        const categories = DhikrCategory.values;

        return Container(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.88),
          decoration: BoxDecoration(
            color: AppColors.bgTeal,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
                color: Colors.orange.withValues(alpha: 0.5), width: 1.5),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Row(children: [
                  const Icon(Icons.developer_mode_rounded,
                      color: Colors.orange, size: 22),
                  const SizedBox(width: 8),
                  Text('DEV PANEL',
                      style: AppText.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.orange)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text('TEST ONLY',
                        style: AppText.label(color: Colors.orange)),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(
                    'Internal testing panel. Not visible to users without 7 taps on version.',
                    style: AppText.body(color: AppColors.textSlate400)
                        .copyWith(fontSize: 11)),
                const SizedBox(height: 20),

                // ── PRO TOGGLE ────────────────────────────────────────────
                _devSection(
                  icon: Icons.workspace_premium_rounded,
                  label: 'SUBSCRIPTION STATUS',
                  color: ThemeProvider.divineAmber,
                  child: Column(
                    children: [
                      _devRow(
                        'Current Status',
                        isPro
                            ? '✅ PRO ACTIVE'
                            : '🔒 FREE (Non-Pro)',
                        valueColor: isPro ? Colors.green : Colors.grey,
                      ),
                      if (pp.activeSubscriptionId != null)
                        _devRow('Product ID', pp.activeSubscriptionId!),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: Icon(
                              isPro
                                  ? Icons.lock_open_rounded
                                  : Icons.workspace_premium_rounded,
                              size: 18),
                          label: Text(isPro
                              ? 'SWITCH TO FREE (Non-Pro)'
                              : 'UNLOCK PRO (Simulate Purchase)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isPro
                                ? Colors.redAccent.withValues(alpha: 0.15)
                                : ThemeProvider.divineAmber
                                    .withValues(alpha: 0.2),
                            foregroundColor:
                                isPro ? Colors.redAccent : ThemeProvider.divineAmber,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                    color: isPro
                                        ? Colors.redAccent
                                        : ThemeProvider.divineAmber,
                                    width: 1)),
                            elevation: 0,
                          ),
                          onPressed: kDebugMode ? () => pp.toggleProForTesting() : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                          '📌 Pro unlocks: Custom Plan (Customize routine), priority cloud sync',
                          style: AppText.body(color: AppColors.textSlate400)
                              .copyWith(fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── PROGRESS STATE ────────────────────────────────────────
                _devSection(
                  icon: Icons.bar_chart_rounded,
                  label: 'PROGRESS STATE',
                  color: Colors.tealAccent,
                  child: Column(
                    children: [
                      _devRow('Streak', '$streak days 🔥'),
                      _devRow('Today Total Taps', '$totalTaps'),
                      _devRow('Completed Sets', '$completed / ${dp.dhikrs.length}'),
                      _devRow(
                          'Early Bird Badge (Morning < 11am)',
                          earlyBird ? '🏅 UNLOCKED' : '🔒 Locked',
                          valueColor:
                              earlyBird ? Colors.amber : AppColors.textSlate400),
                      _devRow(
                          'Night Prayer Badge (Evening/Sleep ≥ 18h)',
                          nightPrayer ? '🏅 UNLOCKED' : '🔒 Locked',
                          valueColor:
                              nightPrayer ? Colors.amber : AppColors.textSlate400),
                      const SizedBox(height: 8),
                      Text('── Per Category ──',
                          style: AppText.label(
                              color: AppColors.textSlate400)),
                      const SizedBox(height: 4),
                      ...categories.map((cat) {
                        final done = dp.getCategoryCompletedCount(cat);
                        final total = dp.getCategoryTotalCount(cat);
                        final pct = total > 0
                            ? (done / total * 100).round()
                            : 0;
                        return _devRow(
                            cat.name.toUpperCase(),
                            '$done/$total ($pct%)',
                            valueColor: done == total && total > 0
                                ? Colors.green
                                : AppColors.textSlate400);
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── RESET ACTIONS ─────────────────────────────────────────
                _devSection(
                  icon: Icons.refresh_rounded,
                  label: 'RESET ACTIONS',
                  color: Colors.redAccent,
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon:
                              const Icon(Icons.today_rounded, size: 18),
                          label:
                              const Text('Reset Today\'s Counts Only'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orangeAccent,
                            side: const BorderSide(
                                color: Colors.orangeAccent),
                            padding:
                                const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            dp.resetAll();
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    '✅ Today\'s counts reset (streak kept)'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.delete_forever_rounded,
                              size: 18),
                          label: const Text(
                              '⚠️ FULL RESET (Streak + Badges + All History)'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(
                                color: Colors.redAccent),
                            padding:
                                const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: ctx,
                              builder: (c) => AlertDialog(
                                backgroundColor: AppColors.bgTeal,
                                title: const Text('Full Reset?',
                                    style: TextStyle(color: Colors.white)),
                                content: const Text(
                                    'This will wipe ALL progress: streak, badges, all daily history. Cannot be undone.',
                                    style:
                                        TextStyle(color: Colors.white70)),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(c, false),
                                      child: const Text('Cancel')),
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(c, true),
                                      child: const Text('YES, RESET ALL',
                                          style: TextStyle(
                                              color: Colors.redAccent))),
                                ],
                              ),
                            );
                            if (confirm == true && ctx.mounted) {
                              await dp.devResetAllProgress();
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('🗑️ Full progress reset done'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── HOW PROGRESS WORKS ────────────────────────────────────
                _devSection(
                  icon: Icons.info_outline_rounded,
                  label: 'HOW PROGRESS WORKS',
                  color: Colors.blueAccent,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _rule('🔥 Streak',
                          'Increments when any category is fully completed. +1 per day (not per category). Resets to 1 if a day is missed.'),
                      _rule('🏅 Early Bird Badge',
                          'Unlock: Complete Morning adhkar BEFORE 11:00 AM. One-time — never revokes.'),
                      _rule('🌙 Night Prayer Badge',
                          'Unlock: Complete Before Sleep OR Evening adhkar AFTER 18:00 (6 PM). One-time.'),
                      _rule('📊 Monthly Heatmap',
                          'Color = total dhikr taps that day. Stored in SharedPreferences key: daily_YYYY-MM-DD.'),
                      _rule('☁️ Cloud Sync',
                          'Streak + badges saved to Firestore (users/{uid}/progress/data) when logged in. Merge rule: keep highest streak, never revoke badges.'),
                      _rule('🔄 Daily Reset',
                          'All counts reset to 0 on midnight when app opens. Detected via last_reset_date key in SharedPreferences.'),
                      _rule('💎 Pro Access',
                          'isPro = true when active_subscription_id key exists in SharedPreferences. Pro unlocks: Custom Plan screen, cloud plan sync.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _devSection({
    required IconData icon,
    required String label,
    required Color color,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: AppText.label(color: color)
                    .copyWith(fontSize: 11, letterSpacing: 1.2)),
          ]),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _devRow(String label, String value,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: AppText.body(color: AppColors.textSlate400)
                      .copyWith(fontSize: 12))),
          Text(value,
              style: AppText.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: valueColor ?? AppColors.textPrimary)
                  .copyWith()),
        ],
      ),
    );
  }

  Widget _rule(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: AppText.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(desc,
              style: AppText.body(color: AppColors.textSlate400)
                  .copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}

