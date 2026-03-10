import 'package:drift/drift.dart';

/// Table: conflict_records
/// Stores the losing version of every sync conflict.
/// Never synced to the server — local audit log only.
class ConflictRecords extends Table {
  TextColumn get id => text()();

  /// The type of entity that conflicted.
  TextColumn get entityType => text()();

  /// The UUID of the conflicting entity.
  TextColumn get entityId => text()();

  /// JSON snapshot of the local version that lost the LWW resolution.
  TextColumn get localSnapshot => text()();

  /// JSON snapshot of the remote version that won (now applied locally).
  TextColumn get remoteSnapshot => text()();

  /// ISO 8601 UTC when the conflict was detected.
  TextColumn get detectedAt => text()();

  /// ISO 8601 UTC when the user resolved this conflict. Null = unresolved.
  TextColumn get resolvedAt => text().nullable()();

  /// How the user resolved it: 'kept_remote' | 'restored_local' | 'dismissed'
  TextColumn get resolution => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
