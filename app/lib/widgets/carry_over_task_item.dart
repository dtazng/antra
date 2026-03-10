import 'package:flutter/material.dart';

import 'package:antra/database/app_database.dart';

/// A task row shown in the "From Yesterday" section of the Today screen.
///
/// Tapping opens the TaskDetailScreen.
/// Long press opens the TaskQuickActionsSheet.
class CarryOverTaskItem extends StatelessWidget {
  final Bullet bullet;
  final VoidCallback onTap;
  final VoidCallback onQuickAction;

  const CarryOverTaskItem({
    super.key,
    required this.bullet,
    required this.onTap,
    required this.onQuickAction,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final count = bullet.carryOverCount;
    final countIsWarning = count >= 3;

    return InkWell(
      onTap: onTap,
      onLongPress: onQuickAction,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: countIsWarning
              ? Colors.amber.withValues(alpha: 0.07)
              : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: countIsWarning
                ? Colors.amber.withValues(alpha: 0.25)
                : cs.outlineVariant.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Carry-over icon
            Padding(
              padding: const EdgeInsets.only(top: 1, right: 12),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.redo_rounded,
                  size: 15,
                  color: cs.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
            // Task content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bullet.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      letterSpacing: -0.1,
                      color: cs.onSurface,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(height: 4),
                    _CountBadge(count: count, isWarning: countIsWarning),
                  ],
                ],
              ),
            ),
            // Trailing chevron
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: cs.onSurface.withValues(alpha: 0.25),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final bool isWarning;

  const _CountBadge({required this.count, required this.isWarning});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isWarning)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Icon(
              Icons.warning_amber_rounded,
              size: 11,
              color: Colors.amber[700],
            ),
          ),
        Text(
          isWarning
              ? 'Carried over $count times — consider resolving'
              : 'Carried over $count×',
          style: TextStyle(
            fontSize: 11,
            fontWeight: isWarning ? FontWeight.w600 : FontWeight.w400,
            color: isWarning ? Colors.amber[700] : cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
