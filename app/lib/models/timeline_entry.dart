/// Discriminated union of items that appear in the infinite timeline.
///
/// [LogEntryItem] — a user-created log entry (note, event, legacy task).
/// [CompletionEventItem] — a "Followed up with X" event created when a
/// follow-up suggestion is marked Done.
sealed class TimelineEntry {
  const TimelineEntry();
}

/// A standard log entry created by the user.
class LogEntryItem extends TimelineEntry {
  const LogEntryItem({
    required this.bulletId,
    required this.content,
    required this.createdAt,
    this.personId,
    this.personName,
    this.followUpDate,
    this.followUpStatus,
  });

  final String bulletId;
  final String content;
  final DateTime createdAt;

  /// Linked person, if any.
  final String? personId;
  final String? personName;

  /// ISO date string (YYYY-MM-DD). Null = no follow-up attached.
  final String? followUpDate;

  /// 'pending' | 'done' | 'snoozed' | 'dismissed'. Null = no follow-up.
  final String? followUpStatus;
}

/// A completion event inserted into the timeline when a follow-up is marked Done.
/// Content is typically "Followed up with [personName]".
class CompletionEventItem extends TimelineEntry {
  const CompletionEventItem({
    required this.bulletId,
    required this.content,
    required this.createdAt,
    required this.sourceId,
    this.personId,
    this.personName,
  });

  final String bulletId;

  /// Human-readable completion label, e.g. "Followed up with Anna".
  final String content;
  final DateTime createdAt;

  /// FK → the originating [LogEntryItem]'s bulletId.
  final String sourceId;

  final String? personId;
  final String? personName;
}

/// A group of [TimelineEntry] items that share the same calendar day.
class TimelineDay {
  const TimelineDay({
    required this.label,
    required this.date,
    required this.entries,
  });

  /// Human-readable date label: "Today", "Yesterday", or "Mar 12".
  final String label;

  /// The calendar day, normalised to midnight local time.
  final DateTime date;

  /// Entries for this day, sorted newest-first within the day.
  final List<TimelineEntry> entries;
}
