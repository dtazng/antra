import 'package:drift/drift.dart';

/// Table: person_important_dates
/// A named date (birthday, anniversary, etc.) associated with a person,
/// with an optional reminder rule. Synced to backend via LWW.
class PersonImportantDates extends Table {
  /// Client-generated UUID primary key.
  TextColumn get id => text()();

  /// FK → people.id.
  TextColumn get personId => text()();

  /// Human-readable label, e.g. "Birthday", "Anniversary".
  TextColumn get label => text()();

  /// 1 = birthday — special visual treatment, appears first. Default 0.
  IntColumn get isBirthday => integer().withDefault(const Constant(0))();

  /// Month of the date (1–12).
  IntColumn get month => integer()();

  /// Day of the date (1–31).
  IntColumn get day => integer()();

  /// Optional year. Null = recurs annually.
  IntColumn get year => integer().nullable()();

  /// Days offset for reminder. Negative = before, 0 = on day, null = no reminder.
  IntColumn get reminderOffsetDays => integer().nullable()();

  /// Recurrence for reminder: 'yearly' | 'once' | null.
  TextColumn get reminderRecurrence => text().nullable()();

  /// Optional personal note.
  TextColumn get note => text().nullable()();

  /// ISO 8601 UTC creation timestamp (immutable).
  TextColumn get createdAt => text()();

  /// ISO 8601 UTC last-modified timestamp — LWW key.
  TextColumn get updatedAt => text()();

  /// Server-assigned UUID. Null until first sync push.
  TextColumn get syncId => text().nullable().unique()();

  /// Device that last wrote this record.
  TextColumn get deviceId => text()();

  /// Soft-delete tombstone. Default 0.
  IntColumn get isDeleted => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
