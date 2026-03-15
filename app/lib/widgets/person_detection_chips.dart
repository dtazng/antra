import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:antra/providers/person_detection_providers.dart';

/// Horizontal row of tappable chips suggesting persons to link to a bullet.
///
/// Shown inline below a newly saved log entry.
/// Tapping a chip links that person and removes it from the row.
/// Tapping the × dismisses all chips.
class PersonDetectionChips extends ConsumerWidget {
  const PersonDetectionChips({super.key, required this.bulletId});

  final String bulletId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detectionState =
        ref.watch(personDetectionNotifierProvider(bulletId));
    final suggestions = detectionState.suggestions;

    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Row(
        children: [
          const Text(
            'Link? ',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final s in suggestions) ...[
                    _PersonChip(
                      label: s.personName,
                      onAccept: () => ref
                          .read(personDetectionNotifierProvider(bulletId)
                              .notifier)
                          .acceptSuggestion(s.personId),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ),
          // Dismiss all
          GestureDetector(
            onTap: () => ref
                .read(personDetectionNotifierProvider(bulletId).notifier)
                .dismissAll(),
            child: const Icon(Icons.close_rounded,
                size: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _PersonChip extends StatelessWidget {
  const _PersonChip({required this.label, required this.onAccept});

  final String label;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAccept,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .primaryContainer
              .withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
