import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/providers/database_provider.dart';
import 'package:antra/providers/task_lifecycle_provider.dart';
import 'package:antra/widgets/lifecycle_event_tile.dart';

/// Full task detail view with content, state, scheduled date, lifecycle
/// history, and contextual action buttons.
///
/// Usage:
/// ```dart
/// Navigator.of(context).push(
///   MaterialPageRoute(builder: (_) => TaskDetailScreen(bulletId: id)),
/// );
/// ```
class TaskDetailScreen extends ConsumerStatefulWidget {
  final String bulletId;

  const TaskDetailScreen({super.key, required this.bulletId});

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  bool _editingContent = false;
  late TextEditingController _contentController;

  String get _today {
    return DateFormat('yyyy-MM-dd').format(DateTime.now().toLocal());
  }

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveContent(Bullet bullet) async {
    final newContent = _contentController.text.trim();
    if (newContent.isEmpty || newContent == bullet.content) {
      setState(() => _editingContent = false);
      return;
    }
    final db = await ref.read(appDatabaseProvider.future);
    await (db.update(db.bullets)..where((t) => t.id.equals(bullet.id))).write(
      BulletsCompanion(
        content: Value(newContent),
        updatedAt: Value(DateTime.now().toUtc().toIso8601String()),
      ),
    );
    if (mounted) setState(() => _editingContent = false);
  }

