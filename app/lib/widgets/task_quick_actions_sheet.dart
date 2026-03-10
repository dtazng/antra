import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/providers/task_lifecycle_provider.dart';

/// Bottom sheet with 6 quick actions for a task in the "From Yesterday" section.
///
/// Show via:
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   builder: (_) => TaskQuickActionsSheet(bullet: task),
/// );
/// ```
class TaskQuickActionsSheet extends ConsumerWidget {
  final Bullet bullet;

  const TaskQuickActionsSheet({super.key, required this.bullet});

  String get _today {
    final now = DateTime.now().toLocal();
    return DateFormat('yyyy-MM-dd').format(now);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Action rows
          _ActionTile(
            icon: Icons.check_circle_outline,
            label: 'Mark Complete',
            onTap: () async {
              Navigator.pop(context);
              final svc =
                  await ref.read(taskLifecycleServiceProvider.future);
              await svc.completeTask(bullet.id);
            },
          ),
          _ActionTile(
            icon: Icons.arrow_forward,
            label: 'Keep for Today',
            onTap: () async {
              Navigator.pop(context);
              final svc =
                  await ref.read(taskLifecycleServiceProvider.future);
              await svc.keepForToday(bullet.id, _today);
            },
          ),
          _ActionTile(
            icon: Icons.calendar_today_outlined,
            label: 'Schedule',
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 1)),
                firstDate: DateTime.now().add(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked == null || !context.mounted) return;
              final dateStr = DateFormat('yyyy-MM-dd').format(picked);
              Navigator.pop(context);
              final svc =
                  await ref.read(taskLifecycleServiceProvider.future);
              await svc.scheduleTask(bullet.id, dateStr);
            },
          ),
          _ActionTile(
            icon: Icons.inbox_outlined,
            label: 'Move to Backlog',
            onTap: () async {
              Navigator.pop(context);
              final svc =
                  await ref.read(taskLifecycleServiceProvider.future);
              await svc.moveToBacklog(bullet.id);
            },
          ),
          _ActionTile(
            icon: Icons.note_outlined,
            label: 'Convert to Note',
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Convert to Note?'),
                  content: const Text(
                    'This task will become a note and leave all review queues.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Convert'),
                    ),
                  ],
                ),
              );
              if (confirmed != true || !context.mounted) return;
              Navigator.pop(context);
              final svc =
                  await ref.read(taskLifecycleServiceProvider.future);
              await svc.convertToNote(bullet.id);
            },
          ),
          _ActionTile(
            icon: Icons.cancel_outlined,
            label: 'Cancel Task',
            isDestructive: true,
            onTap: () async {
              Navigator.pop(context);
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
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Theme.of(context).colorScheme.error : null;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      onTap: onTap,
    );
  }
}
