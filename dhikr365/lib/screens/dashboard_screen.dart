import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../providers/language_provider.dart';
import '../utils/responsive.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'prayer_times_screen.dart';
import 'progress_screen.dart';
import 'dua_screen.dart';
import 'qibla_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    PrayerTimesScreen(),
    DuaScreen(),
    QiblaScreen(),
    ProgressScreen(),
    SettingsScreen(),
  ];

  static const _navIcons = [
    Icons.home_filled,
    Icons.access_time_filled,
    Icons.menu_book,
    Icons.explore, // Qibla compass
    Icons.bar_chart,
    Icons.settings,
  ];

  static const _navKeys = [
    'nav_home',
    'nav_prayer',
    'nav_dua',
    'nav_qibla',
    'nav_progress',
    'nav_settings',
  ];

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final lp = Provider.of<LanguageProvider>(context);

    // Bottom nav height adapts to screen
    final navBottom = R.adaptive(20.0, 28.0, 36.0);
    final navTop = R.px(10);
    final iconSize = R.sp(R.adaptive(20.0, 22.0, 26.0));
    final labelSize = R.sp(R.adaptive(8.0, 9.0, 11.0));

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.bgDark,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: EdgeInsets.only(
                top: navTop, bottom: navBottom, left: R.px(6), right: R.px(6)),
            decoration: BoxDecoration(
              color: AppColors.bgDark.withValues(alpha: 0.92),
              border: Border(top: BorderSide(color: AppColors.ink(0.05))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_navIcons.length, (i) {
                final selected = i == _currentIndex;
                return GestureDetector(
                  onTap: () => setState(() => _currentIndex = i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(
                        horizontal: R.px(10), vertical: R.px(6)),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(R.px(12)),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_navIcons[i],
                          color: selected
                              ? AppColors.primary
                              : AppColors.textSlate400,
                          size: iconSize),
                      SizedBox(height: R.px(3)),
                      Text(
                        lp.getText(_navKeys[i]).toUpperCase(),
                        style: AppText.manrope(
                          fontSize: labelSize,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? AppColors.primary
                              : AppColors.textSlate500,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ]),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
