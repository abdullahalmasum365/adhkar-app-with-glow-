import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../providers/theme_provider.dart';

class DhikrProgressRing extends StatelessWidget {
  final double progress;

  const DhikrProgressRing({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    bool reduceGlow = false;
    try {
      reduceGlow = Provider.of<ThemeProvider>(context).reduceGlowAndBlur;
    } catch (_) {}

    return RepaintBoundary(
      child: CircularPercentIndicator(
        radius: 80.0,
        lineWidth: 12.0,
        percent: progress.clamp(0.0, 1.0),
        center: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 28.0,
                color: ThemeProvider.pearlWhite,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Completed',
              style: TextStyle(
                fontSize: 12.0,
                color: ThemeProvider.etherealSage.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        progressColor: ThemeProvider.divineAmber,
        backgroundColor: AppColors.ink(0.1),
        circularStrokeCap: CircularStrokeCap.round,
        animation: !reduceGlow,
        animationDuration: 1200,
      ),
    );
  }
}
