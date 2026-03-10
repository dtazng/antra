import 'dart:convert';

import 'package:antra/database/app_database.dart';
import 'package:antra/database/daos/sync_dao.dart';
import 'package:antra/services/api_client.dart';

/// Wraps [SyncDao] with convenient batch-oriented methods for [SyncEngine].
class SyncQueueManager {
  final SyncDao _dao;

  SyncQueueManager(AppDatabase db) : _dao = SyncDao(db);

  static const _maxBatchSize = 500;

  /// Returns the next batch of unsynced items (up to 500).
  Future<List<PendingSyncData>> drainQueue() async {
    final all = await _dao.getPendingItems();
    return all.take(_maxBatchSize).toList();
  }

  /// Enqueues a new item for sync.
  Future<void> enqueue({
    required String id,
    required String entityType,
    required String entityId,
    required String operation,
    required String payload,
    required String createdAt,
  }) {
    return _dao.enqueuePendingSync(
      id: id,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: payload,
      createdAt: createdAt,
    );
  }

  /// Marks a batch of items as successfully synced and deletes them.
  Future<void> confirmSynced(List<String> ids) async {
    for (final id in ids) {
      await _dao.markSynced(id);
    }
    await _dao.deleteSynced();
  }

  /// Records a failed sync attempt for a single item.
  Future<void> reportFailed(String id, String error) {
    return _dao.markFailed(id, error);
  }

  /// Converts a [PendingSyncData] to a [SyncRecord] for the API.
  SyncRecord toSyncRecord(PendingSyncData item) {
    Map<String, dynamic> payload;
    try {
      payload = (jsonDecode(item.payload) as Map).cast<String, dynamic>();
    } catch (_) {
      payload = {};
    }
    return SyncRecord(
      entityType: item.entityType,
      entityId: item.entityId,
      operation: item.operation,
      payload: payload,
    );
  }
}
