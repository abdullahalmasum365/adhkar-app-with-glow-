// ============================================================================
// lib/constants/app_theme.dart
//
// PALETTE ENGINE — two switchable app-wide color themes:
//
//   • Emerald Night (default) — the original identity: deep green/teal
//     surfaces, warm amber accents, white text.
//   • Royal White — light theme: white/lavender surfaces, royal purple
//     accents, deep-ink text.
//
// Every screen reads colors through the AppColors getters below, so
// switching palettes (Settings → Appearance → App Theme) recolors the whole
// app instantly. ThemeProvider owns the active palette and persists it;
// main() applies the saved palette before the first frame.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/responsive.dart';

/// One complete color scheme for the app.
class AppPalette {
  final String id;
  final String label;
  final String tagline; // short audience-facing description
  final bool isDark;

  final Color primary; // main accent: buttons, highlights
  final Color onPrimary; // text/icons on primary
  final Color accent; // player/secondary accent
  final Color onAccent; // text/icons on accent-filled chips

  final Color bgDark; // scaffold background
  final Color bgDeep; // deepest background (gradients)
  final Color bgTeal; // sheets, dialogs, elevated surfaces
  final Color surfaceElevated; // dropdowns, popovers
  final Color playerSurface; // mini-player card

  final Color ink; // base color for text/borders (opacity-scaled)
  final Color textPrimary;
  final Color textSlate300; // body text
  final Color textSlate400; // secondary text
  final Color textSlate500; // faint text

  final Color bgCard; // translucent card fill
  final Color glassBorder; // translucent card border
  final List<Color> homeGradient; // home screen radial (3 stops)
  final double shadowScale; // softer shadows on light surfaces

  const AppPalette({
    required this.id,
    required this.label,
    required this.tagline,
    required this.isDark,
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.onAccent,
    required this.bgDark,
    required this.bgDeep,
    required this.bgTeal,
    required this.surfaceElevated,
    required this.playerSurface,
    required this.ink,
    required this.textPrimary,
    required this.textSlate300,
    required this.textSlate400,
    required this.textSlate500,
    required this.bgCard,
    required this.glassBorder,
    required this.homeGradient,
    required this.shadowScale,
  });
}

abstract class AppPalettes {
  /// The original identity — deep green night with warm amber.
  static const AppPalette emeraldNight = AppPalette(
    id: 'emerald',
    label: 'Emerald Night',
    tagline: 'Dark • Green & Amber',
    isDark: true,
    primary: Color(0xFFEC7F13),
    onPrimary: Colors.white,
    accent: Color(0xFFF59E0B),
    onAccent: Color(0xFF020617),
    bgDark: Color(0xFF0A1212),
    bgDeep: Color(0xFF050806),
    bgTeal: Color(0xFF1A2E2E),
    surfaceElevated: Color(0xFF0D3330),
    playerSurface: Color(0xFF042F2E),
    ink: Colors.white,
    textPrimary: Colors.white,
    textSlate300: Color(0xFFCBD5E1),
    textSlate400: Color(0xFF94A3B8),
    textSlate500: Color(0xFF64748B),
    bgCard: Color(0x08FFFFFF),
    glassBorder: Color(0x15FFFFFF),
    homeGradient: [Color(0xFF133A36), Color(0xFF0A1F1D), Color(0xFF000000)],
    shadowScale: 1.0,
  );

  /// Light theme — white & lavender surfaces with royal purple.
  static const AppPalette royalWhite = AppPalette(
    id: 'royal',
    label: 'Royal White',
    tagline: 'Light • White & Purple',
    isDark: false,
    primary: Color(0xFF7C3AED),
    onPrimary: Colors.white,
    accent: Color(0xFF8B5CF6),
    onAccent: Colors.white,
    bgDark: Color(0xFFF7F5FC),
    bgDeep: Color(0xFFEFEBF8),
    bgTeal: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    playerSurface: Color(0xFFFFFFFF),
    ink: Color(0xFF241B3E),
    textPrimary: Color(0xFF241B3E),
    textSlate300: Color(0xFF4C4560),
    textSlate400: Color(0xFF6E6685),
    textSlate500: Color(0xFF8D86A3),
    bgCard: Color(0x0D7C3AED),
    glassBorder: Color(0x227C3AED),
    homeGradient: [Color(0xFFE9E1FB), Color(0xFFF6F3FC), Color(0xFFFFFFFF)],
    shadowScale: 0.35,
  );

