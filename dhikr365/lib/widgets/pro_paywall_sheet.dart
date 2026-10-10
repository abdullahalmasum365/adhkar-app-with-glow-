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
  return Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const DonationScreen()),
  );
}

class ProPaywallSheet extends StatefulWidget {
  const ProPaywallSheet({super.key});

  @override
  State<ProPaywallSheet> createState() => _ProPaywallSheetState();
}

class _ProPaywallSheetState extends State<ProPaywallSheet> {
  String _selectedPlanId = DonationProductIds.pro1Year;
  bool _wasPurchasing = false;

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final lp = Provider.of<LanguageProvider>(context);
    final pp = Provider.of<PurchaseProvider>(context);
    final isBn = lp.locale.languageCode == 'bn';

    // Auto-dismiss when Pro is successfully unlocked
    if (_wasPurchasing && !pp.isPurchasing && pp.isPro) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isBn
                ? 'আলহামদুলিল্লাহ! আপনার প্রো সুবিধা সক্রিয় হয়েছে।'
                : 'Alhamdulillah! Your Pro subscription is now active.'),
            backgroundColor: Colors.green,
          ),
        );
      });
    }
    _wasPurchasing = pp.isPurchasing;

    final selectedProduct = pp.products[_selectedPlanId];
    final selectedPriceLabel = selectedProduct?.price;

    final title = isBn ? 'আযকার ৩৬৫ প্রো' : 'Adhkaar 365 PRO';
    final subtitle = isBn
        ? 'ব্যক্তিগত সুবিধার জন্য কাস্টম রুটিন তৈরি করুন, ক্লাউডে নিরাপদ সিঙ্ক রাখুন ও বিশেষ থিম উপভোগ করুন।'
        : 'Personalize your dhikr routine, sync securely across all your devices, and unlock premium themes.';

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
        child: SingleChildScrollView(
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
                  isBn ? 'ব্যক্তিগত প্রো প্ল্যান' : 'CHOOSE PRO PLAN',
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
                icon: Icons.cloud_sync_rounded,
                title: isBn ? 'নিরাপদ ক্লাউড ব্যাকআপ' : 'Secure Cloud Backup',
                desc: isBn
                    ? 'ফোন পরিবর্তন বা অ্যাপ রি-ইন্সটল করলেও আপনার কাস্টম লিস্ট কখনোই হারাবে না।'
                    : 'Your routine stays synced and safely restored across all your devices.',
              ),
              SizedBox(height: R.px(10)),
              _FeatureRow(
                icon: Icons.palette_rounded,
                title: isBn ? 'এক্সক্লুসিভ লাক্সারি থিম' : 'Exclusive Luxury Palettes',
                desc: isBn
                    ? 'রয়্যাল গোল্ড, অ্যামোলেড ব্ল্যাক এবং বিশেষ কালার প্যালেট আনলক করুন।'
                    : 'Unlock Midnight AMOLED, Royal Gold, and all premium aesthetic themes.',
              ),

              SizedBox(height: R.px(20)),

              // ── 3 Pro Plan Selector Cards (1 Month, 6 Months, 1 Year) ──
              Row(
                children: [
                  _PlanCard(
                    title: isBn ? '১ মাস' : '1 Month',
                    price: pp.products[DonationProductIds.pro1Month]?.price ?? '—',
                    period: isBn ? '/মাস' : '/mo',
                    isSelected: _selectedPlanId == DonationProductIds.pro1Month,
                    onTap: () => setState(() => _selectedPlanId = DonationProductIds.pro1Month),
                  ),
                  const SizedBox(width: 8),
                  _PlanCard(
                    title: isBn ? '৬ মাস' : '6 Months',
                    price: pp.products[DonationProductIds.pro6Months]?.price ?? '—',
                    period: isBn ? '/৬ মাস' : '/6 mos',
                    isSelected: _selectedPlanId == DonationProductIds.pro6Months,
                    onTap: () => setState(() => _selectedPlanId = DonationProductIds.pro6Months),
                  ),
                  const SizedBox(width: 8),
                  _PlanCard(
                    title: isBn ? '১ বছর' : '1 Year',
                    badge: isBn ? 'সেরা সাশ্রয়ী' : 'Best Value',
                    price: pp.products[DonationProductIds.pro1Year]?.price ?? '—',
                    period: isBn ? '/বছর' : '/yr',
                    isSelected: _selectedPlanId == DonationProductIds.pro1Year,
                    onTap: () => setState(() => _selectedPlanId = DonationProductIds.pro1Year),
                  ),
                ],
              ),

              SizedBox(height: R.px(18)),

              // Unlock Pro Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: pp.isPurchasing
                      ? null
                      : () => pp.buy(_selectedPlanId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeProvider.divineAmber,
                    foregroundColor: ThemeProvider.brandDark,
                    disabledBackgroundColor:
                        ThemeProvider.divineAmber.withValues(alpha: 0.3),
                    disabledForegroundColor:
                        ThemeProvider.brandDark.withValues(alpha: 0.5),
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
                        pp.isPurchasing
                            ? (isBn ? 'প্রসেসিং হচ্ছে...' : 'Processing...')
                            : (selectedPriceLabel != null
                                ? (isBn
                                    ? 'প্রো আনলক করুন ($selectedPriceLabel)'
                                    : 'Unlock Pro ($selectedPriceLabel)')
                                : (isBn
                                    ? 'প্রো প্ল্যান আনলক করুন'
                                    : 'Unlock Pro Plan')),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: R.px(16)),

              // Voluntary Support Card (Open to everyone)
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
                              isBn
                                  ? 'ডেভেলপারকে সমর্থন করুন'
                                  : 'Support the Developer',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isBn
                                  ? 'সবার জন্য উন্মুক্ত • অনেকে সদকায়ে জারিয়ার নিয়তে সমর্থন করেন →'
                                  : 'Open to everyone • Many support with the intention of sadaqah jariyah →',
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

class _PlanCard extends StatelessWidget {
  final String title;
  final String? badge;
  final String price;
  final String period;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.title,
    this.badge,
    required this.price,
    required this.period,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? ThemeProvider.divineAmber.withValues(alpha: 0.12)
                : AppColors.ink(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? ThemeProvider.divineAmber
                  : AppColors.ink(0.1),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (badge != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: ThemeProvider.divineAmber,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                )
              else
                const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppColors.textSlate300,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                price,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? ThemeProvider.divineAmber : Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                period,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textSlate400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
