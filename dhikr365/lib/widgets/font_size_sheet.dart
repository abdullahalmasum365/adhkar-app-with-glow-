import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../constants/app_theme.dart';
import '../providers/language_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/user_provider.dart';
import '../utils/responsive.dart';

/// Modal bottom sheet allowing users to customize Arabic and translation reading font sizes
/// with instant live preview and tactile fine-tuning controls.
class FontSizeSheet extends StatelessWidget {
  const FontSizeSheet({super.key});

  /// Presents the modal font size adjustment sheet from any context (Settings or Reader).
  static Future<void> show(BuildContext context) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const FontSizeSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final up = Provider.of<UserProvider>(context);
    final lp = Provider.of<LanguageProvider>(context);
    final tp = Provider.of<ThemeProvider>(context);
    final showTranslit = tp.showTransliteration;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgTeal,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.ink(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            R.px(20),
            R.px(12),
            R.px(20),
            R.px(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Drag Handle ──────────────────────────────────────────────
              Center(
                child: Container(
                  width: R.px(42),
                  height: R.px(4),
                  decoration: BoxDecoration(
                    color: AppColors.ink(0.24),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: R.px(14)),

              // ── Header: Title & Reset ────────────────────────────────────
              Row(
                children: [
                  Container(
                    width: R.px(36),
                    height: R.px(36),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.format_size_rounded,
                      color: Color(0xFF818CF8),
                      size: 20,
                    ),
                  ),
                  SizedBox(width: R.px(10)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lp.getText('font_size_title'),
                          style: AppText.heading(17),
                        ),
                        SizedBox(height: R.px(1)),
                        Text(
                          lp.getText('font_size_desc'),
                          style: AppText.manrope(
                            fontSize: 12,
                            color: AppColors.textSlate400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!up.isDefaultFontSize)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        up.resetFontSizes();
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: R.px(10),
                          vertical: R.px(5),
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.restart_alt_rounded,
                              size: R.sp(13),
                              color: AppColors.primary,
                            ),
                            SizedBox(width: R.px(4)),
                            Text(
                              lp.getText('font_size_reset'),
                              style: TextStyle(
                                fontSize: R.sp(11.5),
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: R.px(16)),

              // ── Live Preview Box ─────────────────────────────────────────
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: R.px(16),
                  vertical: R.px(14),
                ),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.ink(0.08)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          size: R.sp(11),
                          color: AppColors.primary,
                        ),
                        SizedBox(width: R.px(5)),
                        Text(
                          lp.getText('font_size_preview'),
                          style: TextStyle(
                            fontSize: R.sp(9.5),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: R.px(10)),

                    // Arabic Preview
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOut,
                      style: GoogleFonts.amiri(
                        fontSize: up.arabicFontSize,
                        height: 1.6,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                      child: const Text(
                        'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
                        textDirection: TextDirection.rtl,
                      ),
                    ),

                    if (showTranslit) ...[
                      SizedBox(height: R.px(8)),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOut,
                        style: AppText.transliteration(
                          fontSize: (up.translationFontSize - 2.5).clamp(10.0, 18.0),
                          color: AppColors.textSlate400,
                        ),
                        textAlign: TextAlign.center,
                        child: const Text('Subḥānallāhi wa bi-ḥamdih'),
                      ),
                    ],

                    SizedBox(height: R.px(8)),
                    // Translation Preview
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOut,
                      style: TextStyle(
                        fontSize: up.translationFontSize,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textSlate300,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                      child: Text(
                        lp.getText('font_size_preview_text'),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: R.px(18)),

              // ── Section 1: Arabic Font Size Control ───────────────────────
              _buildControlCard(
                title: lp.getText('font_size_arabic'),
                currentSizeText: '${up.arabicFontSize.toStringAsFixed(0)} sp',
                isDefault: (up.arabicFontSize - UserProvider.defaultArabicFontSize).abs() < 0.1,
                defaultBadge: lp.getText('calc_method_default_badge'),
                minLabel: 'A',
                maxLabel: 'A',
                sliderValue: up.arabicFontSize,
                min: UserProvider.minArabicFontSize,
                max: UserProvider.maxArabicFontSize,
                divisions: (UserProvider.maxArabicFontSize - UserProvider.minArabicFontSize).toInt(),
                onSliderChanged: (val) => up.setArabicFontSize(val),
                onDecrement: () {
                  HapticFeedback.selectionClick();
                  up.setArabicFontSize(up.arabicFontSize - 1.0);
                },
                onIncrement: () {
                  HapticFeedback.selectionClick();
                  up.setArabicFontSize(up.arabicFontSize + 1.0);
                },
                presets: [
                  _Preset('22', lp.getText('font_size_small'), 22.0),
                  _Preset('26', lp.getText('font_size_normal'), UserProvider.defaultArabicFontSize),
                  _Preset('30', lp.getText('font_size_large'), 30.0),
                  _Preset('34', lp.getText('font_size_extra'), 34.0),
                ],
                currentSelectedValue: up.arabicFontSize,
                onPresetSelected: (val) {
                  HapticFeedback.selectionClick();
                  up.setArabicFontSize(val);
                },
              ),
              SizedBox(height: R.px(14)),

              // ── Section 2: Translation Font Size Control ──────────────────
              _buildControlCard(
                title: lp.getText('font_size_translation'),
                currentSizeText: '${up.translationFontSize.toStringAsFixed(1)} sp',
                isDefault: (up.translationFontSize - UserProvider.defaultTranslationFontSize).abs() < 0.1,
                defaultBadge: lp.getText('calc_method_default_badge'),
                minLabel: 'A',
                maxLabel: 'A',
                sliderValue: up.translationFontSize,
                min: UserProvider.minTranslationFontSize,
                max: UserProvider.maxTranslationFontSize,
                divisions: ((UserProvider.maxTranslationFontSize - UserProvider.minTranslationFontSize) * 2).toInt(),
                onSliderChanged: (val) => up.setTranslationFontSize(val),
                onDecrement: () {
                  HapticFeedback.selectionClick();
                  up.setTranslationFontSize(up.translationFontSize - 0.5);
                },
                onIncrement: () {
                  HapticFeedback.selectionClick();
                  up.setTranslationFontSize(up.translationFontSize + 0.5);
                },
                presets: [
                  _Preset('13.0', lp.getText('font_size_compact'), 13.0),
                  _Preset('14.5', lp.getText('font_size_normal'), UserProvider.defaultTranslationFontSize),
                  _Preset('16.5', lp.getText('font_size_large'), 16.5),
                  _Preset('18.5', lp.getText('font_size_extra'), 18.5),
                ],
                currentSelectedValue: up.translationFontSize,
                onPresetSelected: (val) {
                  HapticFeedback.selectionClick();
                  up.setTranslationFontSize(val);
                },
              ),
              SizedBox(height: R.px(18)),

              // ── Close / Done Button ──────────────────────────────────────
              ElevatedButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  padding: EdgeInsets.symmetric(vertical: R.px(14)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  lp.getText('font_size_done'),
                  style: TextStyle(
                    fontSize: R.sp(14.5),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlCard({
    required String title,
    required String currentSizeText,
    required bool isDefault,
    required String defaultBadge,
    required String minLabel,
    required String maxLabel,
    required double sliderValue,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onSliderChanged,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
    required List<_Preset> presets,
    required double currentSelectedValue,
    required ValueChanged<double> onPresetSelected,
  }) {
    return Container(
      padding: EdgeInsets.fromLTRB(R.px(14), R.px(12), R.px(14), R.px(12)),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.ink(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: R.sp(13.5),
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: R.px(8),
                  vertical: R.px(3),
                ),
                decoration: BoxDecoration(
                  color: isDefault
                      ? AppColors.ink(0.06)
                      : AppColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDefault
                        ? AppColors.ink(0.12)
                        : AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  isDefault ? '$currentSizeText ($defaultBadge)' : currentSizeText,
                  style: TextStyle(
                    fontSize: R.sp(11),
                    fontWeight: FontWeight.w700,
                    color: isDefault ? AppColors.textSlate400 : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: R.px(6)),

          // Slider with A- and A+ buttons
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon: Text(
                  minLabel,
                  style: TextStyle(
                    fontSize: R.sp(13),
                    fontWeight: FontWeight.w800,
                    color: sliderValue <= min ? AppColors.ink(0.2) : AppColors.primary,
                  ),
                ),
                onPressed: sliderValue <= min ? null : onDecrement,
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: AppColors.ink(0.12),
                    thumbColor: AppColors.primary,
                    overlayColor: AppColors.primary.withValues(alpha: 0.16),
                    trackHeight: 3.5,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.5),
                  ),
                  child: Slider(
                    value: sliderValue.clamp(min, max),
                    min: min,
                    max: max,
                    divisions: divisions,
                    onChanged: onSliderChanged,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon: Text(
                  maxLabel,
                  style: TextStyle(
                    fontSize: R.sp(18),
                    fontWeight: FontWeight.w800,
                    color: sliderValue >= max ? AppColors.ink(0.2) : AppColors.primary,
                  ),
                ),
                onPressed: sliderValue >= max ? null : onIncrement,
              ),
            ],
          ),
          SizedBox(height: R.px(2)),

          // Preset Chips
          Row(
            children: presets.map((preset) {
              final isSelected = (currentSelectedValue - preset.value).abs() < 0.6;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: R.px(3)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => onPresetSelected(preset.value),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: R.px(5)),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.18)
                            : AppColors.ink(0.04),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.ink(0.08),
                          width: isSelected ? 1.2 : 1.0,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            preset.label,
                            style: TextStyle(
                              fontSize: R.sp(10.5),
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? AppColors.primary : AppColors.textSlate400,
                            ),
                          ),
                          Text(
                            preset.name,
                            style: TextStyle(
                              fontSize: R.sp(9),
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.85)
                                  : AppColors.textSlate400.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _Preset {
  final String label;
  final String name;
  final double value;

  const _Preset(this.label, this.name, this.value);
}