  /// Classic prayer-app elegance — deep navy night sky with rich gold.
  /// The most popular combination in the category (Muslim Pro–style):
  /// calm, premium, and easy on the eyes at night.
  static const AppPalette sapphireGold = AppPalette(
    id: 'sapphire',
    label: 'Sapphire Gold',
    tagline: 'Dark • Navy & Gold',
    isDark: true,
    primary: Color(0xFFE0A82E),
    onPrimary: Color(0xFF2A1F04),
    accent: Color(0xFFF0C75E),
    onAccent: Color(0xFF2A1F04),
    bgDark: Color(0xFF0A1428),
    bgDeep: Color(0xFF050B18),
    bgTeal: Color(0xFF16264A),
    surfaceElevated: Color(0xFF12203E),
    playerSurface: Color(0xFF0D1B36),
    ink: Colors.white,
    textPrimary: Colors.white,
    textSlate300: Color(0xFFC7D2E8),
    textSlate400: Color(0xFF8FA3C4),
    textSlate500: Color(0xFF64789B),
    bgCard: Color(0x08FFFFFF),
    glassBorder: Color(0x15FFFFFF),
    homeGradient: [Color(0xFF16305E), Color(0xFF0A1428), Color(0xFF000000)],
    shadowScale: 1.0,
  );

  /// Warm and gentle — blush surfaces with deep rose accents.
  /// Soft warm tones consistently rate highest with users who find dark
  /// or high-contrast themes harsh; graceful without losing readability.
  static const AppPalette roseDawn = AppPalette(
    id: 'rose',
    label: 'Rose Dawn',
    tagline: 'Light • Blush & Rose',
    isDark: false,
    primary: Color(0xFFDB2777),
    onPrimary: Colors.white,
    accent: Color(0xFFEC4899),
    onAccent: Colors.white,
    bgDark: Color(0xFFFDF4F7),
    bgDeep: Color(0xFFFAE8EF),
    bgTeal: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    playerSurface: Color(0xFFFFFFFF),
    ink: Color(0xFF3D1F30),
    textPrimary: Color(0xFF3D1F30),
    textSlate300: Color(0xFF5C4250),
    textSlate400: Color(0xFF8A6E7C),
    textSlate500: Color(0xFFAD96A2),
    bgCard: Color(0x0DDB2777),
    glassBorder: Color(0x22DB2777),
    homeGradient: [Color(0xFFFBE3ED), Color(0xFFFDF2F6), Color(0xFFFFFFFF)],
    shadowScale: 0.35,
  );

  /// Monochrome graphite-on-paper — charcoal "pencil" tones on off-white
  /// paper. For users who want a calm, distraction-free, artistic look —
  /// no color at all, just ink and paper, like a hand-drawn sketchbook.
  static const AppPalette pencilSketch = AppPalette(
    id: 'sketch',
    label: 'Pencil Sketch',
    tagline: 'Light • Black & White',
    isDark: false,
    primary: Color(0xFF2B2B2B),
    onPrimary: Colors.white,
    accent: Color(0xFF6B6B6B),
    onAccent: Colors.white,
    bgDark: Color(0xFFFAFAF7),
    bgDeep: Color(0xFFF0F0EC),
    bgTeal: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    playerSurface: Color(0xFFFFFFFF),
    ink: Color(0xFF1F1F1F),
    textPrimary: Color(0xFF1F1F1F),
    textSlate300: Color(0xFF444444),
    textSlate400: Color(0xFF737373),
    textSlate500: Color(0xFF9B9B9B),
    bgCard: Color(0x0D2B2B2B),
    glassBorder: Color(0x1F2B2B2B),
    homeGradient: [Color(0xFFE8E8E4), Color(0xFFF5F5F1), Color(0xFFFFFFFF)],
    shadowScale: 0.35,
  );

