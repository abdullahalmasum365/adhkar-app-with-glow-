import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/language_provider.dart';
import '../providers/dhikr_provider.dart';
import 'madhab_selection_screen.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  String _selectedLangCode = 'en';

  final Map<String, String> _langGlyphs = {
    'ar': 'ع',
    'en': 'A',
    'fr': 'F',
    'ur': 'اردو',
    'hi': 'ह',
    'bn': 'অ',
    'ru': 'Я',
    'es': 'E',
    'pt': 'P',
    'de': 'D',
    'it': 'I',
    'nl': 'N',
    'tr': 'T',
    'ms': 'M',
    'id': 'I',
    'th': 'ท',
    'ja': 'あ',
    'zh': '中',
    'ta': 'அ',
  };

  void _onContinue() async {
    // Capture navigator and providers before any await to satisfy
    // use_build_context_synchronously lint.
    final nav = Navigator.of(context);
    final provider = Provider.of<LanguageProvider>(context, listen: false);
    final dhikrProvider = Provider.of<DhikrProvider>(context, listen: false);

    // Set UI language
    await provider.setLanguage(_selectedLangCode);
    // Set translation and transliteration to chosen language to match requirement
    await provider.setTranslationLanguage(_selectedLangCode);
    await provider.setTransliterationLanguage(_selectedLangCode);

    await dhikrProvider.reloadDhikrs(
      uiLanguageCode: _selectedLangCode,
      transliterationCode: _selectedLangCode,
      translationCode: _selectedLangCode,
    );

    if (!mounted) return;
    nav.pushReplacement(
      MaterialPageRoute(builder: (_) => const MadhabSelectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFF48C25);
    const bgDark = Color(0xFF0A1A1A);
    const bgMeshLight = Color(0xFF1A2E2E);
    final lp = Provider.of<LanguageProvider>(context);

    final languagesToShow = LanguageProvider.supportedLanguages
        .where((lang) => _langGlyphs.containsKey(lang['code']))
        .toList();

    final order = [
      'ar',
      'en',
      'fr',
      'ur',
      'hi',
      'bn',
      'ru',
      'es',
      'pt',
      'de',
      'it',
      'nl',
      'tr',
      'ms',
      'id',
      'th',
      'ja',
      'zh',
      'ta'
    ];
    languagesToShow.sort((a, b) =>
        order.indexOf(a['code']!).compareTo(order.indexOf(b['code']!)));

    return Scaffold(
      backgroundColor: bgDark,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topRight,
                radius: 1.5,
                colors: [bgMeshLight, bgDark],
              ),
            ),
          ),
          Opacity(
            opacity: 0.4,
            child: CustomPaint(
              painter: _GeometricOverlayPainter(),
              size: Size.infinite,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Row(
                    children: [
                      if (Navigator.of(context).canPop())
                        InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.05),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 40),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 40),
                          child: Text(
                            lp.getText('app_title').toUpperCase(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.4,
                              color:
                                  Color(0xCCF48C25), // primary with 80% opacity
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  lp.getText('select_language'),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: Colors.white,
                  ),
                ).animate().fadeIn().moveY(begin: -20, end: 0),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    lp.getText('select_language_desc'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.6),
                      height: 1.5,
                    ),
                  ),
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 32),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 140),
                    itemCount: languagesToShow.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final lang = languagesToShow[index];
                      final isSelected = _selectedLangCode == lang['code'];

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedLangCode = lang['code']!;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? primaryColor
                                  : Colors.white.withOpacity(0.08),
                              width: 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: primaryColor.withOpacity(0.15),
                                      blurRadius: 20,
                                      spreadRadius: 0,
                                    )
                                  ]
                                : [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 10,
                                    )
                                  ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                    width: 1,
                                  ),
                                  color: Colors.white.withOpacity(0.05),
                                ),
                                child: Center(
                                  child: Text(
                                    _langGlyphs[lang['code']] ?? 'A',
                                    style: TextStyle(
                                      // No fontFamily — let the system font
                                      // handle Arabic (ع), Bengali (অ),
                                      // Hindi (ह), Thai (ท), etc.
                                      fontSize: 24,
                                      color: primaryColor.withOpacity(0.8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      lang['name']!,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      lang['nativeName']!,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white.withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? primaryColor
                                      : Colors.transparent,
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check,
                                        color: bgDark,
                                        size: 16,
                                      )
                                    : null,
                              )
                            ],
                          ),
                        ),
                      )
                          .animate()
                          .fadeIn(delay: (50 * index).ms)
                          .slideY(begin: 0.1, end: 0);
                    },
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: -96,
            left: 0,
            right: 0,
            child: Container(
              height: 256,
              decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.rectangle,
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.1),
                      blurRadius: 120,
                      spreadRadius: 60,
                    )
                  ]),
            ),
          ),
          Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      bgDark,
                      bgDark.withOpacity(0.95),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: _onContinue,
                      child: Container(
                        height: 64,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.3),
                              blurRadius: 30,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              lp.getText('continue'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: bgDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.chevron_right,
                              color: bgDark,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 24,
                          height: 6,
                          decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ))
        ],
      ),
    );
  }
}

class _GeometricOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF48C25).withOpacity(0.03) // 3% orange
      ..style = PaintingStyle.fill;

    const double patternSize = 60.0;

    // Pattern path: M30 0 l15 30 -15 30 -15 -30 z
    final path = Path();
    path.moveTo(30, 0);
    path.lineTo(45, 30);
    path.lineTo(30, 60);
    path.lineTo(15, 30);
    path.close();

    for (double y = 0; y < size.height; y += patternSize) {
      for (double x = 0; x < size.width; x += patternSize) {
        canvas.save();
        canvas.translate(x, y);
        canvas.drawPath(path, paint);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
