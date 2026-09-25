import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../models/dhikr.dart';
import '../providers/dhikr_provider.dart';
import '../providers/language_provider.dart';
import '../services/dua_search_service.dart';
import 'dhikr_focus_screen.dart';
import 'dhikr_list_screen.dart';

class DuaScreen extends StatefulWidget {
  const DuaScreen({super.key});

  @override
  State<DuaScreen> createState() => _DuaScreenState();
}

class _DuaScreenState extends State<DuaScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static const List<_Cat> _cats = [
    _Cat(
        icon: Icons.wb_sunny_outlined,
        titleKey: 'morning_adhkar',
        title: 'Morning Adhkar',
        count: 29,
        color: Color(0xFFEC7F13),
        category: DhikrCategory.morning),
    _Cat(
        icon: Icons.nights_stay_outlined,
        titleKey: 'evening_adhkar',
        title: 'Evening Adhkar',
        count: 29,
        color: Color(0xFF6366F1),
        category: DhikrCategory.evening),
    _Cat(
        icon: Icons.mosque_outlined,
        titleKey: 'after_salah',
        title: 'After Salah',
        count: 10,
        color: Color(0xFF14B8A6),
        category: DhikrCategory.afterSalah),
    _Cat(
        icon: Icons.shield_outlined,
        titleKey: 'protection',
        title: 'Daily Protection',
        count: 5,
        color: Color(0xFFEF4444),
        category: DhikrCategory.protection),
    _Cat(
        icon: Icons.filter_center_focus,
        titleKey: 'focus',
        title: 'Focus & Dhikr',
        count: 10,
        color: Color(0xFF10B981),
        category: DhikrCategory.focus),
    _Cat(
        icon: Icons.restaurant_outlined,
        titleKey: 'food_eating',
        title: 'Food & Eating',
        count: 9,
        color: Color(0xFFF59E0B),
        category: DhikrCategory.food),
    _Cat(
        icon: Icons.family_restroom_outlined,
        titleKey: 'parents',
        title: 'Duas for Parents',
        count: 4,
        color: Color(0xFFEC4899),
        category: DhikrCategory.parents),
    _Cat(
        icon: Icons.landscape_outlined,
        titleKey: 'graveyard',
        title: 'Graveyard',
        count: 1,
        color: Color(0xFF64748B),
        category: DhikrCategory.graveyard),
    _Cat(
        icon: Icons.bedtime_outlined,
        titleKey: 'before_sleep',
        title: 'Before Sleep',
        count: 14,
        color: Color(0xFF6366F1),
        category: DhikrCategory.beforeSleep),
    _Cat(
        icon: Icons.flight_takeoff_rounded,
        titleKey: 'travel',
        title: 'Travel & Journey',
        count: 4,
        color: Color(0xFF0EA5E9),
        category: DhikrCategory.travel),
    _Cat(
        icon: Icons.healing_rounded,
        titleKey: 'shifa',
        title: 'Healing & Relief',
        count: 4,
        color: Color(0xFF059669),
        category: DhikrCategory.shifa),
    _Cat(
        icon: Icons.favorite_rounded,
        titleKey: 'distress',
        title: 'Anxiety & Debt Relief',
        count: 5,
        color: Color(0xFF8B5CF6),
        category: DhikrCategory.distress),
  ];

  static _Cat getCategoryMeta(DhikrCategory category) {
    return _cats.firstWhere(
      (c) => c.category == category,
      orElse: () => _cats.first,
    );
  }

  static void openCategory(
    BuildContext context,
    _Cat cat,
    String resolvedTitle,
  ) {
    final lp = Provider.of<LanguageProvider>(context, listen: false);

    if (cat.category == DhikrCategory.parents) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _NoteSheet(
          color: const Color(0xFFEC4899),
          icon: Icons.family_restroom_outlined,
          title: lp.getText('parents_note_title'),
          body: lp.getText('parents_note_body'),
          buttonLabel: resolvedTitle,
          onContinue: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const DhikrListScreen(category: DhikrCategory.parents),
              ),
            );
          },
        ),
      );
    } else if (cat.category == DhikrCategory.graveyard) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _NoteSheet(
          color: const Color(0xFF64748B),
          icon: Icons.landscape_outlined,
          title: lp.getText('graveyard_note_title'),
          body: lp.getText('graveyard_note_body'),
          buttonLabel: resolvedTitle,
          onContinue: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const DhikrListScreen(category: DhikrCategory.graveyard),
              ),
            );
          },
        ),
      );
    } else if (cat.category != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DhikrListScreen(category: cat.category!),
        ),
      );
    } else {
      final comingSoon = lp.getText('coming_soon');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$resolvedTitle — $comingSoon',
              style: TextStyle(color: AppColors.onPrimary)),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);
    final dp = Provider.of<DhikrProvider>(context);

    final liveCounts = {
      DhikrCategory.morning: dp.getMorningDhikrs().length,
      DhikrCategory.evening: dp.getEveningDhikrs().length,
      DhikrCategory.protection: dp.getProtectionDhikrs().length,
      DhikrCategory.focus: dp.getFocusDhikrs().length,
      DhikrCategory.parents: dp.getParentsDhikrs().length,
      DhikrCategory.graveyard: dp.getGraveyardDhikrs().length,
      DhikrCategory.food: dp.getFoodDhikrs().length,
      DhikrCategory.afterSalah: dp.getAfterSalahDhikrs().length,
      DhikrCategory.beforeSleep: dp.getBeforeSleepDhikrs().length,
      DhikrCategory.travel: dp.getTravelDhikrs().length,
      DhikrCategory.shifa: dp.getShifaDhikrs().length,
      DhikrCategory.distress: dp.getDistressDhikrs().length,
    };

    final duasLabel = lp.getText('duas_count');
    final comingSoon = lp.getText('coming_soon');

    // Build resolved categories list (translated titles)
    final resolvedCats = _cats.map((cat) {
      final resolvedTitle =
          cat.titleKey != null ? lp.getText(cat.titleKey!) : cat.title;
      return (cat: cat, resolvedTitle: resolvedTitle);
    }).toList();

    final isSearching = _query.trim().isNotEmpty;

    // Filter categories that match query
    final matchedCats = !isSearching
        ? resolvedCats
        : resolvedCats.where((e) {
            final q = _query.toLowerCase();
            return e.resolvedTitle.toLowerCase().contains(q) ||
                e.cat.title.toLowerCase().contains(q);
          }).toList();

    // Google-like Deep Dua Search across all 120+ Dhikrs
    final searchResults = isSearching
        ? DuaSearchService.search(
            allDhikrs: dp.dhikrs,
            query: _query,
          )
        : <DuaSearchResult>[];

    return LayoutBuilder(builder: (context, constraints) {
      final h = constraints.maxHeight;
      final w = constraints.maxWidth;
      final isSmall = h < 680;
      final isTablet = w >= 600;

      final hPad = isTablet ? 32.0 : 24.0;
      final topPad = isSmall ? 12.0 : 20.0;
      final searchH = isSmall ? 42.0 : 48.0;
      final crossCount = isTablet ? 3 : 2;
      final childRatio = isTablet ? 1.3 : (isSmall ? 1.15 : 1.25);
      final gridBottom = isSmall ? 80.0 : 120.0;
      final titleSize = isSmall ? 22.0 : 28.0;

      return Scaffold(
        backgroundColor: AppColors.bgDark,
        body: Container(
          decoration: AppDeco.radialBg(center: Alignment.topLeft),
          child: SafeArea(
            bottom: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(hPad, topPad, hPad, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lp.getText('supplications').toUpperCase(),
                        style: AppText.label(color: AppColors.primary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lp.getText('dua_collection'),
                        style: AppText.heading(titleSize),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lp.getText('authentic_duas'),
                        style: AppText.body(color: AppColors.textSlate400),
                      ),
                    ],
                  ),
                ).animate().fadeIn().slideY(begin: -0.1),

                // ── Search bar ───────────────────────────────────────────────
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 12),
                  child: Container(
                    height: searchH,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.ink(0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSearching
                            ? AppColors.primary.withValues(alpha: 0.6)
                            : AppColors.ink(0.12),
                        width: isSearching ? 1.5 : 1.0,
                      ),
                      boxShadow: isSearching
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                blurRadius: 12,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    child: Row(children: [
                      Icon(
                        Icons.search_rounded,
                        color: isSearching
                            ? AppColors.primary
                            : AppColors.textSlate500,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _query = val),
                          style: AppText.body(color: AppColors.textPrimary)
                              .copyWith(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: lp.getText('search_duas'),
                            hintStyle:
                                AppText.body(color: AppColors.textSlate500)
                                    .copyWith(fontSize: 14),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (isSearching)
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.ink(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.close_rounded,
                                color: AppColors.textSlate300, size: 16),
                          ),
                        ),
                    ]),
                  ),
                ).animate().fadeIn(delay: 150.ms),

                // ── Body: Category Grid OR Search Results ───────────────────
                Expanded(
                  child: !isSearching
                      ? _buildCategoryGrid(
                          filteredCats: resolvedCats,
                          hPad: hPad,
                          gridBottom: gridBottom,
                          crossCount: crossCount,
                          childRatio: childRatio,
                          isSmall: isSmall,
                          liveCounts: liveCounts,
                          duasLabel: duasLabel,
                          comingSoon: comingSoon,
                        )
                      : _buildSearchResultsView(
                          lp: lp,
                          query: _query,
                          matchedCats: matchedCats,
                          searchResults: searchResults,
                          hPad: hPad,
                          gridBottom: gridBottom,
                          isSmall: isSmall,
                          liveCounts: liveCounts,
                          duasLabel: duasLabel,
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  /// Default Category Grid view when search is empty
  Widget _buildCategoryGrid({
    required List<({_Cat cat, String resolvedTitle})> filteredCats,
    required double hPad,
    required double gridBottom,
    required int crossCount,
    required double childRatio,
    required bool isSmall,
    required Map<DhikrCategory, int> liveCounts,
    required String duasLabel,
    required String comingSoon,
  }) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, gridBottom),
      physics: const BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: childRatio,
      ),
      itemCount: filteredCats.length,
      itemBuilder: (context, i) {
        final entry = filteredCats[i];
        final cat = entry.cat;
        return _CatCard(
          cat: cat,
          isSmall: isSmall,
          count: cat.category != null
              ? (liveCounts[cat.category] ?? cat.count)
              : cat.count,
          resolvedTitle: entry.resolvedTitle,
          duasLabel: duasLabel,
          comingSoon: comingSoon,
        )
            .animate()
            .fadeIn(delay: Duration(milliseconds: 30 + i * 30))
            .slideY(begin: 0.08);
      },
    );
  }

  /// Google-like Search Results View (Categorical Quick Jump + Rich Dua Cards)
  Widget _buildSearchResultsView({
    required LanguageProvider lp,
    required String query,
    required List<({_Cat cat, String resolvedTitle})> matchedCats,
    required List<DuaSearchResult> searchResults,
    required double hPad,
    required double gridBottom,
    required bool isSmall,
    required Map<DhikrCategory, int> liveCounts,
    required String duasLabel,
  }) {
    if (matchedCats.isEmpty && searchResults.isEmpty) {
      return _buildNoResults(lp, query, isSmall);
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, gridBottom),
      physics: const BouncingScrollPhysics(),
      children: [
        // ── 1. Matching Categories Quick-Chips ──────────────────────────────
        if (matchedCats.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: Row(
              children: [
                Icon(Icons.folder_outlined,
                    size: 14, color: AppColors.textSlate400),
                const SizedBox(width: 6),
                Text(
                  'CATEGORIES (${matchedCats.length})',
                  style: AppText.label(color: AppColors.textSlate400)
                      .copyWith(fontSize: 11, letterSpacing: 1.2),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: matchedCats.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final entry = matchedCats[idx];
                final cat = entry.cat;
                final count = liveCounts[cat.category] ?? cat.count;
                return GestureDetector(
                  onTap: () => openCategory(context, cat, entry.resolvedTitle),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: cat.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: cat.color.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(cat.icon, size: 15, color: cat.color),
                        const SizedBox(width: 6),
                        Text(
                          entry.resolvedTitle,
                          style: AppText.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: cat.color.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: AppText.manrope(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── 2. Matching Duas Header ─────────────────────────────────────────
        if (searchResults.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'SUPPLICATIONS (${searchResults.length})',
                      style: AppText.label(color: AppColors.primary)
                          .copyWith(fontSize: 11, letterSpacing: 1.2),
                    ),
                  ],
                ),
                Text(
                  '${searchResults.length} $duasLabel found',
                  style: AppText.body(color: AppColors.textSlate400)
                      .copyWith(fontSize: 11),
                ),
              ],
            ),
          ),

          // ── 3. Dua Search Result Cards ─────────────────────────────────────
          ...List.generate(searchResults.length, (i) {
            final res = searchResults[i];
            final dhikr = res.dhikr;
            final catMeta = getCategoryMeta(dhikr.category);
            final resolvedCatTitle = catMeta.titleKey != null
                ? lp.getText(catMeta.titleKey!)
                : catMeta.title;

            return _SearchResultCard(
              result: res,
              query: query,
              catMeta: catMeta,
              resolvedCatTitle: resolvedCatTitle,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DhikrFocusScreen(dhikr: dhikr),
                  ),
                );
              },
              onCategoryTap: () {
                openCategory(context, catMeta, resolvedCatTitle);
              },
            )
                .animate()
                .fadeIn(delay: Duration(milliseconds: (i * 25).clamp(0, 400)))
                .slideY(begin: 0.05);
          }),
        ],
      ],
    );
  }

  Widget _buildNoResults(LanguageProvider lp, String query, bool isSmall) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.ink(0.04),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.ink(0.08)),
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: isSmall ? 40 : 48,
                color: AppColors.textSlate500,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No results for "$query"',
              textAlign: TextAlign.center,
              style: AppText.manrope(
                fontSize: isSmall ? 15 : 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try searching by keyword, meaning, or topic:\n"kursi", "forgiveness", "ঘুম", "খাবার", "ক্ষমা", "ঋণ", "রিজিক"',
              textAlign: TextAlign.center,
              style: AppText.body(color: AppColors.textSlate400)
                  .copyWith(fontSize: 12.5, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Search Result Card ────────────────────────────────────────────────────────

class _SearchResultCard extends StatelessWidget {
  final DuaSearchResult result;
  final String query;
  final _Cat catMeta;
  final String resolvedCatTitle;
  final VoidCallback onTap;
  final VoidCallback onCategoryTap;

  const _SearchResultCard({
    required this.result,
    required this.query,
    required this.catMeta,
    required this.resolvedCatTitle,
    required this.onTap,
    required this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    final d = result.dhikr;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.ink(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.ink(0.08)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          highlightColor: catMeta.color.withValues(alpha: 0.08),
          splashColor: catMeta.color.withValues(alpha: 0.12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Meta row (Category Chip + Target Count badge)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: onCategoryTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: catMeta.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: catMeta.color.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(catMeta.icon, size: 12, color: catMeta.color),
                            const SizedBox(width: 5),
                            Text(
                              resolvedCatTitle,
                              style: AppText.manrope(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: catMeta.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (d.targetCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.ink(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${d.targetCount}x',
                          style: AppText.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSlate300,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Title with matched highlight
                HighlightedText(
                  text: d.title,
                  query: query,
                  baseStyle: AppText.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  highlightStyle: AppText.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFFBBF24),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),

                // Arabic Text snippet
                if (d.arabicText.isNotEmpty) ...[
                  Text(
                    d.arabicText,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.amiri(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Translation with matched highlight
                if (d.translation.isNotEmpty) ...[
                  HighlightedText(
                    text: d.translation,
                    query: query,
                    baseStyle: AppText.body(color: AppColors.textSlate400)
                        .copyWith(fontSize: 12.5, height: 1.45),
                    highlightStyle: AppText.body(color: const Color(0xFFFDE68A))
                        .copyWith(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            height: 1.45),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 10),
                ],

                // Matched Context Snippet (if matched in benefit, reference, etc.)
                if (result.snippet != null) ...[
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.ink(0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.ink(0.08)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb_outline_rounded,
                            size: 13, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Matched: ${result.snippet!}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body(color: AppColors.textSlate300)
                                .copyWith(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Bottom Action Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (d.reference != null && d.reference!.isNotEmpty)
                      Flexible(
                        child: Text(
                          d.reference!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(color: AppColors.textSlate500)
                              .copyWith(fontSize: 10.5),
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    Row(
                      children: [
                        Text(
                          'Read & Count',
                          style: AppText.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios_rounded,
                            size: 10, color: AppColors.primary),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Highlighted Text Widget ───────────────────────────────────────────────────

class HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle baseStyle;
  final TextStyle highlightStyle;
  final int maxLines;
  final TextOverflow overflow;
  final TextAlign textAlign;

  const HighlightedText({
    super.key,
    required this.text,
    required this.query,
    required this.baseStyle,
    required this.highlightStyle,
    this.maxLines = 2,
    this.overflow = TextOverflow.ellipsis,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) {
      return Text(text,
          style: baseStyle,
          maxLines: maxLines,
          overflow: overflow,
          textAlign: textAlign);
    }

    final lower = text.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    // Search query or first token
    final searchTerms = cleanQuery
        .split(' ')
        .where((t) => t.length >= 2)
        .toList();
    if (searchTerms.isEmpty) searchTerms.add(cleanQuery);

    // Simplest robust highlight: highlight occurrences of any search term
    final matchIndices = <({int start, int end})>[];
    for (final term in searchTerms) {
      int s = 0;
      while (s < lower.length) {
        final idx = lower.indexOf(term, s);
        if (idx == -1) break;
        matchIndices.add((start: idx, end: idx + term.length));
        s = idx + term.length;
      }
    }

    // Sort and merge overlapping match ranges
    matchIndices.sort((a, b) => a.start.compareTo(b.start));
    final merged = <({int start, int end})>[];
    for (final m in matchIndices) {
      if (merged.isEmpty) {
        merged.add(m);
      } else {
        final last = merged.last;
        if (m.start <= last.end) {
          merged[merged.length - 1] =
              (start: last.start, end: m.end > last.end ? m.end : last.end);
        } else {
          merged.add(m);
        }
      }
    }

    if (merged.isEmpty) {
      return Text(text,
          style: baseStyle,
          maxLines: maxLines,
          overflow: overflow,
          textAlign: textAlign);
    }

    for (final range in merged) {
      if (range.start > start) {
        spans.add(TextSpan(
          text: text.substring(start, range.start),
          style: baseStyle,
        ));
      }
      spans.add(TextSpan(
        text: text.substring(range.start, range.end),
        style: highlightStyle,
      ));
      start = range.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: baseStyle,
      ));
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}

// ── Category note bottom sheet ────────────────────────────────────────────────

class _NoteSheet extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String body;
  final String buttonLabel;
  final VoidCallback onContinue;

  const _NoteSheet({
    required this.color,
    required this.icon,
    required this.title,
    required this.body,
    required this.buttonLabel,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgTeal,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.ink(0.24),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        title,
                        style: AppText.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  height: 1,
                  color: AppColors.ink(0.08),
                ),
                const SizedBox(height: 16),
                Text(
                  body,
                  style: AppText.body(color: AppColors.textSlate300)
                      .copyWith(fontSize: 13.5, height: 1.7),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: onContinue,
                    icon: Icon(Icons.arrow_forward_rounded,
                        color: AppColors.textPrimary, size: 18),
                    label: Text(
                      buttonLabel,
                      style: AppText.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: AppColors.onPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Category Data Model ───────────────────────────────────────────────────────

class _Cat {
  final IconData icon;
  final String? titleKey;
  final String title;
  final int count;
  final Color color;
  final DhikrCategory? category;

  const _Cat({
    required this.icon,
    required this.titleKey,
    required this.title,
    required this.count,
    required this.color,
    required this.category,
  });
}

// ── Category Card widget ──────────────────────────────────────────────────────

class _CatCard extends StatelessWidget {
  final _Cat cat;
  final bool isSmall;
  final int count;
  final String resolvedTitle;
  final String duasLabel;
  final String comingSoon;

  const _CatCard({
    required this.cat,
    required this.isSmall,
    required this.count,
    required this.resolvedTitle,
    required this.duasLabel,
    required this.comingSoon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _DuaScreenState.openCategory(context, cat, resolvedTitle),
      child: Container(
        padding: EdgeInsets.all(isSmall ? 10 : 14),
        decoration: BoxDecoration(
          color: AppColors.ink(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cat.color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: cat.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(cat.icon, color: cat.color, size: 18),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    resolvedTitle,
                    style: AppText.manrope(
                        fontSize: isSmall ? 11 : 12,
                        fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '$count $duasLabel',
                        style: AppText.manrope(
                            fontSize: 10, color: AppColors.textSlate500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (cat.category != null) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 8,
                        color: cat.color.withValues(alpha: 0.7),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