  /// Kindle-style E Ink reader — warm paper-gray with true black text and
  /// almost no shadow at all. Real E Ink displays have no glare or depth,
  /// so this theme stays deliberately flat; text uses pure black (not
  /// Pencil Sketch's softer charcoal) for the high-contrast readability
  /// that makes e-readers legible even in direct sunlight.
  static const AppPalette kindleReader = AppPalette(
    id: 'kindle',
    label: 'E Ink Reader',
    tagline: 'Light • Grayscale & Paper',
    isDark: false,
    primary: Color(0xFF000000),
    onPrimary: Colors.white,
    accent: Color(0xFF404040),
    onAccent: Colors.white,
    bgDark: Color(0xFFF2F1EC),
    bgDeep: Color(0xFFE8E6DE),
    bgTeal: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    playerSurface: Color(0xFFFFFFFF),
    ink: Color(0xFF000000),
    textPrimary: Color(0xFF000000),
    textSlate300: Color(0xFF2B2B2B),
    textSlate400: Color(0xFF5C5C5C),
    textSlate500: Color(0xFF8A8A8A),
    bgCard: Color(0x0D000000),
    glassBorder: Color(0x1F000000),
    homeGradient: [Color(0xFFE8E6DE), Color(0xFFF2F1EC), Color(0xFFFFFFFF)],
    shadowScale: 0.15,
  );

  /// Reading-first warmth — cream "mushaf paper" with bronze ink.
  /// Sepia/paper tones are the proven choice for long reading sessions
  /// (every book app's reading mode); familiar to traditional readers.
  static const AppPalette desertMushaf = AppPalette(
    id: 'mushaf',
    label: 'Desert Mushaf',
    tagline: 'Light • Cream & Bronze',
    isDark: false,
    primary: Color(0xFFA16207),
    onPrimary: Colors.white,
    accent: Color(0xFFB45309),
    onAccent: Colors.white,
    bgDark: Color(0xFFF8F2E4),
    bgDeep: Color(0xFFF1E8D2),
    bgTeal: Color(0xFFFFFDF5),
    surfaceElevated: Color(0xFFFFFDF5),
    playerSurface: Color(0xFFFFFDF5),
    ink: Color(0xFF3B2E1A),
    textPrimary: Color(0xFF3B2E1A),
    textSlate300: Color(0xFF59492F),
    textSlate400: Color(0xFF82704F),
    textSlate500: Color(0xFFA4946F),
    bgCard: Color(0x0DA16207),
    glassBorder: Color(0x22A16207),
    homeGradient: [Color(0xFFF0E4C8), Color(0xFFF7F0DE), Color(0xFFFFFDF5)],
    shadowScale: 0.35,
  );

  /// Dreamy pastels — soft lilac surfaces with orchid-pink accents.
  /// The lavender/orchid pastel family tops preference studies with young
  /// female audiences: gentle, elegant, and distinctly "hers" next to the
  /// stronger Royal White purple and the warmer Rose Dawn blush.
  static const AppPalette lilacDream = AppPalette(
    id: 'lilac',
    label: 'Lilac Dream',
    tagline: 'Light • Lilac & Orchid',
    isDark: false,
    primary: Color(0xFFA855F7),
    onPrimary: Colors.white,
    accent: Color(0xFFD946EF),
    onAccent: Colors.white,
    bgDark: Color(0xFFF6F2FC),
    bgDeep: Color(0xFFEEE6FA),
    bgTeal: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    playerSurface: Color(0xFFFFFFFF),
    ink: Color(0xFF35234E),
    textPrimary: Color(0xFF35234E),
    textSlate300: Color(0xFF52406B),
    textSlate400: Color(0xFF7D6C96),
    textSlate500: Color(0xFFA294B8),
    bgCard: Color(0x0DA855F7),
    glassBorder: Color(0x22A855F7),
    homeGradient: [Color(0xFFE7DBF9), Color(0xFFF3EDFB), Color(0xFFFFFFFF)],
    shadowScale: 0.35,
  );

