import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/user_provider.dart';
import '../providers/dhikr_provider.dart';
import '../providers/language_provider.dart';
import '../constants/app_theme.dart';
import '../utils/responsive.dart';
// dashboard_screen import removed — overlay now dismisses in-place, not navigates

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});
  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  // True until the user taps "Got it" for the first time.
  bool _showNote = false;

  @override
  void initState() {
    super.initState();
    _checkNote();
  }

  Future<void> _checkNote() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('progress_note_seen') ?? false;
    if (!seen && mounted) setState(() => _showNote = true);
  }

  Future<void> _dismissNote() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('progress_note_seen', true);
    if (mounted) setState(() => _showNote = false);
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);

    final lp = Provider.of<LanguageProvider>(context);
    final user = Provider.of<UserProvider>(context);
    final dhikr = Provider.of<DhikrProvider>(context);

    final name = (user.userName?.isNotEmpty == true)
        ? user.userName!
        : lp.getText('guest_user');
    final initials = name
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    final total = dhikr.totalDhikrCount;
    final streak = dhikr.streakDays;
    final sets = dhikr.completedSets;
    final week = dhikr.weeklyActivity;
    final langCode = lp.locale.languageCode;
    final rawMax = week.fold(0, (a, b) => a > b ? a : b);
    final maxW = rawMax == 0 ? 1 : rawMax;

    // Responsive sizes
    final avatarSize = R.adaptive(90.0, 110.0, 140.0);
    final avatarFont = R.adaptive(24.0, 30.0, 40.0);
    final nameSize = R.adaptive(18.0, 22.0, 28.0);
    final hPad = R.adaptive(16.0, 24.0, 32.0);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Container(
        decoration: AppDeco.radialBg(),
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    backgroundColor: AppColors.bgDark.withOpacity(0.85),
                    pinned: true,
                    elevation: 0,
                    flexibleSpace: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child:
                            Container(color: AppColors.bgDark.withOpacity(0.5)),
                      ),
                    ),
                    title: Text(lp.getText('profile'),
                        style: AppText.heading(R.adaptive(18, 20, 24))),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: R.px(120)),
                      child: Column(children: [
                        // ── Avatar ──────────────────────────────────────────────
                        Padding(
                          padding: EdgeInsets.all(R.px(24)),
                          child: Column(children: [
                            Stack(
                                alignment: Alignment.center,
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: avatarSize,
                                    height: avatarSize,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.primary.withOpacity(0.1),
                                      border: Border.all(
                                          color: AppColors.primary, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                            color: AppColors.primary
                                                .withOpacity(0.3),
                                            blurRadius: 20)
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                        initials.isEmpty ? '?' : initials,
                                        style: AppText.manrope(
                                            fontSize: avatarFont,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.primary)),
                                  ),
                                ]),
                            SizedBox(height: R.px(14)),
                            Text(name, style: AppText.heading(nameSize)),
                            SizedBox(height: R.px(4)),
                            Text(lp.getText('active_member'),
                                style: AppText.body(
                                    color: AppColors.textSlate400)),
                          ]),
                        ),

                        // ── Stats ────────────────────────────────────────────────
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: hPad),
                          child: Row(children: [
                            _Stat(
                                R.localizeDigits(_fmt(total), langCode),
                                lp.getText('total_dhikr').toUpperCase(),
                                AppColors.primary),
                            SizedBox(width: R.px(10)),
                            _Stat(
                                R.localizeDigits('$sets', langCode),
                                lp.getText('sets_done').toUpperCase(),
                                AppColors.textPrimary),
                            SizedBox(width: R.px(10)),
                            _Stat(
                                R.localizeDigits('$streak', langCode),
                                lp.getText('day_streak').toUpperCase(),
                                const Color(0xFF10B981)),
                          ]),
                        ),

                        SizedBox(height: R.px(24)),

                        // ── Achievements ─────────────────────────────────────────
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: hPad),
                          child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(lp.getText('achievements'),
                                  style:
                                      AppText.heading(R.adaptive(16, 18, 22)))),
                        ),
                        SizedBox(height: R.px(12)),
                        SizedBox(
                          height: R.adaptive(100.0, 120.0, 140.0),
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.symmetric(horizontal: hPad),
                            physics: const BouncingScrollPhysics(),
                            children: [
                              _Badge(Icons.workspace_premium,
                                  lp.getText('badge_7day_streak'), streak >= 7),
                              SizedBox(width: R.px(14)),
                              _Badge(Icons.stars,
                                  lp.getText('badge_1k_adhkar'), total >= 1000),
                              SizedBox(width: R.px(14)),
                              _Badge(Icons.wb_sunny,
                                  lp.getText('badge_early_bird'), false),
                              SizedBox(width: R.px(14)),
                              _Badge(Icons.nightlight_round,
                                  lp.getText('badge_night_prayer'), false),
                              SizedBox(width: R.px(14)),
                              _Badge(Icons.favorite,
                                  lp.getText('badge_generous_donor'),
                                  user.hasDonated),
                            ],
                          ),
                        ),

                        SizedBox(height: R.px(24)),

                        // ── Activity chart ───────────────────────────────────────
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: hPad),
                          child: Container(
                            padding: EdgeInsets.all(R.px(18)),
                            decoration: AppDeco.glassCard(
                                borderRadius: BorderRadius.circular(R.px(16))),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                  lp
                                                      .getText('total_dhikr')
                                                      .toUpperCase(),
                                                  style: AppText.label()),
                                              SizedBox(height: R.px(4)),
                                              Text(
                                                  R.localizeDigits(NumberFormat('#,###').format(total), langCode),
                                                  style:
                                                      AppText.manrope(
                                                          fontSize: R.adaptive(
                                                              20, 24, 30),
                                                          fontWeight:
                                                              FontWeight.w800)),
                                            ]),
                                        Container(
                                          padding: EdgeInsets.all(R.px(8)),
                                          decoration: BoxDecoration(
                                              color: AppColors.primary
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      R.px(8))),
                                          child: Icon(Icons.analytics,
                                              color: AppColors.primary,
                                              size: R.sp(20)),
                                        ),
                                      ]),
                                  SizedBox(height: R.px(16)),
                                  SizedBox(
                                    height: R.adaptive(60.0, 72.0, 90.0),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: List.generate(week.length, (i) {
                                        final ratio =
                                            maxW > 0 ? week[i] / maxW : 0.05;
                                        final isToday = i == week.length - 1;
                                        return Expanded(
                                            child: Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: R.px(2)),
                                          child: FractionallySizedBox(
                                            heightFactor:
                                                ratio.clamp(0.05, 1.0),
                                            alignment: Alignment.bottomCenter,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: isToday
                                                    ? AppColors.primary
                                                    : AppColors.primary
                                                        .withOpacity(0.3),
                                                borderRadius:
                                                    const BorderRadius.vertical(
                                                        top:
                                                            Radius.circular(3)),
                                              ),
                                            ),
                                          ),
                                        ));
                                      }),
                                    ),
                                  ),
                                  SizedBox(height: R.px(16)),
                                  Container(
                                    padding: EdgeInsets.all(R.px(10)),
                                    decoration: BoxDecoration(
                                        color:
                                            AppColors.primary.withOpacity(0.05),
                                        borderRadius:
                                            BorderRadius.circular(R.px(8)),
                                        border: Border.all(
                                            color: AppColors.primary
                                                .withOpacity(0.15))),
                                    child: Row(children: [
                                      Icon(Icons.local_fire_department,
                                          color: AppColors.primary,
                                          size: R.sp(17)),
                                      SizedBox(width: R.px(8)),
                                      Expanded(
                                          child: Text(
                                              '${R.localizeDigits('$streak', langCode)} ${lp.getText('day_streak')} — ${lp.getText('keep_it_going')}',
                                              style: AppText.body(
                                                      color: AppColors
                                                          .textSlate300)
                                                  .copyWith(
                                                      fontSize: R.sp(R.adaptive(
                                                          11, 13, 15))),
                                              overflow: TextOverflow.ellipsis)),
                                    ]),
                                  ),
                                ]),
                          ),
                        ),
                        SizedBox(height: R.px(24)),

                        // ── Milestones ───────────────────────────────────────────
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: hPad),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(lp.getText('milestones'),
                                    style: AppText.heading(
                                        R.adaptive(16, 18, 22))),
                                SizedBox(height: R.px(14)),
                                if (user.hasDonated)
                                  _Mile(
                                      Icons.favorite,
                                      const Color(0xFFF43F5E),
                                      lp.getText('milestone_patron_title'),
                                      lp.getText('milestone_patron_desc')),
                                if (total >= 1000)
                                  _Mile(
                                      Icons.emoji_events,
                                      AppColors.primary,
                                      lp.getText('milestone_bronze_title'),
                                      lp.getText('milestone_bronze_desc')),
                                if (total >= 10000)
                                  _Mile(
                                      Icons.workspace_premium,
                                      const Color(0xFF94A3B8),
                                      lp.getText('milestone_silver_title'),
                                      lp.getText('milestone_silver_desc')),
                                if (streak >= 7)
                                  _Mile(
                                      Icons.calendar_month,
                                      const Color(0xFF10B981),
                                      lp.getText('milestone_weekly_title'),
                                      lp.getText('milestone_weekly_desc')),
                                if (streak >= 30)
                                  _Mile(
                                      Icons.star,
                                      const Color(0xFFF59E0B),
                                      lp.getText('milestone_consistency_title'),
                                      lp.getText('milestone_consistency_desc')),
                                if (total < 1000)
                                  _Mile(
                                      Icons.flag_outlined,
                                      AppColors.textSlate400,
                                      lp.getText('milestone_first_title'),
                                      lp.getText('milestone_first_desc')),
                              ]),
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
              // ── One-time "Note on Progress" overlay ─────────────────────────
              // Shown only on the first ever visit. After the user taps
              // "Got it" it is stored in SharedPreferences and never shown again.
              if (_showNote)
                Positioned.fill(
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                      child: Container(
                        color: AppColors.shadow(0.5),
                        padding: EdgeInsets.all(R.px(24)),
                        alignment: Alignment.center,
                        child: Container(
                          padding: EdgeInsets.all(R.px(24)),
                          decoration: AppDeco.glassCard(
                            borderRadius: BorderRadius.circular(R.px(20)),
                          ).copyWith(
                            color: AppColors.bgDark.withOpacity(0.92),
                            border: Border.all(
                                color: AppColors.primary.withOpacity(0.3)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.favorite,
                                  color: AppColors.primary, size: R.sp(40)),
                              SizedBox(height: R.px(16)),
                              Text(
                                lp.getText('note_on_progress'),
                                style: AppText.heading(R.adaptive(18, 20, 24)),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: R.px(16)),
                              Text(
                                lp.getText('progress_philosophy'),
                                style: AppText.body(color: AppColors.textSlate300)
                                    .copyWith(
                                  fontSize: R.sp(R.adaptive(12, 14, 15)),
                                  height: 1.6,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: R.px(24)),
                              // "Got it" — dismisses permanently
                              GestureDetector(
                                onTap: _dismissNote,
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.symmetric(vertical: R.px(14)),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(R.px(12)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withOpacity(0.3),
                                        blurRadius: 12,
                                      )
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      lp.getText('done'),
                                      style: AppText.manrope(
                                        fontSize: R.sp(14),
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmt(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';
}

class _Stat extends StatelessWidget {
  final String value, label;
  final Color color;
  const _Stat(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Expanded(
          child: Container(
        padding: EdgeInsets.all(R.px(10)),
        decoration:
            AppDeco.glassCard(borderRadius: BorderRadius.circular(R.px(12))),
        child: Column(children: [
          Text(value,
              style: AppText.manrope(
                  fontSize: R.adaptive(16, 18, 22),
                  fontWeight: FontWeight.w800,
                  color: color)),
          SizedBox(height: R.px(4)),
          Text(label, style: AppText.label(), textAlign: TextAlign.center),
        ]),
      ));
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool unlocked;
  const _Badge(this.icon, this.title, this.unlocked);
  @override
  Widget build(BuildContext context) {
    final size = R.adaptive(60.0, 68.0, 80.0);
    return Opacity(
      opacity: unlocked ? 1.0 : 0.4,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.ink(0.03),
            border: Border.all(
                color: unlocked
                    ? AppColors.primary.withOpacity(0.4)
                    : AppColors.ink(0.1)),
            boxShadow: unlocked
                ? [
                    BoxShadow(
                        color: AppColors.primary.withOpacity(0.25),
                        blurRadius: 10)
                  ]
                : [],
          ),
          child: Icon(icon,
              color: unlocked ? AppColors.primary : AppColors.textSlate500,
              size: R.sp(R.adaptive(24, 28, 34))),
        ),
        SizedBox(height: R.px(7)),
        SizedBox(
            width: size + 8,
            child: Text(title,
                style: AppText.manrope(
                    fontSize: R.adaptive(9, 10, 12),
                    fontWeight: FontWeight.w600,
                    color: unlocked ? AppColors.textPrimary : AppColors.textSlate500),
                textAlign: TextAlign.center)),
      ]),
    );
  }
}

class _Mile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  const _Mile(this.icon, this.color, this.title, this.subtitle);
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: R.px(10)),
        child: Container(
          padding: EdgeInsets.all(R.px(14)),
          decoration:
              AppDeco.glassCard(borderRadius: BorderRadius.circular(R.px(12))),
          child: Row(children: [
            Container(
                width: R.sp(38),
                height: R.sp(38),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.15), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: R.sp(18))),
            SizedBox(width: R.px(14)),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: AppText.manrope(
                          fontSize: R.adaptive(12, 13, 15),
                          fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style: AppText.body(color: AppColors.textSlate400)
                          .copyWith(fontSize: R.sp(R.adaptive(10, 12, 14)))),
                ])),
          ]),
        ),
      );
}
