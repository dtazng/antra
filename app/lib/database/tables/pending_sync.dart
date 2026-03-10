import 'package:drift/drift.dart';

/// Table: pending_sync
/// Durable offline queue. Every local write enqueues a row here.
/// Rows are deleted after successful sync confirmation.
/// Never synced to the server itself.
class PendingSync extends Table {
  TextColumn get id => text()();

  /// The entity type: 'bullet' | 'day_log' | 'person' | 'tag' | etc.
  TextColumn get entityType => text()();

  /// The UUID of the entity being synced.
  TextColumn get entityId => text()();

  /// Operation: 'create' | 'update' | 'delete'
  TextColumn get operation => text()();

  /// JSON-serialized snapshot of the entity at time of write.
  TextColumn get payload => text()();

  TextColumn get createdAt => text()();

  /// How many sync attempts have failed for this item.
  IntColumn get retryCount => integer().withDefault(const Constant(0))();

  /// Last error message if a sync attempt failed.
  TextColumn get lastError => text().nullable()();

  /// 1 once successfully uploaded; row is deleted shortly after.
  IntColumn get isSynced => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