  /// True-black AMOLED — pure black with emerald green.
  /// Black pixels are literally off on OLED screens: maximum battery
  /// savings and the most comfortable choice for late-night dhikr.
  static const AppPalette midnightAmoled = AppPalette(
    id: 'amoled',
    label: 'Midnight Black',
    tagline: 'Dark • AMOLED & Emerald',
    isDark: true,
    primary: Color(0xFF10B981),
    onPrimary: Colors.white,
    accent: Color(0xFF34D399),
    onAccent: Color(0xFF052E16),
    bgDark: Color(0xFF000000),
    bgDeep: Color(0xFF000000),
    bgTeal: Color(0xFF101010),
    surfaceElevated: Color(0xFF161616),
    playerSurface: Color(0xFF0A0A0A),
    ink: Colors.white,
    textPrimary: Colors.white,
    textSlate300: Color(0xFFD1D5DB),
    textSlate400: Color(0xFF9CA3AF),
    textSlate500: Color(0xFF6B7280),
    bgCard: Color(0x0AFFFFFF),
    glassBorder: Color(0x14FFFFFF),
    homeGradient: [Color(0xFF06231C), Color(0xFF021410), Color(0xFF000000)],
    shadowScale: 1.0,
  );

  /// Light theme — soft lavender surfaces with a deep, rich violet accent.
  /// Pairs a pastel background with a much darker, more saturated primary
  /// than Lilac Dream/Royal White for stronger contrast and a moodier feel.
  static const AppPalette lavenderViolet = AppPalette(
    id: 'lavviolet',
    label: 'Lavender Violet',
    tagline: 'Light • Lavender & Violet',
    isDark: false,
    primary: Color(0xFF36255C),
    onPrimary: Colors.white,
    accent: Color(0xFF6B4FA0),
    onAccent: Colors.white,
    bgDark: Color(0xFFF3EEFB),
    bgDeep: Color(0xFFE6D9F5),
    bgTeal: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    playerSurface: Color(0xFFFFFFFF),
    ink: Color(0xFF2A1C47),
    textPrimary: Color(0xFF2A1C47),
    textSlate300: Color(0xFF4A3A6B),
    textSlate400: Color(0xFF7A6996),
    textSlate500: Color(0xFFA394BE),
    bgCard: Color(0x0D36255C),
    glassBorder: Color(0x2236255C),
    homeGradient: [Color(0xFFD2C3F6), Color(0xFFEDE3FA), Color(0xFFFFFFFF)],
    shadowScale: 0.35,
  );

  /// High-energy dark theme — matte carbon black with an electric lime
  /// accent. The highest-contrast, most "gaming/tech" combination in the
  /// set — for users who want dark mode with maximum pop, not calm pastels.
  static const AppPalette carbonLime = AppPalette(
    id: 'carbonlime',
    label: 'Carbon Lime',
    tagline: 'Dark • Carbon & Lime',
    isDark: true,
    primary: Color(0xFFC6FF34),
    onPrimary: Color(0xFF17210A),
    accent: Color(0xFFA6E022),
    onAccent: Color(0xFF17210A),
    bgDark: Color(0xFF171717),
    bgDeep: Color(0xFF0D0D0D),
    bgTeal: Color(0xFF212121),
    surfaceElevated: Color(0xFF262626),
    playerSurface: Color(0xFF1C1C1C),
    ink: Colors.white,
    textPrimary: Colors.white,
    textSlate300: Color(0xFFD4D4D4),
    textSlate400: Color(0xFFA3A3A3),
    textSlate500: Color(0xFF737373),
    bgCard: Color(0x08FFFFFF),
    glassBorder: Color(0x15FFFFFF),
    homeGradient: [Color(0xFF2B2B08), Color(0xFF171717), Color(0xFF000000)],
    shadowScale: 1.0,
  );

