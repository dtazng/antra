import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:antra/database/daos/bullets_dao.dart';
import 'package:antra/database/daos/people_dao.dart';
import 'package:antra/models/timeline_entry.dart';
import 'package:antra/providers/database_provider.dart';

part 'timeline_provider.g.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _todayStr() => DateFormat('yyyy-MM-dd').format(DateTime.now());

/// Human-readable label for a date: "Today", "Yesterday", or "Mar 12".
String _dateLabel(DateTime date) {
  final today = DateTime.now();
  final todayMidnight = DateTime(today.year, today.month, today.day);
  final dateMidnight = DateTime(date.year, date.month, date.day);
  final diff = todayMidnight.difference(dateMidnight).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return DateFormat('MMM d').format(date);
}

// ---------------------------------------------------------------------------
// timelineEntriesProvider
// ---------------------------------------------------------------------------

/// Emits the infinite timeline as a list of [TimelineDay] groups.
/// Each group contains [TimelineEntry] items (log entries + completion events)
/// sorted newest-first within the day.
///
/// Updates reactively whenever the bullets table changes.
@riverpod
Stream<List<TimelineDay>> timelineEntries(TimelineEntriesRef ref) async* {
  final db = await ref.watch(appDatabaseProvider.future);
  final bulletsDao = BulletsDao(db);
  final peopleDao = PeopleDao(db);

  await for (final rawBullets in bulletsDao.watchTimelineEntries()) {
    final days = <DateTime, List<TimelineEntry>>{};

    for (final bullet in rawBullets) {
      final createdAt =
          DateTime.tryParse(bullet.createdAt)?.toLocal() ?? DateTime.now();
      final midnight = DateTime(createdAt.year, createdAt.month, createdAt.day);

      // Resolve optional person link (one query per bullet; acceptable at timeline scale).
      final person = await peopleDao.getLinkedPersonForBullet(bullet.id);

      final TimelineEntry entry;
      if (bullet.type == 'completion_event' && bullet.sourceId != null) {
        entry = CompletionEventItem(
          bulletId: bullet.id,
          content: bullet.content,
          createdAt: createdAt,
          sourceId: bullet.sourceId!,
          personId: person?.id,
          personName: person?.name,
        );
      } else {
        entry = LogEntryItem(
          bulletId: bullet.id,
          content: bullet.content,
          createdAt: createdAt,
          personId: person?.id,
          personName: person?.name,
          followUpDate: bullet.followUpDate,
          followUpStatus: bullet.followUpStatus,
        );
      }

      days.putIfAbsent(midnight, () => []).add(entry);
    }

    // Emit as sorted TimelineDay list (newest day first; entries already DESC from DAO).
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

// ---------------------------------------------------------------------------
// needsAttentionItemsProvider — see needs_attention_provider.dart
// ---------------------------------------------------------------------------

/// Exposed here as a convenience re-export reference.
/// The actual provider is in needs_attention_provider.dart.
String get todayDateString => _todayStr();
