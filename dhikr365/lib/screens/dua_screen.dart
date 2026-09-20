import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../models/dhikr.dart';
import '../providers/dhikr_provider.dart';
import '../providers/language_provider.dart';
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

  // titleKey = i18n key; title = fallback for null-category items with no key yet
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
        count: 6,
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

    // Pre-resolve translated strings once — passed down to cards
    final duasLabel = lp.getText('duas_count');
    final comingSoon = lp.getText('coming_soon');

    // Build resolved list (translated titles) then filter by query
    final resolvedCats = _cats.map((cat) {
      final resolvedTitle =
          cat.titleKey != null ? lp.getText(cat.titleKey!) : cat.title;
      return (cat: cat, resolvedTitle: resolvedTitle);
    }).toList();

    final filteredCats = _query.isEmpty
        ? resolvedCats
        : resolvedCats
            .where(
              (e) =>
                  e.resolvedTitle
                      .toLowerCase()
                      .contains(_query.toLowerCase()) ||
                  e.cat.title.toLowerCase().contains(_query.toLowerCase()),
            )
            .toList();

    // FIX: LayoutBuilder reads real screen dimensions
    return LayoutBuilder(builder: (context, constraints) {
      final h = constraints.maxHeight;
      final w = constraints.maxWidth;
      final isSmall = h < 680; // compact phone (SE, A03 …)
      final isTablet = w >= 600; // tablet → 3-column grid

      // Responsive values — no hardcoded px that overflow
      final hPad = isTablet ? 32.0 : 24.0;
      final topPad = isSmall ? 12.0 : 20.0;
      final searchH = isSmall ? 40.0 : 46.0;
      final crossCount = isTablet ? 3 : 2;
      final childRatio = isTablet ? 1.3 : (isSmall ? 1.15 : 1.25);
      final gridBottom = isSmall ? 80.0 : 120.0;
      final titleSize = isSmall ? 22.0 : 28.0;

      return Scaffold(
        backgroundColor: AppColors.bgDark,
        body: Container(
          decoration: AppDeco.radialBg(center: Alignment.topLeft),
          // FIX: SafeArea on every side — prevents status-bar + nav-bar overlap
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
                      // FIX: font size shrinks on small screens
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
                    decoration: AppDeco.glassCard(),
                    child: Row(children: [
                      Icon(Icons.search,
                          color: AppColors.textSlate500, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _query = val),
                          style: AppText.body(),
                          decoration: InputDecoration(
                            hintText: lp.getText('search_duas'),
                            hintStyle:
                                AppText.body(color: AppColors.textSlate500),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      // Clear button — only visible when there is text
                      if (_query.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          child: Icon(Icons.close_rounded,
                              color: AppColors.textSlate500, size: 18),
                        ),
                    ]),
                  ),
                ).animate().fadeIn(delay: 150.ms),

                // ── Grid or empty state ───────────────────────────────────────
                Expanded(
                  child: filteredCats.isEmpty
                      ? _buildNoResults(lp, isSmall)
                      : GridView.builder(
                          // FIX: padding uses gridBottom so content clears the nav bar
                          padding:
                              EdgeInsets.fromLTRB(hPad, 4, hPad, gridBottom),
                          physics: const BouncingScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossCount,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            // FIX: childAspectRatio responds to screen size
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
                                .fadeIn(
                                    delay: Duration(milliseconds: 50 + i * 40))
                                .slideY(begin: 0.08)
                                .shimmer(
                                  delay: Duration(milliseconds: 200 + i * 60),
                                  duration: const Duration(milliseconds: 600),
                                  color: AppColors.ink(0.18),
                                  angle: 0.3,
                                );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildNoResults(LanguageProvider lp, bool isSmall) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: isSmall ? 48 : 60,
              color: AppColors.textSlate500,
            ),
            const SizedBox(height: 16),
            Text(
              'No results for "$_query"',
              textAlign: TextAlign.center,
              style: AppText.manrope(
                fontSize: isSmall ? 15 : 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textSlate400,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different keyword',
              textAlign: TextAlign.center,
              style: AppText.body(color: AppColors.textSlate500),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Category note bottom sheet ────────────────────────────────────────────────
// Shown when the user opens a category that has an introductory note.
// Parameterised by color and icon so it works for any category.

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
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Drag handle ───────────────────────────────────────────────
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

                // ── Icon + title row ──────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: color,
                        size: 22,
                      ),
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

                // ── Divider ───────────────────────────────────────────────────
                Container(
                  height: 1,
                  color: AppColors.ink(0.08),
                ),

                const SizedBox(height: 16),

                // ── Body text ─────────────────────────────────────────────────
                Text(
                  body,
                  style: AppText.body(color: AppColors.textSlate300)
                      .copyWith(fontSize: 13.5, height: 1.7),
                ),

                const SizedBox(height: 28),

                // ── Continue button ───────────────────────────────────────────
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

// ── Data model ────────────────────────────────────────────────────────────────

class _Cat {
  final IconData icon;
  final String?
      titleKey; // i18n key; null for categories without translation yet
  final String title; // English fallback
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

// ── Card widget ───────────────────────────────────────────────────────────────

class _CatCard extends StatelessWidget {
  final _Cat cat;
  final bool isSmall;
  final int count;
  final String resolvedTitle; // already-translated title from parent
  final String duasLabel; // translated word for "duas"
  final String comingSoon; // translated "coming soon"

  const _CatCard({
    required this.cat,
    required this.isSmall,
    required this.count,
    required this.resolvedTitle,
    required this.duasLabel,
    required this.comingSoon,
  });

  void _onTap(BuildContext context) {
    if (cat.category == DhikrCategory.parents) {
      // Show the informational note before entering the parents duas list.
      final lp = Provider.of<LanguageProvider>(context, listen: false);
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
            Navigator.pop(context); // close sheet
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
      final lp = Provider.of<LanguageProvider>(context, listen: false);
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
    return GestureDetector(
      onTap: () => _onTap(context),
      child: Container(
        // FIX: padding uses EdgeInsets not const so it can adapt if needed
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
            // Icon box
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: cat.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(cat.icon, color: cat.color, size: 18),
            ),

            // Title + count
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // FIX: FittedBox ensures long translated titles don't overflow
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
