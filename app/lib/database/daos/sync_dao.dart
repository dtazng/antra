import 'package:drift/drift.dart';

import 'package:antra/database/app_database.dart';

part 'sync_dao.g.dart';

@DriftAccessor(tables: [PendingSync])
class SyncDao extends DatabaseAccessor<AppDatabase> with _$SyncDaoMixin {
  SyncDao(super.db);

  /// Returns all unsynced pending items, oldest first.
  Future<List<PendingSyncData>> getPendingItems() {
    return (select(pendingSync)
          ..where((t) => t.isSynced.equals(0))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  /// Enqueues a new sync item.
  Future<void> enqueuePendingSync({
    required String id,
    required String entityType,
    required String entityId,
    required String operation,
    required String payload,
    required String createdAt,
  }) {
    return into(pendingSync).insert(
      PendingSyncCompanion.insert(
        id: id,
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        payload: payload,
        createdAt: createdAt,
      ),
    );
  }

  /// Marks a pending sync row as successfully synced (row will be deleted
  /// by the SyncEngine after confirmation).
  Future<void> markSynced(String id) {
    return (update(pendingSync)..where((t) => t.id.equals(id))).write(
      const PendingSyncCompanion(isSynced: Value(1)),
    );
  }

  /// Records a failed sync attempt — increments retryCount and stores the error.
  Future<void> markFailed(String id, String error) async {
    final row = await (select(pendingSync)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return;
    await (update(pendingSync)..where((t) => t.id.equals(id))).write(
      PendingSyncCompanion(
        retryCount: Value(row.retryCount + 1),
        lastError: Value(error),
      ),
    );
  }

  /// Deletes all rows that have been successfully synced.
  Future<void> deleteSynced() {
    return (delete(pendingSync)..where((t) => t.isSynced.equals(1))).go();
  }
}
