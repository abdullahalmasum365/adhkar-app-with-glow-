import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/language_provider.dart';

class DonationScreen extends StatelessWidget {
  const DonationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color background = Color(0xFF050806);
    const Color primary = Color(0xFFFF7700);
    const Color surfaceContainerHigh = Color(0xFF1E2823);
    const Color onSurfaceVariant = Color(0xFFE0C0B0);
    const Color textWhite = Colors.white;

    final lp = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: [
          // Decorative background gradient (radial)
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, -0.4),
                radius: 1.0,
                colors: [Color(0xFF1E2823), Color(0xFF050806)],
                stops: [0.0, 0.7],
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
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 28),
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
                        const SizedBox(height: 48),
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
                              fontSize: 48,
                              height: 1.1,
                              color: textWhite,
                            ),
                            children: [
                              TextSpan(text: '${lp.getText('donation_become')}\n'),
                              TextSpan(
                                text: lp.getText('donation_patron'),
                                style: const TextStyle(color: primary),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2),
                        const SizedBox(height: 48),

                        // The Pitch
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(
                                4), // slightly rounded for aesthetic
                            border: Border.all(
                              color: const Color(0xFF584235).withOpacity(0.2),
                            ),
                          ),
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: GoogleFonts.publicSans(
                                color: onSurfaceVariant,
                                fontSize: 18,
                                height: 1.8,
                                fontWeight: FontWeight.w300,
                              ),
                              children: [
                                TextSpan(
                                    text: '${lp.getText('donation_pitch_1')} '),
                                const TextSpan(
                                  text: "\$3/month",
                                  style: TextStyle(
                                      color: textWhite,
                                      fontWeight: FontWeight.normal),
                                ),
                                TextSpan(
                                    text:
                                        ' ${lp.getText('donation_pitch_2')}'),
                              ],
                            ),
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 200.ms)
                            .scale(begin: const Offset(0.95, 0.95)),

                        const SizedBox(height: 80),

                        // Call to Action
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Provider.of<UserProvider>(context, listen: false).setDonated(true);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(lp.getText('donation_thank_you')),
                                  backgroundColor: primary,
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: const Color(0xFF0A100D),
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${lp.getText('donation_cta')} - \$5/MONTH',
                                  style: GoogleFonts.spaceMono(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Icon(Icons.arrow_forward, size: 20),
                              ],
                            ),
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 300.ms)
                            .slideY(begin: 0.2)
                            .animate(onPlay: (controller) => controller.repeat())
                            .shimmer(
                                duration: 2500.ms,
                                color: Colors.white.withOpacity(0.4),
                                delay: 1000.ms),
                        const SizedBox(height: 24),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: onSurfaceVariant.withOpacity(0.7),
                          ),
                          child: Text(
                            lp.getText('donation_maybe_later'),
                            style: GoogleFonts.spaceMono(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ).animate().fadeIn(delay: 400.ms),

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
