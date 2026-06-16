// ============================================================================
// lib/screens/qibla_screen.dart
//
// Live Qibla compass.
//   • Uses flutter_compass for fused-sensor device heading (mag + accel + gyro).
//   • Calculates the great-circle bearing from the user's saved coordinates
//     to the Kaaba (21.4225° N, 39.8262° E).
//   • The compass rose rotates so that N always points to geographic north;
//     the Kaaba needle rotates independently to always point to Mecca.
//   • Falls back gracefully when no location is saved or sensor is unavailable.
// ============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:provider/provider.dart';

import '../constants/app_theme.dart';
import '../providers/language_provider.dart';
import '../providers/user_provider.dart';
import '../utils/responsive.dart';

// ── Kaaba coordinates ─────────────────────────────────────────────────────────
const double _kaabaLat = 21.4225;
const double _kaabaLng = 39.8262;

// ── Great-circle bearing (degrees, 0–360) from (lat1,lng1) to Kaaba ──────────
double _qiblaBearing(double userLat, double userLng) {
  final lat1 = userLat * math.pi / 180;
  const lat2 = _kaabaLat * math.pi / 180;
  final dLng = (_kaabaLng - userLng) * math.pi / 180;

  final y = math.sin(dLng) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLng);

  final bearing = math.atan2(y, x) * 180 / math.pi;
  return (bearing + 360) % 360;
}

