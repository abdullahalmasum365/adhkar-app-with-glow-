import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dhikr_provider.dart';
import '../providers/custom_plan_provider.dart';
import '../providers/language_provider.dart';
import '../models/dhikr.dart';
import '../constants/app_theme.dart';

class CustomizePlanScreen extends StatelessWidget {
  const CustomizePlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dp = Provider.of<DhikrProvider>(context);
    final cp = Provider.of<CustomPlanProvider>(context);
    final lp = Provider.of<LanguageProvider>(context);

    final morning    = dp.getMorningDhikrs();
    final evening    = dp.getEveningDhikrs();
    final protection = dp.getProtectionDhikrs();
    final focus      = dp.getFocusDhikrs();
    final parents    = dp.getParentsDhikrs();
    final graveyard  = dp.getGraveyardDhikrs();
    final food       = dp.getFoodDhikrs();

    final allIds = [
      ...morning, ...evening, ...protection,
      ...focus, ...parents, ...graveyard, ...food,
    ].map((d) => d.id).toList();
    final allOn = allIds.every((id) => cp.enabledDhikrIds.contains(id));

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        title: Text(lp.getText('customize'), style: AppText.heading(18)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () {
              for (final id in allIds) {
                cp.toggleDhikr(id, !allOn);
              }
            },
            child: Text(
                allOn ? lp.getText('disable_all') : lp.getText('enable_all'),
                style: AppText.body(color: AppColors.primary)),
          ),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          _Header(lp.getText('morning_adhkar')),
          ...morning.map((d) => _Tile(d, cp)),
          _Header(lp.getText('evening_adhkar')),
          ...evening.map((d) => _Tile(d, cp)),
          _Header(lp.getText('protection')),
          ...protection.map((d) => _Tile(d, cp)),
          _Header(lp.getText('focus')),
          ...focus.map((d) => _Tile(d, cp)),
          _Header(lp.getText('parents')),
          ...parents.map((d) => _Tile(d, cp)),
          _Header(lp.getText('graveyard')),
          ...graveyard.map((d) => _Tile(d, cp)),
          _Header(lp.getText('food_eating')),
          ...food.map((d) => _Tile(d, cp)),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  const _Header(this.title);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(title,
            style: AppText.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.primary)),
      );
}

class _Tile extends StatelessWidget {
  final Dhikr dhikr;
  final CustomPlanProvider cp;
  const _Tile(this.dhikr, this.cp);

  @override
  Widget build(BuildContext context) {
    // FIX: single consistent source — removed the redundant dead `isEnabled` variable
    final checked = cp.enabledDhikrIds.contains(dhikr.id);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: AppDeco.glassCard(borderRadius: BorderRadius.circular(12)),
      child: CheckboxListTile(
        value: checked,
        onChanged: (_) => cp.toggleDhikr(dhikr.id, !checked),
        activeColor: AppColors.primary,
        checkColor: AppColors.textPrimary,
        title: Text(dhikr.title,
            style: AppText.manrope(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(dhikr.translation,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.body(color: AppColors.textSlate400)),
        secondary: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              shape: BoxShape.circle),
          child: Center(
              child: Text('${dhikr.targetCount}',
                  style: AppText.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary))),
        ),
      ),
    );
  }
}
