import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../providers/theme_provider.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final Color? color;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final BoxBorder? border;
  final bool? enableBlur;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 10.0,
    this.opacity = 0.2,
    this.color,
    this.borderRadius,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.border,
    this.enableBlur,
  });

  @override
  Widget build(BuildContext context) {
    bool reduce = false;
    try {
      reduce = Provider.of<ThemeProvider>(context).reduceGlowAndBlur;
    } catch (_) {}

    final bool shouldBlur = (enableBlur ?? !reduce) && blur > 0;
    final radius = borderRadius ?? BorderRadius.circular(20);

    final innerContainer = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: (color ?? AppColors.palette.ink).withValues(alpha: opacity),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            (color ?? AppColors.palette.ink).withValues(
                alpha: (opacity * 1.25).clamp(0.0, 1.0)),
            (color ?? AppColors.palette.ink).withValues(alpha: opacity),
          ],
        ),
        borderRadius: radius,
        border: border ??
            Border.all(
              color: AppColors.ink(0.18),
              width: 1.2,
            ),
      ),
      child: child,
    );

    return Container(
      margin: margin,
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: radius,
        child: shouldBlur
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: innerContainer,
              )
            : innerContainer,
      ),
    );
  }
}
