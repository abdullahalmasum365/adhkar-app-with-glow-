import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Responsive utility — use this everywhere instead of hardcoded numbers.
///
/// USAGE:
///   R.init(context);            // call once at the top of build()
///   R.w(20)                     // 20% of screen width
///   R.h(10)                     // 10% of screen height
///   R.sp(16)                    // font size scaled to screen
///   R.px(24)                    // horizontal padding scaled
///   R.adaptive(small, medium, large)  // different value per device size
/// ─────────────────────────────────────────────────────────────────────────────

class R {
  static late double _width;
  static late double _height;
  static late bool _isTablet;
  static late bool _isSmallPhone;

  /// Call this ONCE at the top of every build() method.
  static void init(BuildContext context) {
    final mq      = MediaQuery.of(context);
    _width        = mq.size.width;
    _height       = mq.size.height;
    _isTablet     = _width >= 600;
    _isSmallPhone = _width < 360;
  }

  static double get screenWidth  => _width;
  static double get screenHeight => _height;
  static bool   get isTablet     => _isTablet;
  static bool   get isSmallPhone => _isSmallPhone;

  /// Percentage of screen WIDTH
  static double w(double percent) => _width * percent / 100;

  /// Percentage of screen HEIGHT
  static double h(double percent) => _height * percent / 100;

  /// Scaled font size — prevents overflow on small screens and
  /// tiny text on large screens.
  static double sp(double size) {
    // Base design width is 390px (iPhone 14)
    final scale = (_width / 390).clamp(0.8, 1.3);
    return size * scale;
  }

  /// Scaled padding/spacing
  static double px(double size) {
    final scale = (_width / 390).clamp(0.75, 1.25);
    return size * scale;
  }

  /// Returns different values for small phone / normal phone / tablet
  static T adaptive<T>(T small, T normal, T tablet) {
    if (_isTablet)     return tablet;
    if (_isSmallPhone) return small;
    return normal;
  }

  /// Safe horizontal padding (scales with screen)
  static EdgeInsets get hPad => EdgeInsets.symmetric(horizontal: px(20));

  /// Clamp a value between min and max
  static double clamp(double value, double min, double max) =>
      value.clamp(min, max);

  // ── Numeral systems for each language code ─────────────────────────────────
  static const Map<String, List<String>> _numerals = {
    'ar': ['٠','١','٢','٣','٤','٥','٦','٧','٨','٩'], // Arabic-Indic
    'ur': ['٠','١','٢','٣','٤','٥','٦','٧','٨','٩'], // Urdu (same codepoints)
    'hi': ['०','१','२','३','४','५','६','७','८','९'], // Devanagari
    'bn': ['০','১','২','৩','৪','৫','৬','৭','৮','৯'], // Bengali
    'ta': ['௦','௧','௨','௩','௪','௫','௬','௭','௮','௯'], // Tamil
    'th': ['๐','๑','๒','๓','๔','๕','๖','๗','๘','๙'], // Thai
  };

  /// Converts ASCII digits 0–9 in [text] to the locale-specific numeral
  /// system, if the language uses one. Returns [text] unchanged for all
  /// other languages (they use standard Western digits).
  ///
  /// Example: R.localizeDigits('70%', 'ar') → '٧٠%'
  static String localizeDigits(String text, String languageCode) {
    final digits = _numerals[languageCode];
    if (digits == null) return text; // no conversion needed
    final buf = StringBuffer();
    for (final ch in text.runes) {
      // ASCII '0' = 48, '9' = 57
      if (ch >= 48 && ch <= 57) {
        buf.write(digits[ch - 48]);
      } else {
        buf.writeCharCode(ch);
      }
    }
    return buf.toString();
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// Device size breakpoints
/// ─────────────────────────────────────────────────────────────────────────────
enum DeviceSize { small, medium, large, tablet }

extension DeviceSizeExtension on BuildContext {
  DeviceSize get deviceSize {
    final w = MediaQuery.of(this).size.width;
    if (w >= 600) return DeviceSize.tablet;
    if (w >= 414) return DeviceSize.large;
    if (w >= 360) return DeviceSize.medium;
    return DeviceSize.small;
  }

  bool get isTablet    => deviceSize == DeviceSize.tablet;
  bool get isSmallPhone => deviceSize == DeviceSize.small;
}
