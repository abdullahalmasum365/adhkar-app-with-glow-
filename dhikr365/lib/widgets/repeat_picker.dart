// ============================================================================
// lib/widgets/repeat_picker.dart
//
// Dialog for choosing how many times the audio repeats.
// The user can TYPE an exact number (1–999) or tap a quick count —
// including the real dhikr counts 33× and 100× — or ∞ for endless.
// Returns the chosen count (0 = infinite) or null when cancelled.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_theme.dart';

Future<int?> showRepeatPicker(BuildContext context, int current) {
  final controller = TextEditingController(
    text: current == 0 ? '' : current.toString(),
  );

  return showDialog<int>(
    context: context,
    builder: (ctx) {
      int? parse() {
        final v = int.tryParse(controller.text.trim());
        if (v == null || v < 1) return null;
        return v.clamp(1, 999);
      }

      Widget chip(String label, int value) {
        final selected = value == current;
        return GestureDetector(
          onTap: () => Navigator.pop(ctx, value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withOpacity(0.18)
                  : AppColors.ink(0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.ink(0.12),
              ),
            ),
            child: Text(
              label,
              style: AppText.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ),
        );
      }

      return AlertDialog(
        backgroundColor: AppColors.bgTeal,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.repeat_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Text('Repeat Count', style: AppText.heading(16)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              style: AppText.manrope(
                  fontSize: 20, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
              cursorColor: AppColors.primary,
              decoration: InputDecoration(
                hintText: 'Type a number…',
                hintStyle: AppText.body(color: AppColors.textSlate500),
                filled: true,
                fillColor: AppColors.ink(0.06),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.ink(0.12)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
              onSubmitted: (_) {
                final v = parse();
                if (v != null) Navigator.pop(ctx, v);
              },
            ),
            const SizedBox(height: 14),
            Text('QUICK COUNTS', style: AppText.label()),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                chip('1×', 1),
                chip('3×', 3),
                chip('7×', 7),
                chip('10×', 10),
                chip('33×', 33),
                chip('100×', 100),
                chip('∞', 0),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: AppText.body(color: AppColors.textSlate400)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final v = parse();
              if (v != null) Navigator.pop(ctx, v);
            },
            child: Text('Set',
                style: AppText.manrope(
                    fontWeight: FontWeight.w700,
                    color: AppColors.onPrimary)),
          ),
        ],
      );
    },
  );
}
