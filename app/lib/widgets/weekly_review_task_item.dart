import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/providers/task_lifecycle_provider.dart';

/// A task row shown in the Weekly Review "Needs Attention" section.
///
/// Shows task content, age, carry-over count, and 5 action buttons.
class WeeklyReviewTaskItem extends ConsumerWidget {
  final Bullet bullet;

  const WeeklyReviewTaskItem({super.key, required this.bullet});

  String get _today {
    return DateFormat('yyyy-MM-dd').format(DateTime.now().toLocal());
  }

  String _ageLabel() {
    try {
      final created = DateTime.parse(bullet.createdAt).toLocal();
      final now = DateTime.now().toLocal();
      final days = now.difference(created).inDays;
      return '$days day${days == 1 ? '' : 's'} old';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final count = bullet.carryOverCount;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Content + age
            Text(
              bullet.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  _ageLabel(),
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 10),
                  Text(
                    '×$count carries',
                    style: TextStyle(
                      fontSize: 12,
                      color: count >= 3 ? Colors.amber[700] : cs.onSurfaceVariant,
                      fontWeight:
                          count >= 3 ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            // Action buttons
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ActionChip(
                    label: 'This Week',
                    onTap: () async {
                      final svc = await ref
                          .read(taskLifecycleServiceProvider.future);
                      await svc.moveToThisWeek(bullet.id, _today);
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
                      final dateStr =
                          DateFormat('yyyy-MM-dd').format(picked);
                      final svc = await ref
                          .read(taskLifecycleServiceProvider.future);
                      await svc.scheduleTask(bullet.id, dateStr);
                    },
                  ),
                  _ActionChip(
                    label: 'Backlog',
                    onTap: () async {
                      final svc = await ref
                          .read(taskLifecycleServiceProvider.future);
                      await svc.moveToBacklog(bullet.id);
                    },
                  ),
                  _ActionChip(
                    label: '→ Note',
                    onTap: () async {
                      final svc = await ref
                          .read(taskLifecycleServiceProvider.future);
                      await svc.convertToNote(bullet.id);
                    },
                  ),
                  _ActionChip(
                    label: 'Cancel',
                    isDestructive: true,
                    onTap: () async {
                      final svc = await ref
                          .read(taskLifecycleServiceProvider.future);
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
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        child: Text(label),
      ),
    );
  }
}