  /// Elegant dark theme — near-black cosmic gray with a pale vanilla-cream
  /// accent. Softer and warmer than the AMOLED/Sapphire dark themes.
  static const AppPalette cosmicVanilla = AppPalette(
    id: 'cosmicvanilla',
    label: 'Cosmic Vanilla',
    tagline: 'Dark • Cosmic & Vanilla',
    isDark: true,
    primary: Color(0xFFF1FEC8),
    onPrimary: Color(0xFF23212C),
    accent: Color(0xFFDCEBA0),
    onAccent: Color(0xFF23212C),
    bgDark: Color(0xFF23212C),
    bgDeep: Color(0xFF17151C),
    bgTeal: Color(0xFF2E2B39),
    surfaceElevated: Color(0xFF35313F),
    playerSurface: Color(0xFF1D1B24),
    ink: Colors.white,
    textPrimary: Colors.white,
    textSlate300: Color(0xFFCFCBD9),
    textSlate400: Color(0xFF9B96AA),
    textSlate500: Color(0xFF6E697C),
    bgCard: Color(0x08FFFFFF),
    glassBorder: Color(0x15FFFFFF),
    homeGradient: [Color(0xFF2F2C3D), Color(0xFF1B1922), Color(0xFF000000)],
    shadowScale: 1.0,
  );

  /// True-black dark theme — onyx background with a soft powder "candy
  /// blue" accent. A cooler, calmer sibling to Midnight Black's emerald.
  static const AppPalette onyxCandyBlue = AppPalette(
    id: 'onyxblue',
    label: 'Onyx Candy Blue',
    tagline: 'Dark • Onyx & Candy Blue',
    isDark: true,
    primary: Color(0xFFB2D5E5),
    onPrimary: Color(0xFF06222E),
    accent: Color(0xFF8FC1DA),
    onAccent: Color(0xFF06222E),
    bgDark: Color(0xFF020202),
    bgDeep: Color(0xFF000000),
    bgTeal: Color(0xFF0D1418),
    surfaceElevated: Color(0xFF121B20),
    playerSurface: Color(0xFF060A0C),
    ink: Colors.white,
    textPrimary: Colors.white,
    textSlate300: Color(0xFFCBD9DE),
    textSlate400: Color(0xFF93A8B0),
    textSlate500: Color(0xFF647880),
    bgCard: Color(0x08FFFFFF),
    glassBorder: Color(0x15FFFFFF),
    homeGradient: [Color(0xFF0E1E26), Color(0xFF040A0C), Color(0xFF000000)],
    shadowScale: 1.0,
  );

  /// Jet-black dark theme with a soft pink-purple orchid accent — an
  /// alternative "for her" dark option alongside Lilac Dream's light one.
  static const AppPalette jetOrchid = AppPalette(
    id: 'jetorchid',
    label: 'Jet Orchid',
    tagline: 'Dark • Jet Black & Orchid',
    isDark: true,
    primary: Color(0xFFE5BDDF),
    onPrimary: Color(0xFF3B1F38),
    accent: Color(0xFFD79FD0),
    onAccent: Color(0xFF3B1F38),
    bgDark: Color(0xFF1D1D1D),
    bgDeep: Color(0xFF121212),
    bgTeal: Color(0xFF272727),
    surfaceElevated: Color(0xFF2E2E2E),
    playerSurface: Color(0xFF1A1A1A),
    ink: Colors.white,
    textPrimary: Colors.white,
    textSlate300: Color(0xFFD8D0D6),
    textSlate400: Color(0xFFA69CA2),
    textSlate500: Color(0xFF766D72),
    bgCard: Color(0x08FFFFFF),
    glassBorder: Color(0x15FFFFFF),
    homeGradient: [Color(0xFF2E1F2C), Color(0xFF1D1517), Color(0xFF000000)],
    shadowScale: 1.0,
  );

  /// Moody dark theme — dusty wine-ash surfaces with a fresh turquoise
  /// accent. An unusual, elegant warm-dark/cool-accent pairing.
  static const AppPalette wineTurquoise = AppPalette(
    id: 'wineturquoise',
    label: 'Wine Turquoise',
    tagline: 'Dark • Wine Ash & Turquoise',
    isDark: true,
    primary: Color(0xFF99E1D9),
    onPrimary: Color(0xFF0F2E2A),
    accent: Color(0xFF6FCFC3),
    onAccent: Color(0xFF0F2E2A),
    bgDark: Color(0xFF32292F),
    bgDeep: Color(0xFF231D21),
    bgTeal: Color(0xFF3E333A),
    surfaceElevated: Color(0xFF453942),
    playerSurface: Color(0xFF2A2226),
    ink: Colors.white,
    textPrimary: Colors.white,
    textSlate300: Color(0xFFDCD3D8),
    textSlate400: Color(0xFFAA9EA5),
    textSlate500: Color(0xFF7A7076),
    bgCard: Color(0x08FFFFFF),
    glassBorder: Color(0x15FFFFFF),
    homeGradient: [Color(0xFF1E3733), Color(0xFF241C20), Color(0xFF000000)],
    shadowScale: 1.0,
  );

