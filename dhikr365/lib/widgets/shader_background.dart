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
//   • Wrapped in RepaintBoundary to isolate GPU canvas rasterization.
//   • Automatically pauses ticker on AppLifecycleState.paused / inactive / hidden
//     and switches to a lightweight static gradient in Low Power Mode (reduceGlowAndBlur).
// ============================================================================

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../constants/app_theme.dart';
import '../providers/theme_provider.dart';

class ShaderBackground extends StatefulWidget {
  const ShaderBackground({super.key});

  @override
  State<ShaderBackground> createState() => _ShaderBackgroundState();
}

class _ShaderBackgroundState extends State<ShaderBackground>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static Future<ui.FragmentProgram>? _programFuture;

  ui.FragmentShader? _shader;
  Ticker? _ticker;
  final ValueNotifier<double> _time = ValueNotifier(0);
  bool _isAppActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _programFuture ??=
        ui.FragmentProgram.fromAsset('shaders/home_background.frag');
    _programFuture!.then((program) {
      if (!mounted) return;
      setState(() => _shader = program.fragmentShader());
      _ticker = createTicker((elapsed) {
        _time.value = elapsed.inMicroseconds / 1e6;
      });
      _updateTickerState();
    }).catchError((e) {
      debugPrint('[ShaderBackground] shader unavailable: $e');
      // Fallback gradient stays — nothing else to do.
    });
  }

  void _updateTickerState([bool? reduceGlow]) {
    if (_ticker == null) return;
    final reduce = reduceGlow ??
        (mounted
            ? Provider.of<ThemeProvider>(context, listen: false)
                .reduceGlowAndBlur
            : false);
    if (!_isAppActive || reduce) {
      _ticker!.muted = true;
    } else {
      if (!_ticker!.isActive) {
        _ticker!.start();
      }
      _ticker!.muted = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppActive = (state == AppLifecycleState.resumed);
    _updateTickerState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.dispose();
    _shader?.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool reduceGlow = false;
    try {
      reduceGlow = Provider.of<ThemeProvider>(context).reduceGlowAndBlur;
    } catch (_) {}

    _updateTickerState(reduceGlow);

    final shader = _shader;
    if (shader == null || reduceGlow) {
      // Static fallback in the same palette (used pre-load & in Low Power / Performance Mode).
      return RepaintBoundary(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.4,
              colors: [AppColors.bgTeal, AppColors.bgDark],
            ),
          ),
          child: const SizedBox.expand(),
        ),
      );
    }
    return RepaintBoundary(
      child: CustomPaint(
        painter: _ShaderPainter(shader, _time),
        size: Size.infinite,
      ),
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
