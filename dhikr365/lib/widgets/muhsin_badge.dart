// ============================================================================
// lib/widgets/muhsin_badge.dart
//
// A prestigious, respectful Islamic honor badge ("মুহসিন / Muhsin") displayed
// on the profile and header of voluntary Sadaqah Jariyah contributors.
// Tapping opens the donor appreciation sheet and certificate viewer.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../constants/app_theme.dart';
import '../providers/language_provider.dart';
import '../providers/user_provider.dart';
import 'sadaqah_certificate_dialog.dart';

class MuhsinBadge extends StatelessWidget {
  final bool isSmall;
  final VoidCallback? onTap;

  const MuhsinBadge({
    super.key,
    this.isSmall = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);
    final isBn = lp.locale.languageCode == 'bn';
    final label = isBn ? 'মুহসিন' : 'Muhsin';

    return GestureDetector(
      onTap: onTap ?? () => _showMuhsinAppreciationDialog(context),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmall ? 8 : 12,
          vertical: isSmall ? 3 : 5,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFFE5A93C),
              Color(0xFFD4AF37),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE5A93C).withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: const Color(0xFFFFF2B2).withValues(alpha: 0.6),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.stars_rounded,
              size: isSmall ? 13 : 16,
              color: const Color(0xFF1B261F),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: const Color(0xFF1B261F),
                fontSize: isSmall ? 11 : 12.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .shimmer(duration: 2500.ms, color: Colors.white.withValues(alpha: 0.4));
  }

  static void _showMuhsinAppreciationDialog(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final up = Provider.of<UserProvider>(context, listen: false);
    final isBn = lp.locale.languageCode == 'bn';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppColors.bgDeep,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: const Color(0xFFE5A93C).withValues(alpha: 0.4)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.ink(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE5A93C).withValues(alpha: 0.15),
                  border: Border.all(
                    color: const Color(0xFFE5A93C).withValues(alpha: 0.5),
                  ),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFFE5A93C),
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isBn ? 'মুহসিন সম্মাননা (Muhsin Sponsor)' : 'Muhsin Honor (Sustainer)',
                style: AppText.heading(18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isBn
                    ? '“নিশ্চয়ই আল্লাহ মুহসিনদের (সৎকর্মশীল ও উত্তম দানকারীদের) ভালোবাসেন।” (সূরা আল-বাকারা: ১৯৫)\n\nAdhkaar 365 অ্যাপের ইলমী খেদমতকে সচল রাখতে আপনার সাদাকাহ জারিয়াহর জন্য জাযাকাল্লাহু খাইরান। আল্লাহ তায়ালা আপনার ও আপনার পরিবারের পক্ষ থেকে কবুল করুন।'
                    : '“Indeed, Allah loves the doers of good (Al-Muhsinin).” (Surah Al-Baqarah: 195)\n\nJazakAllahu Khairan for supporting Adhkaar 365 as an ongoing charity (Sadaqah Jariyah). May Allah accept it from you and your family.',
                textAlign: TextAlign.center,
                style: AppText.body(color: AppColors.textSlate300).copyWith(height: 1.45),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    showSadaqahCertificateDialog(
                      context,
                      dedication: up.savedDedication,
                      tierName: up.savedTierName,
                    );
                  },
                  icon: const Icon(Icons.card_membership_rounded, size: 18),
                  label: Text(
                    isBn ? 'সনদপত্র দেখুন ও শেয়ার করুন' : 'View & Share Certificate',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE5A93C),
                    foregroundColor: const Color(0xFF0F1713),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  isBn ? 'ঠিক আছে' : 'Close',
                  style: TextStyle(color: AppColors.textSlate400),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