  static const List<AppPalette> all = [
    emeraldNight,
    royalWhite,
    sapphireGold,
    roseDawn,
    lilacDream,
    desertMushaf,
    pencilSketch,
    kindleReader,
    midnightAmoled,
    lavenderViolet,
    carbonLime,
    cosmicVanilla,
    onyxCandyBlue,
    jetOrchid,
    wineTurquoise,
  ];

  static AppPalette byId(String id) => all.firstWhere(
        (p) => p.id == id,
        orElse: () => emeraldNight,
      );
}

/// Global color access. Same names the codebase always used, backed by the
/// active palette so a theme switch recolors everything on next rebuild.
abstract class AppColors {
  static AppPalette _p = AppPalettes.emeraldNight;
  static AppPalette get palette => _p;
  static void apply(AppPalette p) => _p = p;

  static bool get isDark => _p.isDark;

  static Color get primary => _p.primary;
  static Color get onPrimary => _p.onPrimary;
  static Color get accent => _p.accent;
  static Color get onAccent => _p.onAccent;

  static Color get bgDark => _p.bgDark;
  static Color get bgDeep => _p.bgDeep;
  static Color get bgTeal => _p.bgTeal;
  static Color get surfaceElevated => _p.surfaceElevated;
  static Color get playerSurface => _p.playerSurface;

  static Color get textPrimary => _p.textPrimary;
  static Color get textSlate300 => _p.textSlate300;
  static Color get textSlate400 => _p.textSlate400;
  static Color get textSlate500 => _p.textSlate500;

  static Color get bgCard => _p.bgCard;
  static Color get glassBorder => _p.glassBorder;
  static List<Color> get homeGradient => _p.homeGradient;

  /// Replaces `Colors.white.withOpacity(x)`: white ink on dark surfaces,
  /// deep purple-ink on light ones — readable in both themes.
  static Color ink(double opacity) => _p.ink.withValues(alpha: opacity);

  /// Replaces `Colors.black.withOpacity(x)` for shadows — scaled down on
  /// light surfaces where heavy black shadows look muddy.
  static Color shadow(double opacity) => Colors.black
      .withValues(alpha: (opacity * _p.shadowScale).clamp(0.0, 1.0));
}

abstract class AppText {
  /// UI font — Manrope (does NOT support diacritic transliteration)
  static TextStyle manrope({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double? letterSpacing,
    double? height,
  }) =>
      GoogleFonts.manrope(
        fontSize: R.sp(fontSize),
        fontWeight: fontWeight,
        color: color ?? AppColors.textPrimary,
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
    Color? color,
  }) =>
      GoogleFonts.amiri(
        fontSize: R.sp(fontSize),
        color: color ?? AppColors.textPrimary,
        height: 1.8,
      );

  /// FIX: Transliteration font — NotoSerif supports ALL diacritic characters:
  /// ā ū ī ḥ ḍ ṭ ẓ ṣ ṅ ḡ etc.
  /// Manrope was rendering these as blurry/missing boxes on Android.
  static TextStyle transliteration({
    double fontSize = 14,
    Color? color,
    double? height,
  }) =>
      GoogleFonts.notoSerif(
        fontSize: R.sp(fontSize),
        color: color ?? AppColors.textSlate400,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w400,
        height: height ?? 1.7,
      );

  static TextStyle heading(double size) => manrope(
        fontSize: size,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      );

  static TextStyle label({Color? color}) => manrope(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.textSlate400,
        letterSpacing: 2.0,
      );

  static TextStyle body({Color? color}) => manrope(
      fontSize: 14, color: color ?? AppColors.textSlate300, height: 1.6);
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
          colors: [AppColors.bgTeal, AppColors.bgDark],
        ),
      );
}
