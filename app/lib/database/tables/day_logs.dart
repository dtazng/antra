import 'package:drift/drift.dart';

/// Table: day_logs
/// One row per calendar date. Container for all bullets of that day.
class DayLogs extends Table {
  /// Client-generated UUID primary key.
  TextColumn get id => text()();

  /// Calendar date in YYYY-MM-DD format. Unique per user.
  TextColumn get date => text().unique()();

  /// ISO 8601 UTC creation timestamp (immutable).
  TextColumn get createdAt => text()();

  /// ISO 8601 UTC last-modified timestamp — used for LWW sync resolution.
  TextColumn get updatedAt => text()();

  /// Server-assigned UUID after first successful push. Null until synced.
  TextColumn get syncId => text().nullable().unique()();

  /// UUID of the device that last wrote this record.
  TextColumn get deviceId => text()();

  /// Soft-delete tombstone. 1 = deleted; 0 = active.
  IntColumn get isDeleted => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [];
}
