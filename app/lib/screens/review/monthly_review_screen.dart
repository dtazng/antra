import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/database/daos/reviews_dao.dart';
import 'package:antra/providers/database_provider.dart';
import 'package:antra/providers/people_provider.dart';
import 'package:antra/providers/reviews_provider.dart';

class MonthlyReflectionScreen extends ConsumerStatefulWidget {
  const MonthlyReflectionScreen({super.key});

  @override
  ConsumerState<MonthlyReflectionScreen> createState() =>
      _MonthlyReflectionScreenState();
}

class _MonthlyReflectionScreenState
    extends ConsumerState<MonthlyReflectionScreen> {
  final _notesCtrl = TextEditingController();
  late final String _from;
  late final String _to;
  bool _completing = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);
    final fmt = DateFormat('yyyy-MM-dd');
    _from = fmt.format(firstDay);
    _to = fmt.format(lastDay);
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _completeReview() async {
    setState(() => _completing = true);
    final db = await ref.read(appDatabaseProvider.future);
    final reviewsDao = ReviewsDao(db);
    final review = await reviewsDao.getOrCreateReview('month', _from, _to);
    await reviewsDao.markComplete(review.id,
        summaryNotes: _notesCtrl.text.trim());
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Monthly reflection completed!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final openTasksAsync = ref.watch(openTasksForPeriodProvider(_from, _to));
    final eventsAsync = ref.watch(eventsForPeriodProvider(_from, _to));
    final peopleAsync = ref.watch(allPeopleProvider);
    final monthLabel = DateFormat('MMMM yyyy').format(DateTime.parse(_from));

    return Scaffold(
      appBar: AppBar(title: Text('Monthly Reflection: $monthLabel')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top interactions
            Text('Top Interactions',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            peopleAsync.when(
              data: (people) {
                final withInteraction = people
                    .where((p) => p.lastInteractionAt != null)
                    .toList()
                  ..sort(
                    (a, b) => b.lastInteractionAt!
                        .compareTo(a.lastInteractionAt!),
                  );
                final top = withInteraction.take(5).toList();
                if (top.isEmpty) {
                  return const Text(
                    'No interactions recorded yet.',
                    style: TextStyle(color: Colors.grey),
                  );
                }
                return Column(
                  children: top
                      .map(
                        (p) => ListTile(
                          leading: CircleAvatar(
                            child: Text(p.name[0].toUpperCase()),
                          ),
                          title: Text(p.name),
                          subtitle: p.lastInteractionAt != null
                              ? Text(
                                  'Last: ${DateFormat('MMM d').format(DateTime.parse(p.lastInteractionAt!))}',
                                )
                              : null,
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
            // Unresolved tasks
            Text('Unresolved Tasks',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            openTasksAsync.when(
              data: (tasks) {
                if (tasks.isEmpty) {
                  return const Text(
                    'All tasks resolved.',
                    style: TextStyle(color: Colors.grey),
                  );
                }
                return Column(
                  children: tasks
                      .map(
                        (t) => ListTile(
                          leading:
                              const Icon(Icons.check_box_outline_blank),
                          title: Text(t.content),
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
            // Events for the month
            Text('Events This Month',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            eventsAsync.when(
              data: (events) {
                if (events.isEmpty) {
                  return const Text(
                    'No events recorded.',
                    style: TextStyle(color: Colors.grey),
                  );
                }
                return Column(
                  children: events
                      .map(
                        (e) => ListTile(
                          leading:
                              const Icon(Icons.radio_button_checked),
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
            Text('Reflection Notes',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _notesCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Reflect on your month…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _completing ? null : _completeReview,
                child: Text(
                    _completing ? 'Completing…' : 'Complete Reflection'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
