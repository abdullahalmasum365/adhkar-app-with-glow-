// ============================================================================
// lib/widgets/pro_paywall_sheet.dart
//
// Modal bottom sheet displayed when a free user attempts to access Pro features
// such as creating/switching to a Custom Dua Plan.
// Compliant with Google Play Billing: clearly details digital benefits and
// seamlessly routes to the donation/supporter purchase flow.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../constants/app_theme.dart';
import '../providers/language_provider.dart';
import '../providers/purchase_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/donation_screen.dart';
import '../services/purchase_service.dart';
import '../utils/responsive.dart';

Future<void> showProPaywallModal(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const ProPaywallSheet(),
  );
}

class ProPaywallSheet extends StatelessWidget {
  const ProPaywallSheet({super.key});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final lp = Provider.of<LanguageProvider>(context);
    final pp = Provider.of<PurchaseProvider>(context);
    final isBn = lp.locale.languageCode == 'bn';

    final proProduct = pp.products[DonationProductIds.proLifetime];
    final proPriceLabel = proProduct?.price;

    final title = isBn
        ? 'আযকার ৩৬৫ প্রো'
        : 'Adhkaar 365 PRO';
    final subtitle = isBn
        ? 'ব্যক্তিগত সুবিধার জন্য কাস্টম রুটিন তৈরি করুন, ১২+ প্রিমিয়াম থিম আনলক করুন ও ক্লাউডে নিরাপদ সিঙ্ক রাখুন।'
        : 'Personalize your dhikr routine, unlock 12+ premium themes, and sync securely across all your devices.';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgDeep,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: ThemeProvider.divineAmber.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        R.px(24),
        R.px(16),
        R.px(24),
        R.px(28) + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Drag handle
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.ink(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: R.px(20)),

            // Crown / Star Icon badge
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    ThemeProvider.divineAmber.withValues(alpha: 0.25),
                    AppColors.primary.withValues(alpha: 0.15),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: ThemeProvider.divineAmber.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.workspace_premium_rounded,
                size: 36,
                color: ThemeProvider.divineAmber,
              ),
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),

            SizedBox(height: R.px(14)),

            // Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: ThemeProvider.divineAmber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: ThemeProvider.divineAmber.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                isBn ? 'ব্যক্তিগত প্রো ভার্সন' : 'PERSONAL PRO UPGRADE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: ThemeProvider.divineAmber,
                  letterSpacing: 1.2,
                ),
              ),
            ),

            SizedBox(height: R.px(12)),

            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppText.heading(20).copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),

            SizedBox(height: R.px(10)),

            // Subtitle
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppText.body(color: AppColors.textSlate400).copyWith(
                fontSize: 13.5,
                height: 1.5,
              ),
            ),

            SizedBox(height: R.px(18)),

            // Feature List
            _FeatureRow(
              icon: Icons.checklist_rounded,
              title: isBn ? 'ব্যক্তিগত দোয়া তালিকা' : 'Personalized Dua Routine',
              desc: isBn
                  ? 'সকাল, সন্ধ্যা ও যে কোনো সময় নিজের পছন্দমতো দোয়া সক্রিয় বা নিষ্ক্রিয় করুন।'
                  : 'Customize exactly which dhikrs appear in your daily routines.',
            ),
            SizedBox(height: R.px(10)),
            _FeatureRow(
              icon: Icons.palette_rounded,
              title: isBn ? '১২+ প্রিমিয়াম থিম ও ফন্ট' : '12+ Premium Themes & Fonts',
              desc: isBn
                  ? 'গোল্ডেন, এমারেল্ড, মিডনাইট সহ আকর্ষণীয় প্রিমিয়াম ইসলামিক থিম।'
                  : 'Unlock Golden, Emerald, Midnight and exclusive Arabic typography.',
            ),
            SizedBox(height: R.px(10)),
            _FeatureRow(
              icon: Icons.cloud_sync_rounded,
              title: isBn ? 'নিরাপদ ক্লাউড ব্যাকআপ' : 'Secure Cloud Backup',
              desc: isBn
                  ? 'ফোন পরিবর্তন বা অ্যাপ রি-ইন্সটল করলেও আপনার কাস্টম লিস্ট কখনোই হারাবে না।'
                  : 'Your routine stays synced and safely restored across all your devices.',
            ),

            SizedBox(height: R.px(20)),

            // Unlock Pro Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  if (proProduct != null) {
                    pp.buy(DonationProductIds.proLifetime);
                  } else {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DonationScreen()),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeProvider.divineAmber,
                  foregroundColor: ThemeProvider.brandDark,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      proPriceLabel != null
                          ? (isBn ? 'প্রো আনলক করুন ($proPriceLabel)' : 'Unlock Pro ($proPriceLabel)')
                          : (isBn ? 'প্রো ভার্সন আনলক করুন' : 'Unlock Pro Version'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: R.px(14)),

            // Sadaqah Jariyah Card (Dedicated charity section)
            InkWell(
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DonationScreen()),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.volunteer_activism_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isBn ? 'পিতা-মাতা বা আপনজনদের জন্য সদকা?' : 'Sadaqah Jariyah for Parents?',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isBn
                                ? 'মাসিক/বাৎসরিক সদকা দিয়ে ডিজিটাল দোয়া সনদ পান →'
                                : 'Give ongoing charity & receive a Du\'a Certificate →',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSlate400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: R.px(10)),

            // Restore Purchases & Dismiss
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () async {
                    final purchaseProv = Provider.of<PurchaseProvider>(context, listen: false);
                    await purchaseProv.restorePurchases();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isBn ? 'পূর্ববর্তী কেনাকাটা পুনরুদ্ধার করা হচ্ছে...' : 'Checking previous purchases...',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Text(
                    isBn ? 'কেনাকাটা পুনরুদ্ধার' : 'Restore Purchases',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSlate400,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    isBn ? 'পরে দেখুন' : 'Maybe Later',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSlate400,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.ink(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.ink(0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: ThemeProvider.divineAmber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: ThemeProvider.divineAmber),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSlate400,
                    height: 1.35,
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
