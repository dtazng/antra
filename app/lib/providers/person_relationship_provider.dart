import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:antra/database/daos/bullets_dao.dart';
import 'package:antra/models/timeline_entry.dart';
import 'package:antra/providers/database_provider.dart';

part 'person_relationship_provider.g.dart';

String _dateLabel(DateTime date) {
  final today = DateTime.now();
  final todayMidnight = DateTime(today.year, today.month, today.day);
  final dateMidnight = DateTime(date.year, date.month, date.day);
  final diff = todayMidnight.difference(dateMidnight).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return DateFormat('MMM d').format(date);
}

/// Streams the relationship timeline for [personId] as day-grouped [TimelineDay] objects.
///
/// Combines:
///   - all bullets linked to the person
///   - all completion_event bullets sourced from bullets linked to the person
@riverpod
Stream<List<TimelineDay>> personRelationshipTimeline(
  PersonRelationshipTimelineRef ref,
  String personId,
) async* {
  final db = await ref.watch(appDatabaseProvider.future);
  final bulletsDao = BulletsDao(db);

  await for (final rawBullets
      in bulletsDao.watchPersonRelationshipTimeline(personId)) {
    final days = <DateTime, List<TimelineEntry>>{};

    for (final bullet in rawBullets) {
      final createdAt =
          DateTime.tryParse(bullet.createdAt)?.toLocal() ?? DateTime.now();
      final midnight = DateTime(createdAt.year, createdAt.month, createdAt.day);

      final TimelineEntry entry;
      if (bullet.type == 'completion_event' && bullet.sourceId != null) {
        entry = CompletionEventItem(
          bulletId: bullet.id,
          content: bullet.content,
          createdAt: createdAt,
          sourceId: bullet.sourceId!,
        );
      } else {
        entry = LogEntryItem(
          bulletId: bullet.id,
          content: bullet.content,
          createdAt: createdAt,
          followUpDate: bullet.followUpDate,
          followUpStatus: bullet.followUpStatus,
        );
      }

      days.putIfAbsent(midnight, () => []).add(entry);
    }

    final sorted = days.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    yield sorted
        .map((e) => TimelineDay(
              label: _dateLabel(e.key),
              date: e.key,
              entries: e.value,
            ))
        .toList();
  }
}