// ─────────────────────────────────────────────────────────────────────────────

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  // Smoothed heading (degrees)
  double _heading = 0;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final lp = Provider.of<LanguageProvider>(context);
    final up = Provider.of<UserProvider>(context);

    final hasLocation = up.hasSavedCoordinates;
    final userLat     = up.lat ?? 0.0;
    final userLng     = up.lng ?? 0.0;
    final qibla       = hasLocation ? _qiblaBearing(userLat, userLng) : 0.0;
    final cityLabel   = (up.city?.isNotEmpty == true)
        ? '${up.city}, ${up.country}'
        : 'Location not set';

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [Color(0xFF0D2D2A), AppColors.bgDark],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(
                    R.px(8), R.px(8), R.px(16), R.px(4)),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 20),
                    ),
                    Expanded(
                      child: Text(
                        lp.getText('nav_qibla').toUpperCase(),
                        textAlign: TextAlign.center,
                        style: AppText.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // ── Location chip ────────────────────────────────────────────
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on,
                        color: AppColors.primary, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      cityLabel,
                      style: AppText.manrope(
                          fontSize: 12,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 150.ms),

              const Spacer(),

              // ── Compass ──────────────────────────────────────────────────
              if (!hasLocation)
                _buildNoLocation(lp)
              else
                StreamBuilder<CompassEvent>(
                  stream: FlutterCompass.events,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return _buildLoading();
                    }
                    if (snap.hasError || !snap.hasData) {
                      return _buildUnavailable();
                    }

                    final event   = snap.data!;
                    final raw     = event.heading ?? 0.0;
                    // Smooth heading: lerp toward new value
                    _heading = _lerpAngle(_heading, raw, 0.15);

                    final needleAngle =
                        (qibla - _heading) * math.pi / 180;
                    final compassAngle = -_heading * math.pi / 180;
                    final delta = ((qibla - _heading) % 360 + 360) % 360;
                    final aligned = delta < 5 || delta > 355;

                    return _buildCompass(
                      compassAngle : compassAngle,
                      needleAngle  : needleAngle,
                      qibla        : qibla,
                      heading      : _heading,
                      aligned      : aligned,
                      accuracy     : event.accuracy,
                      lp           : lp,
                    );
                  },
                ),

              const Spacer(),

              // ── Kaaba label ──────────────────────────────────────────────
              if (hasLocation)
                Padding(
                  padding: EdgeInsets.only(bottom: R.px(32)),
                  child: Column(
                    children: [
                      const Text('🕋',
                          style: TextStyle(fontSize: 28)),
                      const SizedBox(height: 6),
                      Text(
                        'Masjid Al-Haram, Mecca',
                        style: AppText.manrope(
                            fontSize: 13,
                            color: Colors.white54,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 400.ms),
            ],
          ),
        ),
      ),
    );
  }

  // ── Compass widget ────────────────────────────────────────────────────────

  Widget _buildCompass({
    required double compassAngle,
    required double needleAngle,
    required double qibla,
    required double heading,
    required bool aligned,
    required double? accuracy,
    required LanguageProvider lp,
  }) {
    final size = R.adaptive(260.0, 300.0, 360.0);

    return Column(
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // ── Pulsing glow when aligned ──────────────────────────────
              if (aligned)
                AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) => Container(
                    width: size * (0.88 + 0.06 * _pulseCtrl.value),
                    height: size * (0.88 + 0.06 * _pulseCtrl.value),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withOpacity(
                              0.25 * _pulseCtrl.value),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Compass rose (rotates with heading so N = true north) ──
              Transform.rotate(
                angle: compassAngle,
                child: CustomPaint(
                  size: Size(size, size),
                  painter: _CompassRosePainter(),
                ),
              ),

              // ── Kaaba needle (points to Qibla) ─────────────────────────
              Transform.rotate(
                angle: needleAngle,
                child: CustomPaint(
                  size: Size(size * 0.72, size * 0.72),
                  painter: _NeedlePainter(aligned: aligned),
                ),
              ),

              // ── Center jewel ───────────────────────────────────────────
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: aligned
                      ? const Color(0xFF10B981)
                      : AppColors.primary.withOpacity(0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (aligned
                              ? const Color(0xFF10B981)
                              : AppColors.primary)
                          .withOpacity(0.6),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── Degree readout ─────────────────────────────────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: aligned
                ? const Color(0xFF10B981).withOpacity(0.12)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: aligned
                  ? const Color(0xFF10B981).withOpacity(0.35)
                  : Colors.white.withOpacity(0.08),
            ),
          ),
          child: aligned
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF10B981), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Facing Qibla',
                      style: AppText.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${qibla.toStringAsFixed(1)}°',
                      style: AppText.manrope(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _bearingLabel(qibla),
                      style: AppText.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
        ),

        // ── Accuracy warning ───────────────────────────────────────────
        if (accuracy != null && accuracy > 15)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.amber.withOpacity(0.7), size: 14),
                const SizedBox(width: 6),
                Text(
                  'Low accuracy — move away from metal objects',
                  style: AppText.manrope(
                      fontSize: 11,
                      color: Colors.amber.withOpacity(0.7)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ── States ────────────────────────────────────────────────────────────────

  Widget _buildNoLocation(LanguageProvider lp) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.location_off_rounded,
            color: Colors.white24, size: 64),
        const SizedBox(height: 16),
        Text(
          'Location Not Set',
          style: AppText.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white70),
        ),
        const SizedBox(height: 8),
        Text(
          'Set your location in Settings\nto use the Qibla compass.',
          textAlign: TextAlign.center,
          style: AppText.manrope(
              fontSize: 14, color: Colors.white38),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return SizedBox(
      width: 40, height: 40,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color: AppColors.primary.withOpacity(0.7),
      ),
    );
  }

  Widget _buildUnavailable() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.compass_calibration_outlined,
            color: Colors.white24, size: 64),
        const SizedBox(height: 16),
        Text(
          'Compass Not Available',
          style: AppText.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white70),
        ),
        const SizedBox(height: 8),
        Text(
          'This device does not have a\nmagnetometer sensor.',
          textAlign: TextAlign.center,
          style: AppText.manrope(
              fontSize: 14, color: Colors.white38),
        ),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Interpolate between two angles (handles 359→1 wrap-around).
  double _lerpAngle(double from, double to, double t) {
    double diff = (to - from + 540) % 360 - 180;
    return from + diff * t;
  }

  String _bearingLabel(double deg) {
    const labels = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final idx = ((deg + 22.5) / 45).floor() % 8;
    return labels[idx];
  }
}

// ── Custom Painters ───────────────────────────────────────────────────────────

