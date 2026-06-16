import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/dhikr.dart';
import '../providers/custom_plan_provider.dart';
import '../providers/dhikr_provider.dart';

class EditPlanScreen extends StatefulWidget {
  final DhikrCategory category;

  const EditPlanScreen({super.key, required this.category});

  @override
  State<EditPlanScreen> createState() => _EditPlanScreenState();
}

class _EditPlanScreenState extends State<EditPlanScreen> {
  late List<Dhikr> _editableList;
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

    // Initialize state mapping
    _editableList = List.from(defaultDhikrs);
    _enabledStatus = {
      for (var d in _editableList) d.id: customPlanProvider.isDhikrEnabled(d.id)
    };
  }

  String _getTitle() {
    switch (widget.category) {
      case DhikrCategory.morning:
        return "Edit Regular Morning";
      case DhikrCategory.evening:
        return "Edit Regular Evening";
      case DhikrCategory.protection:
        return "Edit Daily Protection";
      case DhikrCategory.focus:
        return "Edit Focus Selection";
      default:
        return "Edit Plan";
    }
  }

  Widget _buildGlassCard({required Widget child, bool isEnabled = true}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isEnabled
            ? Colors.white.withOpacity(0.03)
            : Colors.white.withOpacity(0.01),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.white.withOpacity(isEnabled ? 0.1 : 0.05)),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryOrange = Color(0xFFF49D25);
    const bgDark = Color(0xFF0A0F12);

    return Scaffold(
      backgroundColor: bgDark,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.5,
            colors: [
              Color(0xFF1A2E35),
              bgDark,
            ],
            stops: [0.0, 1.0],
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
                      color: bgDark.withOpacity(0.8),
                      border: Border(
                          bottom: BorderSide(
                              color: Colors.white.withOpacity(0.05))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.white, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Text(
                          _getTitle(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 48), // Spacer
                      ],
                    ),
                  ),

                  // --- Content ---
                  Expanded(
                    child: ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 160),
                      physics: const BouncingScrollPhysics(),
                      itemCount: _editableList.length,
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
                          // Status Banner
                          Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              color: primaryOrange.withOpacity(0.05),
                              border: Border.all(
                                  color: primaryOrange.withOpacity(0.2)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline,
                                    color: primaryOrange, size: 20),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Modify the standard set of supplications to fit your time.",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          height: 1.4,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            "Learn More",
                                            style: TextStyle(
                                              color: primaryOrange,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(width: 4),
                                          Icon(Icons.arrow_forward,
                                              color: primaryOrange, size: 14),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // List Header
                          const Padding(
                            padding:
                                EdgeInsets.only(bottom: 8.0, left: 4, right: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "SEQUENCE & TOGGLES",
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                Text(
                                  "Hold handle to reorder",
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      itemBuilder: (context, index) {
                        final dhikr = _editableList[index];
                        final isEnabled = _enabledStatus[dhikr.id] ?? false;

                        return Container(
                          key: Key(dhikr.id),
                          child: _buildGlassCard(
                            isEnabled: isEnabled,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  // Drag Handle
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: const Icon(Icons.drag_indicator,
                                        color: Colors.white38),
                                  ),
                                  const SizedBox(width: 16),

                                  // Text Info
                                  Expanded(
                                    child: Opacity(
                                      opacity: isEnabled ? 1.0 : 0.5,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            dhikr.title,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            dhikr.translation,
                                            style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Controls
                                  Opacity(
                                    opacity: isEnabled ? 1.0 : 0.5,
                                    child: Row(
                                      children: [
                                        // Counter Adjuster
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4, vertical: 2),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(0.05),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: Colors.white
                                                    .withOpacity(0.1)),
                                          ),
                                          child: Row(
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.remove,
                                                    size: 14),
                                                color: isEnabled
                                                    ? primaryOrange
                                                        .withOpacity(0.8)
                                                    : Colors.white54,
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(),
                                                onPressed:
                                                    isEnabled ? () {} : null,
                                              ),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8.0),
                                                child: Text(
                                                  "${dhikr.targetCount}x",
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.add,
                                                    size: 14),
                                                color: isEnabled
                                                    ? primaryOrange
                                                        .withOpacity(0.8)
                                                    : Colors.white54,
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(),
                                                onPressed:
                                                    isEnabled ? () {} : null,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),

                                        // Toggle Switch
                                        Switch(
                                          value: isEnabled,
                                          activeColor: Colors.white,
                                          activeTrackColor: primaryOrange,
                                          inactiveThumbColor: Colors.grey,
                                          inactiveTrackColor: Colors.white10,
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
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: bgDark.withOpacity(0.9),
                    border: Border(
                        top: BorderSide(color: Colors.white.withOpacity(0.1))),
                  ),
                  child: Column(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          // Save Logic
                          final planProvider = Provider.of<CustomPlanProvider>(
                              context,
                              listen: false);

                          // Convert states to final map
                          for (var id in _enabledStatus.keys) {
                            planProvider.toggleDhikr(
                                id, _enabledStatus[id] ?? false);
                          }

                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                            content: Text('Plan Saved!'),
                            backgroundColor: primaryOrange,
                            duration: Duration(seconds: 2),
                          ));
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryOrange,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 8,
                          shadowColor: primaryOrange.withOpacity(0.5),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              "Save Morning Plan",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () {
                          // Reset Logic
                          setState(() {
                            for (var key in _enabledStatus.keys) {
                              _enabledStatus[key] = true;
                            }
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          side:
                              BorderSide(color: Colors.white.withOpacity(0.1)),
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.restart_alt,
                                color: Colors.white54, size: 18),
                            SizedBox(width: 8),
                            Text(
                              "Reset to Default",
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 14,
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
