// ============================================================================
// lib/widgets/sadaqah_certificate_dialog.dart
//
// Displays an elegant, Islamic digital certificate & dua keepsake when
// a user donates for themselves, parents, or deceased loved ones.
// Features authentic Qur'anic prayers and a one-tap family share option.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:share_plus/share_plus.dart';

import '../constants/app_theme.dart';
import '../models/sadaqah_dedication.dart';
import '../utils/responsive.dart';

Future<void> showSadaqahCertificateDialog(
  BuildContext context, {
  required SadaqahDedication dedication,
  required String tierName,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => SadaqahCertificateSheet(
      dedication: dedication,
      tierName: tierName,
    ),
  );
}

class SadaqahCertificateSheet extends StatelessWidget {
  final SadaqahDedication dedication;
  final String tierName;

  const SadaqahCertificateSheet({
    super.key,
    required this.dedication,
    required this.tierName,
  });

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final isBn = Localizations.localeOf(context).languageCode == 'bn';
    final dateStr = DateFormat('d MMMM yyyy').format(dedication.timestamp);
    final targetLabel = dedication.getDisplayTitle(isBn ? 'bn' : 'en');
    final recipient = dedication.recipientName?.trim();
    final nameLine = (recipient != null && recipient.isNotEmpty)
        ? '$targetLabel — $recipient'
        : targetLabel;

    final shareText = isBn
        ? '🌙 সদকায়ে জারিয়াহ ও দোয়া সনদ\n'
          'উৎসর্গকৃত: $nameLine\n'
          'প্যাকেজ: $tierName\n'
          'দোয়া: ${dedication.getDuaArabic()}\n'
          '${dedication.getDuaTranslation("bn")}\n\n'
          'তারিখ: $dateStr\n'
          '— Adhkaar 365 অ্যাপের মাধ্যমে প্রেরিত'
        : '🌙 Sadaqah Jariyah Certificate\n'
          'Dedicated to: $nameLine\n'
          'Tier: $tierName\n'
          'Du\'a: ${dedication.getDuaArabic()}\n'
          '${dedication.getDuaTranslation("en")}\n\n'
          'Date: $dateStr\n'
          '— Shared via Adhkaar 365';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgDeep,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: const Color(0xFFE5A93C).withValues(alpha: 0.5),
            width: 2,
          ),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        R.px(20),
        R.px(16),
        R.px(20),
        R.px(24) + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.ink(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: R.px(16)),

            // Certificate Frame
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(R.px(20)),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF1E2D24),
                    Color(0xFF121B16),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFE5A93C).withValues(alpha: 0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE5A93C).withValues(alpha: 0.08),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Crescent & Stars Badge
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFE5A93C).withValues(alpha: 0.15),
                      border: Border.all(
                        color: const Color(0xFFE5A93C).withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Icon(
                      Icons.nightlight_round,
                      color: Color(0xFFE5A93C),
                      size: 28,
                    ),
                  ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),

                  SizedBox(height: R.px(12)),

                  // Arabic Heading
                  Text(
                    'سَدَقَةٌ جَارِيَةٌ',
                    style: AppText.amiri(
                      fontSize: 26,
                      color: const Color(0xFFE5A93C),
                    ),
                  ),

                  Text(
                    isBn ? 'সদকায়ে জারিয়াহ ও মাগফিরাতের সনদ' : 'Certificate of Continuous Charity',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSlate400,
                      letterSpacing: 1.2,
                    ),
                  ),

                  SizedBox(height: R.px(16)),

                  // Dedication Recipient Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.ink(0.1),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          isBn ? 'এই সদকা যার উদ্দেশ্যে উৎসর্গকৃত:' : 'Dedicated In Honor Of:',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSlate400,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          nameLine,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: R.px(16)),

                  // Du'a in Arabic
                  Text(
                    dedication.getDuaArabic(),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: AppText.amiri(
                      fontSize: 20,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: R.px(8)),

                  // Du'a Translation
                  Text(
                    dedication.getDuaTranslation(isBn ? 'bn' : 'en'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSlate300,
                      height: 1.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),

                  SizedBox(height: R.px(16)),

                  // Footer info: Tier & Date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${isBn ? "প্যাকেজ:" : "Tier:"} $tierName',
                        style: TextStyle(
                          fontSize: 11,
                          color: const Color(0xFFE5A93C).withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSlate400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: R.px(20)),

            // Share Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Share.share(shareText);
                },
                icon: const Icon(Icons.share_rounded, size: 18),
                label: Text(
                  isBn ? 'প্রিয়জন ও পরিবারের সাথে শেয়ার করুন' : 'Share Certificate with Family',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE5A93C),
                  foregroundColor: const Color(0xFF0F1713),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),

            SizedBox(height: R.px(8)),

            // Close Button
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                isBn ? 'সম্পন্ন' : 'Done',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSlate400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