class _CompassRosePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2;

    // ── Outer ring ────────────────────────────────────────────────────
    final ringPaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset(cx, cy), r * 0.92, ringPaint);

    // ── Tick marks ────────────────────────────────────────────────────
    final majorPaint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..strokeWidth = 1.5;
    final minorPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 1.0;

    for (int i = 0; i < 72; i++) {
      final angle  = i * 5.0 * math.pi / 180;
      final isMajor = i % 6 == 0;
      final outer = r * 0.92;
      final inner = outer - (isMajor ? r * 0.08 : r * 0.04);
      canvas.drawLine(
        Offset(cx + outer * math.sin(angle), cy - outer * math.cos(angle)),
        Offset(cx + inner * math.sin(angle), cy - inner * math.cos(angle)),
        isMajor ? majorPaint : minorPaint,
      );
    }

    // ── Inner decorative ring ─────────────────────────────────────────
    final innerRing = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(Offset(cx, cy), r * 0.72, innerRing);

    // ── Cardinal labels ───────────────────────────────────────────────
    final cardinals = {
      0.0  : ('N', true),
      90.0 : ('E', false),
      180.0: ('S', false),
      270.0: ('W', false),
    };

    for (final entry in cardinals.entries) {
      final angle  = entry.key * math.pi / 180;
      final label  = entry.value.$1;
      final isNorth = entry.value.$2;
      final dist = r * 0.78;
      final x = cx + dist * math.sin(angle);
      final y = cy - dist * math.cos(angle);

      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: r * 0.1,
            fontWeight: FontWeight.w900,
            color: isNorth
                ? const Color(0xFFEF4444)
                : Colors.white.withOpacity(0.7),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas,
          Offset(x - tp.width / 2, y - tp.height / 2));
    }

    // ── Intercardinal labels ──────────────────────────────────────────
    const intercardinals = [45.0, 135.0, 225.0, 315.0];
    const icLabels       = ['NE', 'SE', 'SW', 'NW'];
    for (int i = 0; i < 4; i++) {
      final angle = intercardinals[i] * math.pi / 180;
      final dist  = r * 0.78;
      final x = cx + dist * math.sin(angle);
      final y = cy - dist * math.cos(angle);

      final tp = TextPainter(
        text: TextSpan(
          text: icLabels[i],
          style: TextStyle(
            fontSize: r * 0.07,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.35),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas,
          Offset(x - tp.width / 2, y - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_CompassRosePainter old) => false;
}

class _NeedlePainter extends CustomPainter {
  final bool aligned;
  const _NeedlePainter({required this.aligned});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2;

    final topColor = aligned
        ? const Color(0xFF10B981)
        : const Color(0xFFF59E0B);

    // ── Kaaba icon at the tip ────────────────────────────────────────
    const kaabaEmoji = '🕋';
    final kaabaY = cy - r * 0.78;
    final tp = TextPainter(
      text: TextSpan(
          text: kaabaEmoji,
          style: TextStyle(fontSize: r * 0.18)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas,
        Offset(cx - tp.width / 2, kaabaY - tp.height / 2));

    // ── Arrow shaft (pointing up = toward Qibla) ─────────────────────
    final shaftPaint = Paint()
      ..color = topColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(cx, kaabaY + tp.height / 2 + 4),
      Offset(cx, cy + r * 0.2),
      shaftPaint,
    );

    // ── Arrowhead ────────────────────────────────────────────────────
    final headPaint = Paint()
      ..color = topColor
      ..style = PaintingStyle.fill;

    final tipY  = kaabaY + tp.height / 2;
    final hBase = tipY + r * 0.12;
    final hW    = r * 0.07;

    final path = Path()
      ..moveTo(cx, tipY)
      ..lineTo(cx - hW, hBase)
      ..lineTo(cx + hW, hBase)
      ..close();
    canvas.drawPath(path, headPaint);

    // ── Tail dot ──────────────────────────────────────────────────────
    final tailPaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy + r * 0.22), 5, tailPaint);
  }

  @override
  bool shouldRepaint(_NeedlePainter old) => old.aligned != aligned;
}
