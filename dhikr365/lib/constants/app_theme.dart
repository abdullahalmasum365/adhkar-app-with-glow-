import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/responsive.dart';

abstract class AppColors {
  static const Color primary      = Color(0xFFEC7F13);
  static const Color bgDark       = Color(0xFF0A1212);
  static const Color bgDeep       = Color(0xFF050806);
  static const Color bgTeal       = Color(0xFF1A2E2E);
  static const Color bgCard       = Color(0x08FFFFFF);
  static const Color textSlate300 = Color(0xFFCBD5E1);
  static const Color textSlate400 = Color(0xFF94A3B8);
  static const Color textSlate500 = Color(0xFF64748B);
  static const Color glassBorder  = Color(0x15FFFFFF);
}

abstract class AppText {
  /// UI font — Manrope (does NOT support diacritic transliteration)
  static TextStyle manrope({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color color = Colors.white,
    double? letterSpacing,
    double? height,
  }) =>
      GoogleFonts.manrope(
        fontSize: R.sp(fontSize),
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      ).copyWith(
        // Fallback ensures non-Latin scripts (Arabic, Bengali, Hindi, Thai,
        // Japanese, Chinese, Tamil, etc.) render correctly.
        // Manrope is Latin-only; Roboto + Noto Sans cover the rest.
        fontFamilyFallback: const ['sans-serif'],
      );

  /// Arabic font
  static TextStyle amiri({
    double fontSize = 28,
    Color color = Colors.white,
  }) =>
      GoogleFonts.amiri(
        fontSize: R.sp(fontSize),
        color: color,
        height: 1.8,
      );

  /// FIX: Transliteration font — NotoSerif supports ALL diacritic characters:
  /// ā ū ī ḥ ḍ ṭ ẓ ṣ ṅ ḡ etc.
  /// Manrope was rendering these as blurry/missing boxes on Android.
  static TextStyle transliteration({
    double fontSize = 14,
    Color color = AppColors.textSlate400,
    double? height,
  }) =>
      GoogleFonts.notoSerif(
        fontSize: R.sp(fontSize),
        color: color,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w400,
        height: height ?? 1.7,
      );

  static TextStyle heading(double size) => manrope(
        fontSize: size,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      );

  static TextStyle label({Color color = AppColors.textSlate400}) => manrope(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 2.0,
      );

  static TextStyle body({Color color = AppColors.textSlate300}) =>
      manrope(fontSize: 14, color: color, height: 1.6);
}

abstract class AppDeco {
  static BoxDecoration glassCard({BorderRadius? borderRadius}) => BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      );

  static BoxDecoration radialBg({
    Alignment center = Alignment.topRight,
    double radius = 1.5,
  }) =>
      BoxDecoration(
        gradient: RadialGradient(
          center: center,
          radius: radius,
          colors: const [AppColors.bgTeal, AppColors.bgDark],
        ),
      );
}
