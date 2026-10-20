import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_theme.dart';
import '../models/dhikr.dart';
import '../providers/custom_plan_provider.dart';
import '../providers/dhikr_provider.dart';
import '../providers/language_provider.dart';
import '../providers/theme_provider.dart';

class EditPlanScreen extends StatefulWidget {
  final DhikrCategory category;

  const EditPlanScreen({super.key, required this.category});

  @override
  State<EditPlanScreen> createState() => _EditPlanScreenState();
}

class _EditPlanScreenState extends State<EditPlanScreen> {
  late List<Dhikr> _editableList;
  late List<Dhikr> _initialOrder;
  late Map<String, bool> _enabledStatus;

  @override
  void initState() {
    super.initState();
    _loadDhikrs();
  }

  void _loadDhikrs() {
    final dhikrProvider = Provider.of<DhikrProvider>(context, listen: false);
    final customPlanProvider =
        Provider.of<CustomPlanProvider>(context, listen: false);

    List<Dhikr> defaultDhikrs;
    switch (widget.category) {
      case DhikrCategory.morning:
        defaultDhikrs = dhikrProvider.getMorningDhikrs();
        break;
      case DhikrCategory.evening:
        defaultDhikrs = dhikrProvider.getEveningDhikrs();
        break;
      case DhikrCategory.focus:
        defaultDhikrs = dhikrProvider.getFocusDhikrs();
        break;
      default:
        defaultDhikrs = dhikrProvider.getProtectionDhikrs();
    }

    _initialOrder = List.from(defaultDhikrs);

    // If a custom reordered sequence exists, preserve that ordering
    final customOrder = customPlanProvider.customOrder;
    if (customOrder.isNotEmpty) {
      final sortedList = List<Dhikr>.from(defaultDhikrs);
      sortedList.sort((a, b) {
        final idxA = customOrder.indexOf(a.id);
        final idxB = customOrder.indexOf(b.id);
        if (idxA == -1 && idxB == -1) return 0;
        if (idxA == -1) return 1;
        if (idxB == -1) return -1;
        return idxA.compareTo(idxB);
      });
      _editableList = sortedList;
    } else {
      _editableList = List.from(defaultDhikrs);
    }

    _enabledStatus = {
      for (var d in _editableList) d.id: customPlanProvider.isDhikrEnabled(d.id)
    };
  }

  String _getTitle(LanguageProvider lp) {
    switch (widget.category) {
      case DhikrCategory.morning:
        return lp.getText('edit_morning_plan');
      case DhikrCategory.evening:
        return lp.getText('edit_evening_plan');
      case DhikrCategory.protection:
        return lp.getText('edit_protection_plan');
      case DhikrCategory.focus:
        return lp.getText('edit_focus_plan');
      default:
        return lp.getText('edit_my_plan');
    }
  }

