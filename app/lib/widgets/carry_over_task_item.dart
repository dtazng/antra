import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/providers/task_lifecycle_provider.dart';

/// A task row shown in the "Carried Over" section of the Today screen.
///
/// Displays the task title, an age badge ("Nd"), and an inline horizontal
/// chip row with quick actions. Tapping the non-button area opens TaskDetailScreen.
class CarryOverTaskItem extends ConsumerWidget {
  final Bullet bullet;
  final VoidCallback onTap;

  const CarryOverTaskItem({
    super.key,
    required this.bullet,
    required this.onTap,
  });

  String get _today => DateFormat('yyyy-MM-dd').format(DateTime.now().toLocal());

  /// Returns a compact age badge string like "3d" from an ISO 8601 [createdAt].
  String _ageBadge(String createdAt) {
    try {
      final created = DateTime.parse(createdAt).toLocal();
      final now = DateTime.now().toLocal();
      final days = now.difference(created).inDays;
      return '${days}d';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final count = bullet.carryOverCount;
    final countIsWarning = count >= 3;
    final ageBadge = _ageBadge(bullet.createdAt);

    return InkWell(
      onTap: onTap,
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: icon + content + age badge
            Row(
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
                // Age badge
                if (ageBadge.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        ageBadge,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Action chip row
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ActionChip(
                    label: 'Complete',
                    onTap: () async {
                      final svc =
                          await ref.read(taskLifecycleServiceProvider.future);
                      await svc.completeTask(bullet.id);
                    },
                  ),
                  _ActionChip(
                    label: 'Keep for Today',
                    onTap: () async {
                      final svc =
                          await ref.read(taskLifecycleServiceProvider.future);
                      await svc.keepForToday(bullet.id, _today);
                    },
                  ),
                  _ActionChip(
                    label: 'Schedule',
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate:
                            DateTime.now().add(const Duration(days: 1)),
                        firstDate:
                            DateTime.now().add(const Duration(days: 1)),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked == null || !context.mounted) return;
                      final dateStr = DateFormat('yyyy-MM-dd').format(picked);
                      final svc =
                          await ref.read(taskLifecycleServiceProvider.future);
                      await svc.scheduleTask(bullet.id, dateStr);
                    },
                  ),
                  _ActionChip(
                    label: 'Backlog',
                    onTap: () async {
                      final svc =
                          await ref.read(taskLifecycleServiceProvider.future);
                      await svc.moveToBacklog(bullet.id);
                    },
                  ),
                  _ActionChip(
                    label: '→ Note',
                    onTap: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Convert to Note?'),
                          content: const Text(
                            'This will change the task into a note. The action cannot be undone.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('Convert'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true || !context.mounted) return;
                      final svc =
                          await ref.read(taskLifecycleServiceProvider.future);
                      await svc.convertToNote(bullet.id);
                    },
                  ),
                  _ActionChip(
                    label: 'Cancel',
                    isDestructive: true,
                    onTap: () async {
                      final svc =
                          await ref.read(taskLifecycleServiceProvider.future);
                      await svc.cancelTask(bullet.id);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Task canceled.'),
                          duration: const Duration(seconds: 3),
                          action: SnackBarAction(
                            label: 'Undo',
                            onPressed: () async {
                              await svc.reactivateTask(bullet.id, _today);
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ],
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

class _ActionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ActionChip({
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = isDestructive ? cs.error : cs.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        child: Text(label),
      ),
    );
  }
}
