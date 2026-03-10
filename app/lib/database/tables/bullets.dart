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

  @override
  Set<Column> get primaryKey => {id};
}
