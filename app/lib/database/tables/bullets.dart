import 'package:drift/drift.dart';

/// Table: bullets
/// Atomic unit of the journal. One bullet per user action.
class Bullets extends Table {
  /// Client-generated UUID primary key.
  TextColumn get id => text()();

  /// Foreign key → day_logs.id. The day this bullet belongs to.
  TextColumn get dayId => text()();

  /// Bullet type: 'task' | 'note' | 'event'. Default: 'note'.
  TextColumn get type => text().withDefault(const Constant('note'))();

  /// Plain-text content. Never empty.
  TextColumn get content => text()();

  /// Task status: 'open' | 'complete' | 'cancelled' | 'migrated'.
  /// Only meaningful when type = 'task'. Notes/events always 'open'.
  TextColumn get status => text().withDefault(const Constant('open'))();

  /// Display order within the day. Higher = later in list.
  IntColumn get position => integer()();

  /// FK → bullets.id. Set only when status = 'migrated'.
  TextColumn get migratedToId => text().nullable()();

  /// E2E encryption flag. 1 = data encrypted before sync push.
  IntColumn get encryptionEnabled =>
      integer().withDefault(const Constant(0))();

  /// ISO 8601 UTC creation timestamp (immutable).
  TextColumn get createdAt => text()();

  /// ISO 8601 UTC last-modified timestamp — LWW key.
  TextColumn get updatedAt => text()();

  /// Server-assigned UUID. Null until first sync push.
  TextColumn get syncId => text().nullable().unique()();

  /// Device that last wrote this record.
  TextColumn get deviceId => text()();

  /// Soft-delete tombstone.
  IntColumn get isDeleted => integer().withDefault(const Constant(0))();

  /// ISO 8601 date string (YYYY-MM-DD) for scheduling a task to a future day.
  /// Null means no scheduled date.
  TextColumn get scheduledDate => text().nullable()();

  /// Number of times this task has been carried over (kept for today / migrated).
  IntColumn get carryOverCount => integer().withDefault(const Constant(0))();

  /// ISO 8601 UTC timestamp when the task was completed. Null if not completed.
  TextColumn get completedAt => text().nullable()();

  /// ISO 8601 UTC timestamp when the task was canceled. Null if not canceled.
  TextColumn get canceledAt => text().nullable()();

  /// ISO date (YYYY-MM-DD) for a scheduled follow-up. Null = no follow-up.
  TextColumn get followUpDate => text().nullable()();

  /// Follow-up lifecycle status: 'pending' | 'done' | 'snoozed' | 'dismissed'.
  /// Null when no follow-up is attached.
  TextColumn get followUpStatus => text().nullable()();

  /// ISO date (YYYY-MM-DD) when a snoozed follow-up should resurface.
  /// Set only when followUpStatus = 'snoozed'.
  TextColumn get followUpSnoozedUntil => text().nullable()();

  /// ISO 8601 UTC timestamp when this follow-up was marked done.
  /// Set only when followUpStatus = 'done'.
  TextColumn get followUpCompletedAt => text().nullable()();

  /// FK → bullets.id. Set only on completion_event bullets pointing to the
  /// originating log entry that was followed up.
  TextColumn get sourceId => text().nullable()();

  // ── Voice log fields (v6 migration) ─────────────────────────────────────────

  /// Relative path to .m4a file in app documents dir. Null if not a voice log.
  TextColumn get audioFilePath => text().nullable()();

  /// Duration of the recorded audio in whole seconds. Null if not a voice log.
  IntColumn get audioDurationSeconds => integer().nullable()();

  /// Final transcript text. Null if not a voice log or transcription pending.
  TextColumn get transcriptText => text().nullable()();

  /// Transcription state: 'pending' | 'transcribing' | 'complete' | 'failed' | null.
  /// Non-null when sourceType = 'voice'.
  TextColumn get transcriptionStatus => text().nullable()();

  /// Input method: 'typed' | 'voice' | null (null = legacy, treated as typed).
  TextColumn get sourceType => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
