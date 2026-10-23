// ============================================================================
// lib/widgets/friday_sadaqah_card.dart
//
// "Friday Sadaqah Barakah" card displayed exclusively on Fridays (Jumu'ah)
// at the upper area of HomeScreen.
// Inspires users to dedicate a Sadaqah Jariyah on the most blessed day of the
// week, and honors existing Muhsin sponsors.
// 100% theme-adaptive across all 15 light and dark palettes.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../constants/app_theme.dart';
import '../providers/language_provider.dart';
import '../providers/purchase_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/user_provider.dart';
import '../screens/donation_screen.dart';
import '../utils/responsive.dart';
import 'sadaqah_certificate_dialog.dart';

class FridaySadaqahCard extends StatefulWidget {
  const FridaySadaqahCard({super.key});

  @override
  State<FridaySadaqahCard> createState() => _FridaySadaqahCardState();
}

class _FridaySadaqahCardState extends State<FridaySadaqahCard> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    // Only visible on Fridays
    final isFriday = DateTime.now().weekday == DateTime.friday;
    if (!isFriday || _dismissed) {
      return const SizedBox.shrink();
    }

    final lp = Provider.of<LanguageProvider>(context);
    final up = Provider.of<UserProvider>(context);
    final pp = Provider.of<PurchaseProvider>(context);
    // Listen to theme changes so card dynamically recolors with theme switches
    Provider.of<ThemeProvider>(context);

    final isBn = lp.locale.languageCode == 'bn';
    final isDonor = up.isMuhsin(pp);

    final isDark = AppColors.isDark;
    final primary = AppColors.primary;
    final onPrimary = AppColors.onPrimary;
    final accent = AppColors.accent;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(vertical: R.px(8)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? (isDonor
                  ? [
                      AppColors.surfaceElevated,
                      AppColors.bgTeal,
                      AppColors.bgDeep,
                    ]
                  : [
                      AppColors.surfaceElevated,
                      AppColors.bgTeal,
                    ])
              : [
                  AppColors.surfaceElevated,
                  AppColors.surfaceElevated,
                  AppColors.bgDeep.withValues(alpha: 0.8),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(R.px(20)),
        border: Border.all(
          color: primary.withValues(alpha: isDark ? 0.35 : 0.28),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? primary.withValues(alpha: 0.10)
                : AppColors.shadow(0.08),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background decorative Islamic arch/mosque silhouette
          Positioned(
            right: -10,
            bottom: -15,
            child: Icon(
              Icons.mosque_rounded,
              size: 110,
              color: primary.withValues(alpha: isDark ? 0.08 : 0.05),
            ),
          ),

          Padding(
            padding: EdgeInsets.all(R.px(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Tag & Dismiss
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: isDark ? 0.16 : 0.10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: primary.withValues(alpha: isDark ? 0.38 : 0.28),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 13,
                            color: primary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isDonor
                                ? (isBn ? 'জুমুআ মোবারক 🕌 • আলহামদুলিল্লাহ' : "Jumu'ah Mubarak 🕌 • Alhamdulillah")
                                : (isBn ? 'জুমুআ মোবারক 🕌 • সুন্নাহ আমল' : "Jumu'ah Mubarak 🕌 • Blessed Sunnah"),
                            style: TextStyle(
                              color: primary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _dismissed = true),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: AppColors.textSlate400,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: R.px(12)),

                // Title & Body (High Contrast across all dark & light themes)
                Text(
                  isDonor
                      ? (isBn ? 'মুহসিন সম্মাননা • জুমার বারাকাহ' : 'Muhsin Sustainer • Friday Barakah')
                      : (isBn ? 'জুমার দিনের সাদাকাহ বারাকাহ' : 'Friday Sadaqah Barakah'),
                  style: AppText.manrope(
                    fontSize: R.adaptive(15, 17, 19),
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: R.px(5)),
                Text(
                  isDonor
                      ? (isBn
                          ? 'আলহামদুলিল্লাহ! আপনার সাদাকাহ জারিয়াহ সক্রিয় রয়েছে। আল্লাহ আপনার পিতা-মাতা ও পরিবারের পক্ষ থেকে কবুল করুন।'
                          : 'Alhamdulillah! Your Sadaqah Jariyah is active. May Allah bless your family and reward you in this life and the next.')
                      : (isBn
                          ? '“অন্যান্য দিনের তুলনায় জুমার দিনের সাদাকাহর মর্যাদা শ্রেষ্ঠ।” — পিতা-মাতার নামে আজ একটি সাদাকাহ জারিয়াহ করুন।'
                          : '“Charity given on Friday has greater merit than on any other day.” — Dedicate a Sadaqah Jariyah for your loved ones today.'),
                  style: AppText.manrope(
                    fontSize: R.sp(12.5),
                    height: 1.45,
                    color: AppColors.textSlate300,
                  ),
                ),

                SizedBox(height: R.px(14)),

                // Action Button (Adapts to palette primary/accent with guaranteed contrast)
                GestureDetector(
                  onTap: () {
                    if (isDonor) {
                      showSadaqahCertificateDialog(
                        context,
                        dedication: up.savedDedication,
                        tierName: up.savedTierName,
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DonationScreen(),
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: R.px(14),
                      vertical: R.px(9),
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          primary,
                          accent,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.30),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isDonor
                              ? Icons.card_membership_rounded
                              : Icons.favorite_rounded,
                          size: 15,
                          color: onPrimary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isDonor
                              ? (isBn ? 'সনদপত্র দেখুন 📜' : 'View Keepsake Certificate 📜')
                              : (isBn ? 'সাদাকাহ জারিয়াহ করুন ➔' : 'Give Sadaqah Jariyah ➔'),
                          style: TextStyle(
                            color: onPrimary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideY(begin: -0.1, duration: 450.ms, curve: Curves.easeOutCubic);
  }
}
