import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../providers/purchase_provider.dart';
import '../services/purchase_service.dart';
import '../models/sadaqah_dedication.dart';
import '../widgets/sadaqah_certificate_dialog.dart';

/// A single donation package the user can pick — see [DonationScreen].
/// Price comes from Play Store at runtime (PurchaseProvider.products), in
/// the user's own currency — never hardcoded here.
class _Tier {
  final String nameKey;
  final String descKey;
  final String productId;
  final bool featured;
  const _Tier({
    required this.nameKey,
    required this.descKey,
    required this.productId,
    this.featured = false,
  });
}

class DonationScreen extends StatefulWidget {
  const DonationScreen({super.key});

  @override
  State<DonationScreen> createState() => _DonationScreenState();
}

class _DonationScreenState extends State<DonationScreen> {
  static const _tiers = [
    _Tier(
        nameKey: 'donation_tier_seed_name',
        descKey: 'donation_tier_seed_desc',
        productId: DonationProductIds.seed),
    _Tier(
        nameKey: 'donation_tier_supporter_name',
        descKey: 'donation_tier_supporter_desc',
        productId: DonationProductIds.supporter,
        featured: true),
    _Tier(
        nameKey: 'donation_tier_patron_name',
        descKey: 'donation_tier_patron_desc',
        productId: DonationProductIds.patron),
    _Tier(
        nameKey: 'donation_tier_annual_name',
        descKey: 'donation_tier_annual_desc',
        productId: DonationProductIds.annual),
  ];

  int _selected = 1;
  DedicationType _selectedDedication = DedicationType.parents;
  final TextEditingController _recipientNameController =
      TextEditingController();

  bool _wasPurchasing = false;
  String? _lastShownError;

  @override
  void dispose() {
    _recipientNameController.dispose();
    super.dispose();
  }

  void _selectFixedTier(int i) => setState(() => _selected = i);

