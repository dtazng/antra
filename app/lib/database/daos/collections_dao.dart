import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:antra/database/app_database.dart';

part 'collections_dao.g.dart';

const _uuid = Uuid();

@DriftAccessor(tables: [Collections, PendingSync])
class CollectionsDao extends DatabaseAccessor<AppDatabase>
    with _$CollectionsDaoMixin {
  CollectionsDao(super.db);

  /// Watches all non-deleted collections ordered by position.
  Stream<List<Collection>> watchAllCollections() {
    return (select(collections)
          ..where((t) => t.isDeleted.equals(0))
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .watch();
  }

  /// Inserts a new collection and enqueues a create sync.
  Future<void> insertCollection(CollectionsCompanion companion) async {
    await transaction(() async {
      await into(collections).insert(companion);
      await _enqueueSync(companion.id.value, 'create', companion);
    });
  }

  /// Updates an existing collection and enqueues an update sync.
  Future<void> updateCollection(CollectionsCompanion companion) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final withTs = companion.copyWith(updatedAt: Value(now));
    await transaction(() async {
      await (update(collections)
            ..where((t) => t.id.equals(companion.id.value)))
          .write(withTs);
      await _enqueueSync(companion.id.value, 'update', withTs);
    });
  }

  /// Soft-deletes a collection and enqueues a delete sync.
  Future<void> softDeleteCollection(String id) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await transaction(() async {
      await (update(collections)..where((t) => t.id.equals(id))).write(
        CollectionsCompanion(
          isDeleted: const Value(1),
          updatedAt: Value(now),
        ),
      );
      await _enqueueSyncRaw('collection', id, 'delete', {'id': id});
    });
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<void> _enqueueSync(
    String id,
    String operation,
    CollectionsCompanion companion,
  ) async {
    final payload = {
      'id': id,
      'name': companion.name.value,
      'description':
          companion.description.present ? companion.description.value : null,
      'filterRules': companion.filterRules.value,
      'position': companion.position.value,
      'createdAt': companion.createdAt.present ? companion.createdAt.value : null,
      'updatedAt': companion.updatedAt.present ? companion.updatedAt.value : null,
      'deviceId': companion.deviceId.present ? companion.deviceId.value : null,
    };
    await _enqueueSyncRaw('collection', id, operation, payload);
  }

  Future<void> _enqueueSyncRaw(
    String entityType,
    String entityId,
    String operation,
    Map<String, dynamic> payload,
  ) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await into(pendingSync).insert(
      PendingSyncCompanion.insert(
        id: _uuid.v4(),
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        payload: jsonEncode(payload),
        createdAt: now,
      ),
    );
  }
}