  @override
  Widget build(BuildContext context) {
    final bulletAsync = ref.watch(singleBulletProvider(widget.bulletId));
    final eventsAsync =
        ref.watch(taskLifecycleEventsProvider(widget.bulletId));

    return Scaffold(
      appBar: AppBar(
        leading: const CloseButton(),
        title: const Text('Task'),
      ),
      body: bulletAsync.when(
        data: (bullet) {
          if (bullet == null) {
            return const Center(child: Text('Task not found.'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ContentSection(
                  bullet: bullet,
                  editing: _editingContent,
                  controller: _contentController,
                  onTap: () {
                    _contentController.text = bullet.content;
                    setState(() => _editingContent = true);
                  },
                  onSave: () => _saveContent(bullet),
                  onCancel: () => setState(() => _editingContent = false),
                ),
                const SizedBox(height: 16),
                _StatusRow(bullet: bullet),
                if (bullet.scheduledDate != null) ...[
                  const SizedBox(height: 12),
                  _ScheduledDateRow(bullet: bullet),
                ],
                const SizedBox(height: 24),
                _HistorySection(eventsAsync: eventsAsync),
                const SizedBox(height: 24),
                _ActionsSection(bullet: bullet, today: _today),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ContentSection extends StatelessWidget {
  final Bullet bullet;
  final bool editing;
  final TextEditingController controller;
  final VoidCallback onTap;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const _ContentSection({
    required this.bullet,
    required this.editing,
    required this.controller,
    required this.onTap,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (editing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            maxLines: null,
            style: const TextStyle(fontSize: 16, height: 1.5),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              hintText: 'Task content',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton(onPressed: onSave, child: const Text('Save')),
              const SizedBox(width: 8),
              TextButton(onPressed: onCancel, child: const Text('Cancel')),
            ],
          ),
        ],
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha:0.4),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          bullet.content,
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final Bullet bullet;
  const _StatusRow({required this.bullet});

  String _statusLabel(String status) {
    switch (status) {
      case 'open':
        return 'Active';
      case 'backlog':
        return 'Backlog';
      case 'complete':
        return 'Completed';
      case 'cancelled':
        return 'Canceled';
      default:
        return status;
    }
  }

  Color _statusColor(ColorScheme cs, String status) {
    switch (status) {
      case 'complete':
        return cs.primary;
      case 'cancelled':
        return cs.error;
      case 'backlog':
        return cs.tertiary;
      default:
        return cs.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final count = bullet.carryOverCount;
    final countIsWarning = count >= 3;

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        Chip(
          label: Text(_statusLabel(bullet.status)),
          backgroundColor:
              _statusColor(cs, bullet.status).withValues(alpha:0.12),
          labelStyle: TextStyle(
            color: _statusColor(cs, bullet.status),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        if (count > 0)
          Chip(
            avatar: countIsWarning
                ? Icon(Icons.warning_amber_rounded,
                    size: 14, color: Colors.amber[700])
                : null,
            label: Text(
              'Carried over ${count}×${countIsWarning ? ' — consider resolving' : ''}',
            ),
            backgroundColor: countIsWarning
                ? Colors.amber.withValues(alpha:0.12)
                : cs.surfaceContainerHighest,
            labelStyle: TextStyle(
              color: countIsWarning ? Colors.amber[800] : cs.onSurfaceVariant,
              fontSize: 12,
            ),
            padding: EdgeInsets.zero,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
      ],
    );
  }
}

class _ScheduledDateRow extends ConsumerWidget {
  final Bullet bullet;
  const _ScheduledDateRow({required this.bullet});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final formatted = _formatDate(bullet.scheduledDate!);

    return Row(
      children: [
        Icon(Icons.calendar_today_outlined,
            size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          formatted,
          style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () async {
            final svc =
                await ref.read(taskLifecycleServiceProvider.future);
            await svc.scheduleTask(bullet.id, null);
          },
          child:
              Icon(Icons.close_rounded, size: 18, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  String _formatDate(String date) {
    try {
      final dt = DateTime.parse(date);
      return DateFormat('MMM d, y').format(dt);
    } catch (_) {
      return date;
    }
  }
}

class _HistorySection extends StatelessWidget {
  final AsyncValue<List<TaskLifecycleEvent>> eventsAsync;
  const _HistorySection({required this.eventsAsync});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'History',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        eventsAsync.when(
          data: (events) {
            if (events.isEmpty) {
              return Text(
                'No history yet.',
                style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurfaceVariant.withValues(alpha:0.6)),
              );
            }
            return Column(
              children: [
                for (int i = 0; i < events.length; i++)
                  LifecycleEventTile(
                    event: events[i],
                    isLast: i == events.length - 1,
                  ),
              ],
            );
          },
          loading: () => const SizedBox(
            height: 40,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (e, _) => Text('Error: $e'),
        ),
      ],
    );
  }
}

class _ActionsSection extends ConsumerWidget {
  final Bullet bullet;
  final String today;

  const _ActionsSection({required this.bullet, required this.today});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = bullet.status;

    if (status == 'complete' || status == 'cancelled') {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (status == 'open') ...[
          _ActionButton(
            label: 'Complete',
            icon: Icons.check_circle_outline,
            onTap: () async {
              final svc =
                  await ref.read(taskLifecycleServiceProvider.future);
              await svc.completeTask(bullet.id);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          _ActionButton(
            label: 'Schedule',
            icon: Icons.calendar_today_outlined,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate:
                    DateTime.now().add(const Duration(days: 1)),
                firstDate:
                    DateTime.now().add(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked == null || !context.mounted) return;
              final dateStr =
                  DateFormat('yyyy-MM-dd').format(picked);
              final svc =
                  await ref.read(taskLifecycleServiceProvider.future);
              await svc.scheduleTask(bullet.id, dateStr);
            },
          ),
          _ActionButton(
            label: 'Move to Backlog',
            icon: Icons.inbox_outlined,
            onTap: () async {
              final svc =
                  await ref.read(taskLifecycleServiceProvider.future);
              await svc.moveToBacklog(bullet.id);
            },
          ),
          _ActionButton(
            label: 'Convert to Note',
            icon: Icons.note_outlined,
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Convert to Note?'),
                  content: const Text(
                      'This task will become a note and leave all review queues.'),
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
              final svc =
                  await ref.read(taskLifecycleServiceProvider.future);
              await svc.convertToNote(bullet.id);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          _ActionButton(
            label: 'Cancel Task',
            icon: Icons.cancel_outlined,
            isDestructive: true,
            onTap: () async {
              final svc =
                  await ref.read(taskLifecycleServiceProvider.future);
              await svc.cancelTask(bullet.id);
              if (!context.mounted) return;
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Task canceled.'),
                  duration: const Duration(seconds: 3),
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () async {
                      await svc.reactivateTask(bullet.id, today);
                    },
                  ),
                ),
              );
            },
          ),
        ],
        if (status == 'backlog') ...[
          _ActionButton(
            label: 'Reactivate',
            icon: Icons.refresh_rounded,
            onTap: () async {
              final svc =
                  await ref.read(taskLifecycleServiceProvider.future);
              await svc.reactivateTask(bullet.id, today);
            },
          ),
          _ActionButton(
            label: 'Cancel Task',
            icon: Icons.cancel_outlined,
            isDestructive: true,
            onTap: () async {
              final svc =
                  await ref.read(taskLifecycleServiceProvider.future);
              await svc.cancelTask(bullet.id);
              if (!context.mounted) return;
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Task canceled.'),
                  duration: const Duration(seconds: 3),
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () async {
                      await svc.reactivateTask(bullet.id, today);
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = isDestructive ? cs.error : cs.primary;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(color: color, fontSize: 13)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withValues(alpha:0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
