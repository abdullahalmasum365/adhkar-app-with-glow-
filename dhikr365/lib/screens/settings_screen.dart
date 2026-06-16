import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
import '../providers/dhikr_provider.dart';
import '../providers/user_provider.dart';
import '../constants/app_theme.dart';
import '../utils/responsive.dart';
import 'edit_profile_screen.dart';
import 'splash_screen.dart';
import '../providers/notification_provider.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
        decoration: const BoxDecoration(
          color: AppColors.bgTeal,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
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
                        color: sel ? AppColors.primary : Colors.white24,
                        fontSize: 16)),
                title: Text(lang['nativeName']!,
                    style: AppText.manrope(
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                        color: sel ? Colors.white : Colors.white70)),
                subtitle: Text(lang['name']!,
                    style: AppText.body(color: Colors.white38)),
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

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final lp = Provider.of<LanguageProvider>(context);
    final tp = Provider.of<ThemeProvider>(context);
    final up = Provider.of<UserProvider>(context);
    final np = Provider.of<NotificationProvider>(context);

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
                          color: AppColors.primary.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.primary.withOpacity(0.3))),
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
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(lp.getText('edit'),
                            style: AppText.body(color: AppColors.primary))),
                  ),
                ]),
              )),
              const SizedBox(height: 22),

              // ── Notifications ──
              _Lbl(lp.getText('notifications')),
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
                          await lp.setLanguage(c);
                          if (context.mounted) {
                            await Provider.of<DhikrProvider>(context,
                                    listen: false)
                                .reloadDhikrs(
                                    uiLanguageCode: c,
                                    transliterationCode: lp.transliterationCode,
                                    translationCode: lp.translationCode);
                          }
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

              // ── Test Notification ──
              _Card(
                child: _Tile(
                  icon: Icons.notifications_active,
                  color: Colors.greenAccent,
                  title: 'Test Notification',
                  subtitle: 'Send one now to verify notifications work',
                  onTap: () async {
                    try {
                      await NotificationService().showInstantTestNotification();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Notification sent — check your notification bar'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
              const SizedBox(height: 22),

              // ── Appearance ──
              _Lbl(lp.getText('appearance')),
              _Card(
                child: Column(children: [
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
                ]),
              ),
              const SizedBox(height: 22),

              // ── Footer ──
              _Card(
                  child: Column(children: [
                _Tile(
                    icon: Icons.policy_outlined,
                    color: AppColors.textSlate400,
                    title: lp.getText('privacy_policy'),
                    onTap: () {}),
                _div(),
                _Tile(
                    icon: Icons.logout,
                    color: Colors.redAccent,
                    title: lp.getText('logout'),
                    titleColor: Colors.redAccent,
                    onTap: _logout),
              ])),
              const SizedBox(height: 14),
              Center(
                  child: Text('${lp.getText('version').toUpperCase()} 1.0.0',
                      style: AppText.label(color: AppColors.textSlate500))),
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
      color: Colors.white.withOpacity(0.05),
      indent: 14,
      endIndent: 14);
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
          color: color.withOpacity(0.1),
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
                color: titleColor ?? Colors.white)),
        subtitle: subtitle != null
            ? Text(subtitle!,
                style: AppText.body(color: AppColors.textSlate400)
                    .copyWith(fontSize: 12))
            : null,
        trailing: trailing ??
            (onTap != null
                ? const Icon(Icons.chevron_right,
                    color: AppColors.textSlate500, size: 20)
                : null),
        onTap: onTap,
      );
}