  void _handlePurchaseSideEffects(PurchaseProvider pp, LanguageProvider lp) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_wasPurchasing && !pp.isPurchasing) {
        if (pp.lastError != null && pp.lastError != _lastShownError) {
          _lastShownError = pp.lastError;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(pp.lastError!),
                backgroundColor: Colors.redAccent),
          );
        } else if (pp.hasActiveSubscription) {
          final selectedTier = _tiers[_selected];
          showSadaqahCertificateDialog(
            context,
            dedication: SadaqahDedication(
              type: _selectedDedication,
              recipientName: _recipientNameController.text.trim().isNotEmpty
                  ? _recipientNameController.text.trim()
                  : null,
              timestamp: DateTime.now(),
            ),
            tierName: lp.getText(selectedTier.nameKey),
          );
        }
      }
      _wasPurchasing = pp.isPurchasing;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color background = AppColors.bgDeep;
    final Color primary = AppColors.primary;
    final Color surfaceContainerHigh = AppColors.bgTeal;
    final Color onSurfaceVariant = AppColors.textSlate300;
    final Color textWhite = AppColors.textPrimary;

    final lp = Provider.of<LanguageProvider>(context);
    final pp = Provider.of<PurchaseProvider>(context);
    _handlePurchaseSideEffects(pp, lp);
    final selectedTier = _tiers[_selected];
    final selectedProduct = pp.products[selectedTier.productId];
    final priceLabel = selectedProduct?.price; // localized, e.g. "$4.99"

    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: [
          // Decorative background gradient (radial) — follows the active theme.
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.0, -0.4),
                radius: 1.0,
                colors: [AppColors.bgTeal, AppColors.bgDeep],
                stops: const [0.0, 0.7],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Back Button
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16.0, top: 8.0),
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.arrow_back,
                          color: AppColors.textPrimary, size: 28),
                      style: IconButton.styleFrom(
                        backgroundColor: surfaceContainerHigh,
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 40),
                        // Hero Section
                        Text(
                          lp.getText('donation_badge'),
                          style: GoogleFonts.spaceMono(
                            color: primary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4.0,
                          ),
                        ).animate().fadeIn().slideY(begin: -0.2),
                        const SizedBox(height: 24),
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: GoogleFonts.spaceMono(
                              fontSize: 44,
                              height: 1.1,
                              color: textWhite,
                            ),
                            children: [
                              TextSpan(
                                  text: '${lp.getText('donation_become')}\n'),
                              TextSpan(
                                text: lp.getText('donation_patron'),
                                style: TextStyle(color: primary),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2),
                        const SizedBox(height: 40),

                        // The Pitch
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.ink(0.1)),
                          ),
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: GoogleFonts.publicSans(
                                color: onSurfaceVariant,
                                fontSize: 17,
                                height: 1.8,
                                fontWeight: FontWeight.w300,
                              ),
                              children: [
                                TextSpan(
                                    text: '${lp.getText('donation_pitch_1')} '),
                                TextSpan(
                                  text: priceLabel != null
                                      ? '$priceLabel${lp.getText('donation_per_month')}'
                                      : lp.getText(
                                          'donation_tier_supporter_name'),
                                  style: TextStyle(
                                      color: textWhite,
                                      fontWeight: FontWeight.w600),
                                ),
                                TextSpan(
                                    text: ' ${lp.getText('donation_pitch_2')}'),
                              ],
                            ),
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 200.ms)
                            .scale(begin: const Offset(0.95, 0.95)),

                        const SizedBox(height: 28),

                        // ── Why we ask: real, concrete running costs ──────────
                        // Cost transparency answers "why donate" directly and
                        // builds trust before the emotional appeals that follow.
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.ink(0.08)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(Icons.dns_rounded,
                                    color: primary, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    lp.getText('donation_why_title'),
                                    style: GoogleFonts.spaceMono(
                                      color: textWhite,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ]),
                              const SizedBox(height: 12),
                              Text(
                                lp.getText('donation_why_body'),
                                style: GoogleFonts.publicSans(
                                  color: onSurfaceVariant,
                                  fontSize: 13.5,
                                  height: 1.7,
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 230.ms),

                        const SizedBox(height: 24),

                        // ── The hadith: Allah loves regular deeds, even small ──
                        // This is the emotional/spiritual anchor for the whole
                        // screen — it directly justifies picking a SMALL but
                        // RECURRING tier over a large one-off amount.
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: primary.withValues(alpha: 0.25)),
                          ),
                          child: Column(children: [
                            Icon(Icons.favorite_rounded,
                                color: primary, size: 22),
                            const SizedBox(height: 14),
                            Text(
                              lp.getText('donation_hadith_ar'),
                              textAlign: TextAlign.center,
                              textDirection: TextDirection.rtl,
                              style:
                                  AppText.amiri(fontSize: 22, color: textWhite),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              '"${lp.getText('donation_hadith_translation')}"',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.publicSans(
                                color: onSurfaceVariant,
                                fontSize: 14,
                                height: 1.6,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              lp.getText('donation_hadith_ref').toUpperCase(),
                              style: GoogleFonts.spaceMono(
                                color: primary.withValues(alpha: 0.8),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ]),
                        )
                            .animate()
                            .fadeIn(delay: 260.ms)
                            .scale(begin: const Offset(0.95, 0.95)),

                        const SizedBox(height: 24),

                        // ── "Give for you and your loved ones" ──────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(children: [
                            Text(
                              lp.getText('donation_for_you_title'),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.spaceMono(
                                color: textWhite,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              lp.getText('donation_for_you_body'),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.publicSans(
                                color: onSurfaceVariant,
                                fontSize: 14,
                                height: 1.7,
                              ),
                            ),
                          ]),
                        ).animate().fadeIn(delay: 320.ms),

                        const SizedBox(height: 28),

                        // ── "Every morning. Every evening." ───────────────────
                        // The emotional peak, placed right before the ask:
                        // your support multiplies into every reward earned by
                        // every user, every single day, for as long as the app
                        // keeps running — not just your own recitation.
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                primary.withValues(alpha: 0.16),
                                primary.withValues(alpha: 0.04),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: primary.withValues(alpha: 0.3)),
                          ),
                          child: Column(children: [
                            Icon(Icons.wb_twilight_rounded,
                                color: primary, size: 26),
                            const SizedBox(height: 14),
                            Text(
                              lp.getText('donation_multiply_title'),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.spaceMono(
                                color: textWhite,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              lp.getText('donation_multiply_body'),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.publicSans(
                                color: onSurfaceVariant,
                                fontSize: 14,
                                height: 1.75,
                              ),
                            ),
                          ]),
                        )
                            .animate()
                            .fadeIn(delay: 350.ms)
                            .scale(begin: const Offset(0.96, 0.96)),

                        const SizedBox(height: 36),

                        // ── Dedication Engine (কার উদ্দেশ্যে উৎসর্গকৃত) ───────
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFE5A93C).withValues(alpha: 0.35),
                              width: 1.2,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE5A93C).withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.favorite_rounded,
                                      color: Color(0xFFE5A93C),
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      lp.getText('dedicate_title'),
                                      style: GoogleFonts.spaceMono(
                                        color: textWhite,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                lp.getText('dedicate_desc'),
                                style: GoogleFonts.publicSans(
                                  color: onSurfaceVariant,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Dedication Options Chips
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _DedicationChip(
                                    label: lp.getText('dedicate_self'),
                                    icon: Icons.person_outline_rounded,
                                    isSelected: _selectedDedication == DedicationType.self,
                                    onTap: () => setState(() => _selectedDedication = DedicationType.self),
                                  ),
                                  _DedicationChip(
                                    label: lp.getText('dedicate_parents'),
                                    icon: Icons.favorite_border_rounded,
                                    isSelected: _selectedDedication == DedicationType.parents,
                                    onTap: () => setState(() => _selectedDedication = DedicationType.parents),
                                  ),
                                  _DedicationChip(
                                    label: lp.getText('dedicate_deceased'),
                                    icon: Icons.spa_outlined,
                                    isSelected: _selectedDedication == DedicationType.deceased,
                                    onTap: () => setState(() => _selectedDedication = DedicationType.deceased),
                                  ),
                                  _DedicationChip(
                                    label: lp.getText('dedicate_family'),
                                    icon: Icons.family_restroom_rounded,
                                    isSelected: _selectedDedication == DedicationType.family,
                                    onTap: () => setState(() => _selectedDedication = DedicationType.family),
                                  ),
                                ],
                              ),

                              // Optional Name Input for Parents / Deceased
                              if (_selectedDedication == DedicationType.parents ||
                                  _selectedDedication == DedicationType.deceased) ...[
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _recipientNameController,
                                  style: const TextStyle(color: Colors.white, fontSize: 13.5),
                                  decoration: InputDecoration(
                                    hintText: lp.locale.languageCode == 'bn'
                                        ? 'যার নামে উৎসর্গ করছেন (যেমন: মরহুম পিতা আব্দুল্লাহ)'
                                        : 'Name of your loved one (optional)',
                                    hintStyle: TextStyle(
                                      color: AppColors.textSlate400,
                                      fontSize: 12.5,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.edit_note_rounded,
                                      color: Color(0xFFE5A93C),
                                      size: 20,
                                    ),
                                    filled: true,
                                    fillColor: background,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: AppColors.ink(0.1)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFFE5A93C)),
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 14),

                              // Preview Certificate Button
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () {
                                    final selectedTier = _tiers[_selected];
                                    showSadaqahCertificateDialog(
                                      context,
                                      dedication: SadaqahDedication(
                                        type: _selectedDedication,
                                        recipientName: _recipientNameController.text.trim().isNotEmpty
                                            ? _recipientNameController.text.trim()
                                            : null,
                                        timestamp: DateTime.now(),
                                      ),
                                      tierName: lp.getText(selectedTier.nameKey),
                                    );
                                  },
                                  icon: const Icon(Icons.card_membership_rounded, size: 16, color: Color(0xFFE5A93C)),
                                  label: Text(
                                    lp.getText('preview_certificate'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFE5A93C),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 380.ms),

                        const SizedBox(height: 36),

                        // ── Package tiers ─────────────────────────────────
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            lp.getText('donation_choose_tier').toUpperCase(),
                            style: GoogleFonts.spaceMono(
                              color: onSurfaceVariant.withValues(alpha: 0.7),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        ...List.generate(_tiers.length, (i) {
                          final t = _tiers[i];
                          final sel = i == _selected;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: GestureDetector(
                              onTap: () => _selectFixedTier(i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 18),
                                decoration: BoxDecoration(
                                  color: sel
                                      ? primary.withValues(alpha: 0.12)
                                      : surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: sel ? primary : AppColors.ink(0.1),
                                    width: sel ? 1.6 : 1,
                                  ),
                                ),
                                child: Row(children: [
                                  Icon(
                                    sel
                                        ? Icons.radio_button_checked_rounded
                                        : Icons.radio_button_off_rounded,
                                    color: sel ? primary : AppColors.ink(0.35),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          // Flexible + ellipsis: the tier
                                          // name shrinks instead of pushing
                                          // past the badge on narrow screens
                                          // or with longer translated names
                                          // (this was the overflow bug —
                                          // the yellow/black hazard stripes).
                                          Flexible(
                                            child: Text(
                                              lp.getText(t.nameKey),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.spaceMono(
                                                color: textWhite,
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          if (t.featured) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                              decoration: BoxDecoration(
                                                color: primary,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                lp.getText(
                                                    'donation_most_loved'),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.spaceMono(
                                                  color: AppColors.onPrimary,
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.6,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ]),
                                        const SizedBox(height: 3),
                                        Text(
                                          lp.getText(t.descKey),
                                          style: GoogleFonts.publicSans(
                                            color: onSurfaceVariant,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // FittedBox: guarantees the price never
                                  // overflows even with a longer translated
                                  // "/month" suffix on very narrow screens.
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: RichText(
                                      text: TextSpan(
                                        style: GoogleFonts.spaceMono(
                                          color: sel ? primary : textWhite,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        children: [
                                          TextSpan(
                                              text: pp.products[t.productId]
                                                      ?.price ??
                                                  '···'),
                                          TextSpan(
                                            text: lp
                                                .getText('donation_per_month'),
                                            style: GoogleFonts.spaceMono(
                                              color: onSurfaceVariant,
                                              fontSize: 11,
                                              fontWeight: FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ]),
                              ),
                            ),
                          )
                              .animate()
                              .fadeIn(delay: (380 + i * 60).ms)
                              .slideX(begin: 0.05);
                        }),

                        const SizedBox(height: 16),

                        // Play Billing can't charge an arbitrary user-typed
                        // amount — subscription prices must be fixed and
                        // pre-configured in Play Console. If products
                        // haven't loaded yet (or aren't configured yet),
                        // show a clear notice instead of a broken picker.
                        if (!pp.isLoading && pp.products.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: Colors.amber.withValues(alpha: 0.25)),
                            ),
                            child: Row(children: [
                              const Icon(Icons.info_outline_rounded,
                                  size: 18, color: Colors.amberAccent),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  lp.getText('donation_not_available'),
                                  style: GoogleFonts.publicSans(
                                    color: Colors.amberAccent,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ]),
                          ),

                        const SizedBox(height: 12),

                        // Call to Action — subscribes to the selected tier
                        // via Google Play Billing. Disabled until real
                        // Play Store products are loaded.
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                                (selectedProduct == null || pp.isPurchasing)
                                    ? null
                                    : () => pp.buy(selectedTier.productId),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: AppColors.onPrimary,
                              disabledBackgroundColor:
                                  primary.withValues(alpha: 0.3),
                              disabledForegroundColor:
                                  AppColors.onPrimary.withValues(alpha: 0.6),
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                              ),
                            ),
                            // FittedBox: the whole button label scales down
                            // as one unit instead of overflowing — handles
                            // long translated CTA text on narrow screens.
                            child: pp.isPurchasing
                                ? SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: AppColors.onPrimary,
                                    ),
                                  )
                                : FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          selectedProduct == null
                                              ? lp.getText(
                                                  'donation_not_available_short')
                                              : '${lp.getText('donation_cta')} - $priceLabel/MONTH',
                                          maxLines: 1,
                                          style: GoogleFonts.spaceMono(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        const Icon(Icons.arrow_forward,
                                            size: 20),
                                      ],
                                    ),
                                  ),
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 600.ms)
                            .slideY(begin: 0.2)
                            .animate(
                                onPlay: (controller) => controller.repeat())
                            .shimmer(
                                duration: 2500.ms,
                                color: AppColors.ink(0.4),
                                delay: 1000.ms),
                        const SizedBox(height: 24),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor:
                                onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                          child: Text(
                            lp.getText('donation_maybe_later'),
                            style: GoogleFonts.spaceMono(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ).animate().fadeIn(delay: 700.ms),

                        const SizedBox(height: 64),
                      ],
                    ),
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

class _DedicationChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _DedicationChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFFE5A93C);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.15)
              : AppColors.ink(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : AppColors.ink(0.12),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? activeColor : AppColors.textSlate400,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textSlate400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
