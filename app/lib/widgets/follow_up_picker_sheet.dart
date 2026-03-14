import 'package:flutter/material.dart';

import 'package:antra/theme/app_theme.dart';
import 'package:antra/widgets/glass_surface.dart';

/// Opens a bottom sheet presenting follow-up time presets.
/// Returns the chosen [DateTime] or null if dismissed without selection.
Future<DateTime?> showFollowUpPicker(BuildContext context) {
  return showModalBottomSheet<DateTime?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _FollowUpPickerSheet(),
  );
}

class _FollowUpPickerSheet extends StatelessWidget {
  const _FollowUpPickerSheet();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final presets = [
      _Preset(
        label: 'Later today',
        date: DateTime(now.year, now.month, now.day, 23, 59),
      ),
      _Preset(label: 'Tomorrow', date: tomorrow),
      _Preset(
        label: 'In 3 days',
        date: today.add(const Duration(days: 3)),
      ),
      _Preset(
        label: 'Next week',
        date: today.add(const Duration(days: 7)),
      ),
    ];

    return GlassSurface(
      style: GlassStyle.modal,
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(AntraRadius.card),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Follow up',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white38,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),

            // Preset rows
            for (final preset in presets)
              ListTile(
                dense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20),
                title: Text(
                  preset.label,
                  style: const TextStyle(
                      fontSize: 15, color: Colors.white),
                ),
                onTap: () => Navigator.pop(context, preset.date),
              ),

            // Custom date row
            ListTile(
              dense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20),
              title: const Text(
                'Custom date\u2026',
                style: TextStyle(fontSize: 15, color: Colors.white70),
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: tomorrow,
                  firstDate: tomorrow,
                  lastDate: DateTime(now.year + 2),
                );
                if (picked != null && context.mounted) {
                  Navigator.pop(context, picked);
                }
                // If cancelled, sheet stays open (no pop).
              },
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _Preset {
  final String label;
  final DateTime date;
  const _Preset({required this.label, required this.date});
}