  String _getSaveButtonText(LanguageProvider lp) {
    switch (widget.category) {
      case DhikrCategory.morning:
        return lp.getText('save_morning_plan');
      case DhikrCategory.evening:
        return lp.getText('save_evening_plan');
      default:
        return lp.getText('save_plan');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final lp = Provider.of<LanguageProvider>(context);
    final dp = Provider.of<DhikrProvider>(context);
    final palette = theme.palette;

    return Scaffold(
      backgroundColor: palette.bgDark,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.5,
            colors: [
              palette.homeGradient[0],
              palette.homeGradient[1],
            ],
            stops: const [0.0, 1.0],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // --- Header ---
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: palette.bgDark.withValues(alpha: 0.85),
                      border: Border(
                        bottom: BorderSide(color: AppColors.glassBorder),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back_ios_new,
                              color: AppColors.textPrimary, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Text(
                            _getTitle(lp),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 48), // Balanced spacer
                      ],
                    ),
                  ),

                  // --- Content ---
                  Expanded(
                    child: ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 170),
                      physics: const BouncingScrollPhysics(),
                      itemCount: _editableList.length,
                      proxyDecorator: (child, index, animation) {
                        return AnimatedBuilder(
                          animation: animation,
                          builder: (context, child) {
                            return Material(
                              color: Colors.transparent,
                              elevation: 10,
                              shadowColor:
                                  palette.primary.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(16),
                              child: child,
                            );
                          },
                          child: child,
                        );
                      },
                      // ignore: deprecated_member_use
                      onReorder: (int oldIndex, int newIndex) {
                        setState(() {
                          if (oldIndex < newIndex) {
                            newIndex -= 1;
                          }
                          final Dhikr item = _editableList.removeAt(oldIndex);
                          _editableList.insert(newIndex, item);
                        });
                      },
                      header: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Status Info Banner
                          Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: palette.primary.withValues(alpha: 0.08),
                              border: Border.all(
                                color: palette.primary.withValues(alpha: 0.25),
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.tune_rounded,
                                    color: palette.primary, size: 22),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        lp.getText('edit_plan_info'),
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(Icons.swap_vert_rounded,
                                              color: palette.primary, size: 16),
                                          const SizedBox(width: 4),
                                          Text(
                                            lp.getText(
                                                'edit_plan_reorder_hint'),
                                            style: TextStyle(
                                              color: palette.primary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // List Header
                          Padding(
                            padding: const EdgeInsets.only(
                                bottom: 10.0, left: 4, right: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  lp.getText('edit_plan_sequence'),
                                  style: TextStyle(
                                    color: AppColors.textSlate400,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                Text(
                                  lp.getText('edit_plan_reorder_hint'),
                                  style: TextStyle(
                                    color: AppColors.textSlate400,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      itemBuilder: (context, index) {
                        final dhikr = _editableList[index];
                        // Resolves dynamically to the active language title & translation
                        final localizedDhikr =
                            dp.getDhikrById(dhikr.id) ?? dhikr;
                        final isEnabled = _enabledStatus[dhikr.id] ?? false;

                        return Container(
                          key: ValueKey(dhikr.id),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: isEnabled
                                ? AppColors.bgCard
                                : AppColors.ink(0.02),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isEnabled
                                  ? AppColors.glassBorder
                                  : AppColors.ink(0.06),
                              width: 1.2,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14.0, vertical: 12.0),
                            child: Row(
                              children: [
                                // Drag Handle
                                ReorderableDragStartListener(
                                  index: index,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(
                                      Icons.drag_indicator_rounded,
                                      color: isEnabled
                                          ? palette.primary
                                              .withValues(alpha: 0.8)
                                          : AppColors.textSlate400,
                                      size: 22,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Text Info (Localized)
                                Expanded(
                                  child: Opacity(
                                    opacity: isEnabled ? 1.0 : 0.45,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          localizedDhikr.title,
                                          style: TextStyle(
                                            color: AppColors.textPrimary,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          localizedDhikr.translation,
                                          style: TextStyle(
                                            color: AppColors.textSlate400,
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 10),

                                // Controls: Count Badge & Toggle Switch
                                Opacity(
                                  opacity: isEnabled ? 1.0 : 0.45,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.ink(0.06),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: AppColors.ink(0.12),
                                          ),
                                        ),
                                        child: Text(
                                          "${localizedDhikr.targetCount}x",
                                          style: TextStyle(
                                            color: AppColors.textPrimary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // Toggle Switch (Theme-reactive)
                                      Switch(
                                        value: isEnabled,
                                        activeThumbColor: palette.onPrimary,
                                        activeTrackColor: palette.primary,
                                        inactiveThumbColor: AppColors.ink(0.40),
                                        inactiveTrackColor: AppColors.ink(0.12),
                                        onChanged: (val) {
                                          setState(() {
                                            _enabledStatus[dhikr.id] = val;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              // --- Action Footer ---
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: palette.bgDark.withValues(alpha: 0.95),
                    border: Border(
                      top: BorderSide(color: AppColors.glassBorder, width: 1.2),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          final planProvider = Provider.of<CustomPlanProvider>(
                              context,
                              listen: false);

                          planProvider.savePlan(
                            orderedIds: _editableList.map((d) => d.id).toList(),
                            enabledMap: _enabledStatus,
                          );

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(lp.getText('plan_saved')),
                              backgroundColor: palette.primary,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: palette.primary,
                          foregroundColor: palette.onPrimary,
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 4,
                          shadowColor: palette.primary.withValues(alpha: 0.4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save_rounded, color: palette.onPrimary),
                            const SizedBox(width: 8),
                            Text(
                              _getSaveButtonText(lp),
                              style: TextStyle(
                                color: palette.onPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _editableList = List.from(_initialOrder);
                            for (var key in _enabledStatus.keys) {
                              _enabledStatus[key] = true;
                            }
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: AppColors.glassBorder, width: 1.2),
                          minimumSize: const Size(double.infinity, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          foregroundColor: AppColors.textPrimary,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.restart_alt_rounded,
                                color: AppColors.textSlate400, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              lp.getText('reset_to_default'),
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
