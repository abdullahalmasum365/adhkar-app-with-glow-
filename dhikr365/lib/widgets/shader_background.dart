// ============================================================================
// lib/widgets/shader_background.dart
//
// GPU-animated flowing background (shaders/home_background.frag).
//
// Design notes:
//   • The FragmentProgram is compiled once and cached statically — every
//     screen that uses this widget shares the same program.
//   • The ticker drives a ValueNotifier that the painter listens to, so
//     each frame only repaints the paint layer — no widget rebuilds.
//   • Until the program loads (or if shaders are unsupported on the device),
//     a static gradient in the same palette is shown, so there is never a
//     black flash or a crash.
// ============================================================================

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../constants/app_theme.dart';

class ShaderBackground extends StatefulWidget {
  const ShaderBackground({super.key});

  @override
  State<ShaderBackground> createState() => _ShaderBackgroundState();
}

class _ShaderBackgroundState extends State<ShaderBackground>
    with SingleTickerProviderStateMixin {
  static Future<ui.FragmentProgram>? _programFuture;

  ui.FragmentShader? _shader;
  Ticker? _ticker;
  final ValueNotifier<double> _time = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _programFuture ??=
        ui.FragmentProgram.fromAsset('shaders/home_background.frag');
    _programFuture!.then((program) {
      if (!mounted) return;
      setState(() => _shader = program.fragmentShader());
      // TickerProviderStateMixin respects TickerMode: the animation pauses
      // automatically when this route is covered or the app is backgrounded.
      _ticker = createTicker((elapsed) {
        _time.value = elapsed.inMicroseconds / 1e6;
      })..start();
    }).catchError((e) {
      debugPrint('[ShaderBackground] shader unavailable: $e');
      // Fallback gradient stays — nothing else to do.
    });
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _shader?.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;
    if (shader == null) {
      // Static fallback in the same palette (also the pre-load frame).
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.4,
            colors: [AppColors.bgTeal, AppColors.bgDark],
          ),
        ),
      );
    }
    return CustomPaint(
      painter: _ShaderPainter(shader, _time),
      size: Size.infinite,
    );
  }
}

class _ShaderPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final ValueListenable<double> time;

  _ShaderPainter(this.shader, this.time) : super(repaint: time);

  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, time.value) // u_time
      ..setFloat(1, size.width) // u_resolution.x
      ..setFloat(2, size.height); // u_resolution.y
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_ShaderPainter old) =>
      old.shader != shader || old.time != time;
}
