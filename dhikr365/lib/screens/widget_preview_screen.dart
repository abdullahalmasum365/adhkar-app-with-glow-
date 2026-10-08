// ============================================================================
// lib/screens/widget_preview_screen.dart
//
// UNIVERSAL MULTI-THEME HOME SCREEN WIDGET PREVIEW & SETUP SCREEN
//
// Allows users to preview all 4 widgets (6 layout variants) rendered in
// the active theme's colors, pin them directly to their launcher via
// HomeWidget.requestPinWidget(), and view step-by-step setup guides.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';

import '../constants/app_theme.dart';
import '../providers/language_provider.dart';
import '../providers/theme_provider.dart';
import '../services/widget_service.dart';
import '../utils/responsive.dart';

class WidgetPreviewScreen extends StatefulWidget {
  const WidgetPreviewScreen({super.key});

  @override
  State<WidgetPreviewScreen> createState() => _WidgetPreviewScreenState();
}

class _WidgetPreviewScreenState extends State<WidgetPreviewScreen> {
  bool _pinSupported = false;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _checkPinSupport();
  }

  Future<void> _checkPinSupport() async {
    try {
      final supported = await HomeWidget.isRequestPinWidgetSupported() ?? false;
      if (mounted) {
        setState(() => _pinSupported = supported);
      }
    } catch (e) {
      debugPrint('[WidgetPreviewScreen] checkPinSupport error: $e');
    }
  }

  Future<void> _pinWidget(String androidName, String title) async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final isBn = lp.locale.languageCode == 'bn';

    try {
      if (_pinSupported) {
        await HomeWidget.requestPinWidget(androidName: androidName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              content: Text(
                isBn
                    ? 'হোম স্ক্রিনে পিন করার অনুরোধ পাঠানো হয়েছে!'
                    : 'Pin request sent to your home screen launcher!',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          );
        }
      } else {
        _showManualAddDialog(title);
      }
    } catch (e) {
      debugPrint('[WidgetPreviewScreen] pinWidget error: $e');
      _showManualAddDialog(title);
    }
  }

  void _showManualAddDialog(String title) {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final isBn = lp.locale.languageCode == 'bn';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.widgets_rounded, color: AppColors.primary, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isBn ? 'হোম স্ক্রিনে উইজেট যোগ করুন' : 'Add Widget Manually',
                style: AppText.heading(16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isBn
                  ? 'আপনার লঞ্চার সরাসরি পিন সমর্থন না করলে নিচের সহজ নিয়মে উইজেট যোগ করতে পারেন:'
                  : 'If 1-tap pin is not supported by your launcher, follow these easy steps:',
              style: AppText.body(color: AppColors.textSlate300)
                  .copyWith(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 14),
            _guideStep(
              '1',
              isBn
                  ? 'হোম স্ক্রিনের ফাঁকা জায়গায় ২ সেকেন্ড চেপে ধরে রাখুন।'
                  : 'Long press on any empty space on your home screen.',
            ),
            _guideStep(
              '2',
              isBn
                  ? 'নিচ থেকে "Widgets" বা "উইজেটস" অপশন সিলেক্ট করুন।'
                  : 'Tap the "Widgets" option at the bottom menu.',
            ),
            _guideStep(
              '3',
              isBn
                  ? 'তালিকায় "Adhkaar 365" খুঁজে বের করুন।'
                  : 'Find "Adhkaar 365" in the apps list.',
            ),
            _guideStep(
              '4',
              isBn
                  ? '"$title" উইজেটটি টেনে এনে আপনার স্ক্রিনে বসান।'
                  : 'Drag "$title" and place it onto your home screen.',
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              isBn ? 'বুঝেছি' : 'Got it',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _guideStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 1.2),
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppText.body(color: AppColors.textSlate400)
                  .copyWith(fontSize: 12.5, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshAll() async {
    setState(() => _isRefreshing = true);
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final tp = Provider.of<ThemeProvider>(context, listen: false);

    await WidgetService().updateTheme(tp.activePalette);
    await WidgetService().updateAllWidgets();

    if (mounted) {
      setState(() => _isRefreshing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Text(
            lp.locale.languageCode == 'bn'
                ? '✅ সকল উইজেট নতুন থিমের রঙে আপডেট হয়েছে!'
                : '✅ All widgets updated with active theme colors!',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final lp = Provider.of<LanguageProvider>(context);
    final tp = Provider.of<ThemeProvider>(context);
    final isBn = lp.locale.languageCode == 'bn';
    final palette = tp.activePalette;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Container(
        decoration: AppDeco.radialBg(center: Alignment.topLeft),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isBn
                                ? 'হোম স্ক্রিন উইজেট'
                                : 'Home Screen Widgets',
                            style: AppText.heading(18),
                          ),
                          Text(
                            isBn
                                ? 'লঞ্চারে জীবন্ত আযকার ও সালাহ ট্র্যাকিং'
                                : 'Live prayer & adhkar tracking on your launcher',
                            style: AppText.body(color: AppColors.textSlate400)
                                .copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: _isRefreshing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.sync_rounded,
                              color: Colors.white, size: 22),
                      tooltip: isBn ? 'রিফ্রেশ করুন' : 'Refresh widgets',
                      onPressed: _isRefreshing ? null : _refreshAll,
                    ),
                  ],
                ),
              ),

              // Active Theme Indicator Banner
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: palette.bgDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: palette.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: palette.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: palette.primary.withValues(alpha: 0.5),
                            blurRadius: 6,
                          )
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isBn
                            ? 'বর্তমান থিম: ${palette.label} (উইজেট স্বয়ংক্রিয়ভাবে মানিয়ে নিবে)'
                            : 'Active Palette: ${palette.label} (Widgets adapt automatically)',
                        style: AppText.manrope(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: palette.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),

              // Widget Previews List
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    // 1. Prayer Countdown (4x2 Medium)
                    _WidgetPreviewCard(
                      title: isBn
                          ? '১. নামাজের কাউন্টডাউন (৪×২ মিডিয়াম)'
                          : '1. Prayer Countdown (4x2 Medium)',
                      subtitle: isBn
                          ? 'বর্তমান ওয়াক্ত, পরবর্তী সালাত, লাইভ কাউন্টডাউন ও ৫ ওয়াক্তের সময়সূচি'
                          : 'Current waqt, next prayer, live countdown, & daily prayer times',
                      onPin: () => _pinWidget(
                        WidgetService.prayerCountdownWidget,
                        isBn ? 'নামাজের কাউন্টডাউন' : 'Prayer Countdown',
                      ),
                      previewWidget: _MockPrayerCountdownWidget(palette: palette),
                    ),

                    const SizedBox(height: 20),

                    // 2. Prayer Compact (2x2 Compact)
                    _WidgetPreviewCard(
                      title: isBn
                          ? '২. নামাজের কম্প্যাক্ট উইজেট (২×২)'
                          : '2. Prayer Compact (2x2)',
                      subtitle: isBn
                          ? 'ছোট সাইজের মিনিমালিস্ট পরবর্তী নামাজের অ্যালার্ট'
                          : 'Minimalist compact card with next prayer & countdown',
                      onPin: () => _pinWidget(
                        WidgetService.prayerCompactWidget,
                        isBn ? 'নামাজের কম্প্যাক্ট' : 'Prayer Compact',
                      ),
                      previewWidget: _MockPrayerCompactWidget(palette: palette),
                    ),

                    const SizedBox(height: 20),

                    // 3. Adhkar Tracker (4x2 Medium)
                    _WidgetPreviewCard(
                      title: isBn
                          ? '৩. ডেইলি আযকার ও স্ট্রিক (৪×২ মিডিয়াম)'
                          : '3. Daily Adhkar & Streak (4x2 Medium)',
                      subtitle: isBn
                          ? 'সকাল-সন্ধ্যার আযকার অগ্রগতি বার ও স্ট্রিক কাউন্টার'
                          : 'Dual morning/evening progress bars and active streak counter',
                      onPin: () => _pinWidget(
                        WidgetService.adhkarTrackerWidget,
                        isBn ? 'ডেইলি আযকার ট্র্যাকার' : 'Daily Adhkar Tracker',
                      ),
                      previewWidget: _MockAdhkarTrackerWidget(palette: palette),
                    ),

                    const SizedBox(height: 20),

                    // 4. Adhkar Tracker Small (2x2 Small)
                    _WidgetPreviewCard(
                      title: isBn
                          ? '৪. আযকার ট্র্যাকার মিনি (২×২)'
                          : '4. Adhkar Tracker Small (2x2)',
                      subtitle: isBn
                          ? 'বড় স্ট্রিক ব্যাজ ও আজ সকাল/সন্ধ্যার কমপ্লিশন স্টেটাস'
                          : 'Bold streak counter with morning & evening completion check',
                      onPin: () => _pinWidget(
                        WidgetService.adhkarTrackerSmallWidget,
                        isBn ? 'আযকার মিনি ট্র্যাকার' : 'Adhkar Mini Tracker',
                      ),
                      previewWidget:
                          _MockAdhkarTrackerSmallWidget(palette: palette),
                    ),

                    const SizedBox(height: 20),

                    // 5. Dua / Ayah of the Day (4x2 Medium)
                    _WidgetPreviewCard(
                      title: isBn
                          ? '৫. আজকের নির্বাচিত দু\'আ (৪×২ মিডিয়াম)'
                          : '5. Dua / Ayah of the Day (4x2)',
                      subtitle: isBn
                          ? 'প্রতিদিন সকালে হাদিস ও কুরআনের নির্বাচিত দু\'আ ও অনুবাদ'
                          : 'Daily authentic Hadith & Quranic supplication with translation',
                      onPin: () => _pinWidget(
                        WidgetService.duaOfTheDayWidget,
                        isBn ? 'আজকের দু\'আ' : 'Dua of the Day',
                      ),
                      previewWidget: _MockDuaOfDayWidget(palette: palette),
                    ),

                    const SizedBox(height: 20),

                    // 6. One-Tap Quick Tasbih (2x2 Small)
                    _WidgetPreviewCard(
                      title: isBn
                          ? '৬. এক-ট্যাপ কুইক তাসবীহ (২×২)'
                          : '6. One-Tap Quick Tasbih (2x2)',
                      subtitle: isBn
                          ? 'অ্যাপ ওপেন না করেই হোম স্ক্রিন থেকে সরাসরি তাসবীহ কাউন্ট করুন!'
                          : 'Count dhikr directly on your home screen without opening the app!',
                      onPin: () => _pinWidget(
                        WidgetService.tasbihWidget,
                        isBn ? 'এক-ট্যাপ তাসবীহ' : 'One-Tap Tasbih',
                      ),
                      previewWidget: _MockTasbihWidget(palette: palette),
                    ),

                    const SizedBox(height: 28),

                    // Setup Instructions Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.ink(0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.ink(0.08)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.touch_app_rounded,
                                  color: Colors.amberAccent, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                isBn
                                    ? 'লঞ্চার থেকে ম্যানুয়ালি যেভাবে বসাবেন'
                                    : 'How to add widgets manually',
                                style: AppText.heading(14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _guideStep(
                            '১',
                            isBn
                                ? 'হোম স্ক্রিনের ফাঁকা স্থানে কিছুক্ষণ চেপে ধরে রাখুন।'
                                : 'Long press on any empty space on your launcher.',
                          ),
                          _guideStep(
                            '২',
                            isBn
                                ? '"Widgets" বা "উইজেটস" অপশন ট্যাপ করুন।'
                                : 'Select "Widgets" from the bottom menu.',
                          ),
                          _guideStep(
                            '৩',
                            isBn
                                ? '"Adhkaar 365" খুঁজুন এবং পছন্দের সাইজটি স্ক্রিনে রাখুন।'
                                : 'Find "Adhkaar 365" and drag your desired layout.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD CONTAINER FOR EACH WIDGET PREVIEW
// ─────────────────────────────────────────────────────────────────────────────
class _WidgetPreviewCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onPin;
  final Widget previewWidget;

  const _WidgetPreviewCard({
    required this.title,
    required this.subtitle,
    required this.onPin,
    required this.previewWidget,
  });

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);
    final isBn = lp.locale.languageCode == 'bn';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.ink(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.ink(0.08)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppText.manrope(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppText.body(color: AppColors.textSlate400)
                          .copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_to_home_screen_rounded, size: 16),
                label: Text(
                  isBn ? 'পিন করুন' : 'Pin',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                onPressed: onPin,
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Visual Mockup Container
          Center(
            child: previewWidget,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. MOCK: Prayer Countdown (4x2 Medium)
// ─────────────────────────────────────────────────────────────────────────────
class _MockPrayerCountdownWidget extends StatelessWidget {
  final AppPalette palette;
  const _MockPrayerCountdownWidget({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.bgDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.glassBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.location_on_rounded,
                      size: 13, color: palette.textSlate400),
                  const SizedBox(width: 4),
                  Text(
                    'DHAKA, BANGLADESH',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: palette.textSlate400,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: palette.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'ASR WAQT',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: palette.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Next Prayer Countdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Maghrib in 48m',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Next: Maghrib at 05:42 PM',
                    style: TextStyle(
                      fontSize: 11,
                      color: palette.textSlate400,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: palette.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.wb_twilight_rounded,
                    color: Colors.white, size: 16),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: 0.65,
              minHeight: 5,
              backgroundColor: palette.surfaceElevated,
              valueColor: AlwaysStoppedAnimation<Color>(palette.primary),
            ),
          ),

          const SizedBox(height: 12),

          // 5 Prayers Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: palette.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _prayerItem('FAJR', '04:45', false, palette),
                _prayerItem('DHUHR', '11:55', false, palette),
                _prayerItem('ASR', '03:15', true, palette),
                _prayerItem('MAGHRIB', '05:42', false, palette),
                _prayerItem('ISHA', '07:05', false, palette),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _prayerItem(
      String name, String time, bool isCurrent, AppPalette palette) {
    return Column(
      children: [
        Text(
          name,
          style: TextStyle(
            fontSize: 8.5,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
            color: isCurrent ? palette.primary : palette.textSlate400,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          time,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: isCurrent ? palette.primary : palette.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. MOCK: Prayer Compact (2x2 Compact)
// ─────────────────────────────────────────────────────────────────────────────
class _MockPrayerCompactWidget extends StatelessWidget {
  final AppPalette palette;
  const _MockPrayerCompactWidget({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 155,
      height: 155,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.bgDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.glassBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.mosque_rounded, size: 18, color: palette.primary),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: palette.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'NEXT',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: palette.primary,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MAGHRIB',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '05:42 PM',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: palette.primary,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: palette.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.hourglass_top_rounded,
                    size: 11, color: palette.textSlate400),
                const SizedBox(width: 4),
                Text(
                  'in 48m',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: palette.textSlate400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. MOCK: Daily Adhkar Tracker (4x2 Medium)
// ─────────────────────────────────────────────────────────────────────────────
class _MockAdhkarTrackerWidget extends StatelessWidget {
  final AppPalette palette;
  const _MockAdhkarTrackerWidget({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.bgDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.glassBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Streak
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DAILY ADHKAAR',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: palette.textSlate400,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '🔥 7-DAY STREAK',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: palette.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Morning Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('🌅 Morning Adhkar',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary)),
              Text('✓ 18/18 Done',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: palette.primary)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 1.0,
              minHeight: 5,
              backgroundColor: palette.surfaceElevated,
              valueColor: AlwaysStoppedAnimation<Color>(palette.primary),
            ),
          ),

          const SizedBox(height: 10),

          // Evening Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('🌆 Evening Adhkar',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary)),
              Text('6/16 In Progress',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: palette.textSlate400)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 0.38,
              minHeight: 5,
              backgroundColor: palette.surfaceElevated,
              valueColor: AlwaysStoppedAnimation<Color>(palette.accent),
            ),
          ),

          const SizedBox(height: 12),

          // Hadith Quote
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: palette.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.format_quote_rounded,
                    size: 13, color: palette.accent),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '“Remember Allah in prosperity; He remembers you in adversity.”',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontStyle: FontStyle.italic,
                      color: palette.textSlate400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. MOCK: Adhkar Tracker Small (2x2 Small)
// ─────────────────────────────────────────────────────────────────────────────
class _MockAdhkarTrackerSmallWidget extends StatelessWidget {
  final AppPalette palette;
  const _MockAdhkarTrackerSmallWidget({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 155,
      height: 155,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.bgDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.glassBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.local_fire_department_rounded,
                  size: 20, color: palette.accent),
              Text(
                '7',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: palette.accent,
                ),
              ),
            ],
          ),
          Text(
            'DAYS STREAK',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: palette.textSlate400,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: palette.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text('🌅 ✓',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: palette.primary)),
                Container(
                    width: 1, height: 12, color: palette.glassBorder),
                Text('🌆 ⏳',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: palette.textSlate400)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. MOCK: Dua of the Day (4x2 Medium)
// ─────────────────────────────────────────────────────────────────────────────
class _MockDuaOfDayWidget extends StatelessWidget {
  final AppPalette palette;
  const _MockDuaOfDayWidget({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.bgDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.glassBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DUA OF THE DAY',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: palette.textSlate400,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: palette.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'FORGIVENESS',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: palette.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'رَبِّ اغْفِرْ لِي وَتُبْ عَلَيَّ',
              style: TextStyle(
                fontFamily: 'Amiri',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: palette.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '“My Lord, forgive me and accept my repentance; surely You are the Accepter of repentance, the Merciful.”',
            style: TextStyle(
              fontSize: 11,
              height: 1.35,
              color: palette.textSlate400,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sunan Abi Dawud 1516',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: palette.accent,
                ),
              ),
              Text(
                'Tap to read in app →',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: palette.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. MOCK: One-Tap Tasbih (2x2 Small)
// ─────────────────────────────────────────────────────────────────────────────
class _MockTasbihWidget extends StatelessWidget {
  final AppPalette palette;
  const _MockTasbihWidget({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 155,
      height: 155,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.bgDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.glassBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'سُبْحَانَ اللَّهِ',
                  style: TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: palette.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '33',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: palette.textSlate400,
                ),
              ),
            ],
          ),
          Text(
            '33',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: palette.primary,
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: palette.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Text(
              '➕ TAP',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
