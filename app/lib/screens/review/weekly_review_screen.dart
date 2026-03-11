import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/database/daos/reviews_dao.dart';
import 'package:antra/providers/database_provider.dart';
import 'package:antra/services/task_lifecycle_service.dart';
import 'package:antra/providers/reviews_provider.dart';
import 'package:antra/providers/task_lifecycle_provider.dart';
import 'package:antra/widgets/weekly_review_task_item.dart';

class WeeklyReviewScreen extends ConsumerStatefulWidget {
  const WeeklyReviewScreen({super.key});

  @override
  ConsumerState<WeeklyReviewScreen> createState() => _WeeklyReviewScreenState();
}

class _WeeklyReviewScreenState extends ConsumerState<WeeklyReviewScreen> {
  final _notesCtrl = TextEditingController();
  late final String _from;
  late final String _to;
  bool _completing = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // ISO week: Monday to Sunday
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    final fmt = DateFormat('yyyy-MM-dd');
    _from = fmt.format(monday);
    _to = fmt.format(sunday);
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _migrateTask(Bullet bullet) async {
    final db = await ref.read(appDatabaseProvider.future);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final svc = TaskLifecycleService(db: db, deviceId: 'local');
    await svc.keepForToday(bullet.id, today);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task moved to today\'s log.')),
      );
    }
    // Invalidate the provider so the list refreshes.
    ref.invalidate(openTasksForPeriodProvider(_from, _to));
  }

  Future<void> _completeReview() async {
    setState(() => _completing = true);
    final db = await ref.read(appDatabaseProvider.future);
    final reviewsDao = ReviewsDao(db);
    final review = await reviewsDao.getOrCreateReview('week', _from, _to);
    await reviewsDao.markComplete(review.id, summaryNotes: _notesCtrl.text.trim());
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Weekly review completed!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final openTasksAsync = ref.watch(openTasksForPeriodProvider(_from, _to));
    final eventsAsync = ref.watch(eventsForPeriodProvider(_from, _to));
    final headerFmt = DateFormat('MMM d');
    final rangeLabel =
        '${headerFmt.format(DateTime.parse(_from))} – ${headerFmt.format(DateTime.parse(_to))}';

    return Scaffold(
      appBar: AppBar(title: Text('Weekly Review: $rangeLabel')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Unresolved Tasks Section — primary content, shown first
            _UnresolvedTasksSection(),
            const SizedBox(height: 16),
            Text('Open Tasks', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            openTasksAsync.when(
              data: (tasks) {
                if (tasks.isEmpty) {
                  return const Text(
                    'No open tasks this week.',
                    style: TextStyle(color: Colors.grey),
                  );
                }
                return Column(
                  children: tasks
                      .map(
                        (t) => Card(
                          child: ListTile(
                            leading:
                                const Icon(Icons.check_box_outline_blank),
                            title: Text(t.content),
                            trailing: IconButton(
                              icon: const Icon(Icons.redo),
                              tooltip: 'Migrate to today',
                              onPressed: () => _migrateTask(t),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
            ),
            const SizedBox(height: 16),
            Text('Events', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            eventsAsync.when(
              data: (events) {
                if (events.isEmpty) {
                  return const Text(
                    'No events this week.',
                    style: TextStyle(color: Colors.grey),
                  );
                }
                return Column(
                  children: events
                      .map(
                        (e) => ListTile(
                          leading: const Icon(Icons.radio_button_checked),
                          title: Text(e.content),
                          dense: true,
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
            ),
            const SizedBox(height: 16),
            Text('Summary Notes',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _notesCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Reflect on your week…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _completing ? null : _completeReview,
                child: Text(_completing ? 'Completing…' : 'Complete Review'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Displays active tasks older than 7 days that need attention.
/// Mutually exclusive with the "From Yesterday" carry-over section.
class _UnresolvedTasksSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(weeklyReviewTasksProvider);
    final cs = Theme.of(context).colorScheme;

    return tasksAsync.when(
      data: (tasks) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Needs Attention',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (tasks.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${tasks.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Tasks older than 7 days',
              style: TextStyle(
                  fontSize: 12, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            if (tasks.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 36,
                          color: cs.onSurfaceVariant.withValues(alpha:0.4)),
                      const SizedBox(height: 8),
                      Text(
                        "Nothing to review — you're all caught up.",
                        style: TextStyle(
                            fontSize: 14,
                            color:
                                cs.onSurfaceVariant.withValues(alpha:0.7)),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              for (final task in tasks)
                WeeklyReviewTaskItem(bullet: task),
          ],
        );
      },
      loading: () => const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => Text('Error loading tasks: $e'),
    );
  }
}
