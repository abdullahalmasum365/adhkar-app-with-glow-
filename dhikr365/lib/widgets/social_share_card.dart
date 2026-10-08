import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../constants/app_theme.dart';
import '../models/dhikr.dart';
import '../providers/language_provider.dart';
import '../providers/purchase_provider.dart';

/// 1080x1920 (9:16 story/status ratio) branded social card widget
/// for sharing beautiful duas across Instagram, WhatsApp, Telegram, etc.
class SocialShareCard extends StatelessWidget {
  final Dhikr dhikr;
  final AppPalette palette;
  final bool showTransliteration;
  final bool showWatermark;
  final String? categoryLabel;

  const SocialShareCard({
    super.key,
    required this.dhikr,
    required this.palette,
    this.showTransliteration = true,
    this.showWatermark = true,
    this.categoryLabel,
  });

  /// Captures and shares the dhikr as a high-resolution social image card.
  static Future<void> shareDhikrAsImage({
    required BuildContext context,
    required Dhikr dhikr,
    bool showTransliteration = true,
  }) async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final pp = Provider.of<PurchaseProvider>(context, listen: false);
    final palette = AppColors.palette;

    // Show quick feedback / loading snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(palette.primary),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              lp.getText('generating_card'),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: palette.textPrimary,
              ),
            ),
          ],
        ),
        backgroundColor: palette.playerSurface,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      final cardWidget = SocialShareCard(
        dhikr: dhikr,
        palette: palette,
        showTransliteration: showTransliteration,
        showWatermark: !pp.isPro, // Pro users don't have mandatory watermark
        categoryLabel: lp.getText(dhikr.category.titleKey),
      );

      final screenshotController = ScreenshotController();
      final bytes = await screenshotController.captureFromWidget(
        cardWidget,
        delay: const Duration(milliseconds: 180),
        context: context,
        targetSize: const Size(1080, 1920),
      );

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/adhkar_share_${dhikr.id}.png';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: '${dhikr.title} — Adhkar 365',
      );
    } catch (e) {
      debugPrint('[SocialShareCard] Error generating/sharing card: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasTranslit = showTransliteration &&
        dhikr.transliteration != null &&
        dhikr.transliteration!.trim().isNotEmpty;
    final hasRef = dhikr.reference != null && dhikr.reference!.trim().isNotEmpty;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        type: MaterialType.transparency,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Container(
            width: 1080,
            height: 1920,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [palette.bgDark, palette.bgDeep],
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
            children: [
              // Radial Ambient Center Glow
              Center(
                child: Container(
                  width: 900,
                  height: 900,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        palette.primary.withValues(alpha: 0.16),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Decorative Border Frame
              Positioned.fill(
                child: Container(
                  margin: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: palette.primary.withValues(alpha: 0.25),
                      width: 2,
                    ),
                  ),
                ),
              ),

              // Content Area
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 72, vertical: 72),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Top Header: App Branding + Category
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: palette.primary.withValues(alpha: 0.2),
                                border: Border.all(
                                  color: palette.primary.withValues(alpha: 0.5),
                                  width: 2,
                                ),
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.mosque_rounded,
                                    color: palette.primary,
                                    size: 28,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ADHKAR 365',
                                  style: GoogleFonts.manrope(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 3.0,
                                    color: palette.primary,
                                  ),
                                ),
                                Text(
                                  'Daily Islamic Remembrance',
                                  style: GoogleFonts.manrope(
                                    fontSize: 14,
                                    color: palette.textSlate400,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (categoryLabel != null && categoryLabel!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: palette.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: palette.primary.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              categoryLabel!.toUpperCase(),
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: palette.primary,
                              ),
                            ),
                          ),
                      ],
                    ),

                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Dua Title Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.bgCard,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: palette.glassBorder),
                                ),
                                child: Text(
                                  dhikr.title,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.manrope(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: palette.textPrimary,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 36),

                              // Arabic Text (Centered, Large Amiri Font, RTL)
                              Directionality(
                                textDirection: TextDirection.rtl,
                                child: Text(
                                  dhikr.arabicText,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.amiri(
                                    fontSize: 44,
                                    fontWeight: FontWeight.w700,
                                    color: palette.textPrimary,
                                    height: 1.85,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Soft Amber Decorative Underline Divider
                              Center(
                                child: Container(
                                  width: 140,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        palette.primary,
                                        Colors.transparent,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 32),

                              // Translation (Inter/Manrope, Slate 300, Italic)
                              Text(
                                dhikr.translation,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.manrope(
                                  fontSize: 24,
                                  fontStyle: FontStyle.italic,
                                  color: palette.textSlate300,
                                  height: 1.6,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),

                              // Transliteration (Slate 400, Smaller)
                              if (hasTranslit) ...[
                                const SizedBox(height: 20),
                                Text(
                                  dhikr.transliteration!,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.notoSerif(
                                    fontSize: 20,
                                    fontStyle: FontStyle.italic,
                                    color: palette.textSlate400,
                                    height: 1.5,
                                  ),
                                ),
                              ],

                              const SizedBox(height: 28),

                              // Hadith Reference Pill Badge
                              if (hasRef)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: palette.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: palette.primary.withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '📖  ${dhikr.reference}',
                                        style: GoogleFonts.manrope(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: palette.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Footer / Watermark
                    if (showWatermark)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.favorite_rounded,
                            size: 16,
                            color: palette.primary.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'adhkar365.app',
                            style: GoogleFonts.manrope(
                              fontSize: 16,
                              letterSpacing: 2.0,
                              fontWeight: FontWeight.w600,
                              color: palette.textSlate500,
                            ),
                          ),
                        ],
                      )
                    else
                      const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }
}
