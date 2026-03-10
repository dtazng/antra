import 'dart:convert';
import 'dart:typed_data';

import 'package:antra/database/app_database.dart';
import 'package:antra/database/tables/conflict_records.dart';
import 'package:antra/services/api_client.dart';
import 'package:antra/services/encryption_service.dart';
import 'package:antra/services/sync_queue_manager.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Orchestrates the full pull → push sync cycle.
///
/// Call [sync] on app foreground resume and from the workmanager background
/// task. The method is idempotent — calling it while already syncing is a no-op.
class SyncEngine {
  final AppDatabase _db;
  final ApiClient _apiClient;
  final SyncQueueManager _queue;

  bool _isSyncing = false;

  /// Optional E2E encryption key (Pro tier). When set, payloads with
  /// `encryptionEnabled = true` are encrypted before being pushed.
  Uint8List? encryptionKey;

  final EncryptionService _encryption = EncryptionService();

  SyncEngine({
    required AppDatabase db,
    required ApiClient apiClient,
    this.encryptionKey,
  })  : _db = db,
        _apiClient = apiClient,
        _queue = SyncQueueManager(db);

  /// Runs a full sync cycle: pull remote changes, then push local changes.
  ///
  /// Returns silently if already in progress.
  Future<void> sync() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      await _pull();
      await _push();
    } finally {
      _isSyncing = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Pull: apply remote changes to local database
  // ---------------------------------------------------------------------------

  Future<void> _pull() async {
    // Read the last-known sync timestamp from the database (stored as metadata).
    final lastSyncTs = await _readLastSyncTimestamp();

    String? cursor;
    do {
      final response = await _apiClient.pull(
        SyncPullRequest(lastSyncTimestamp: lastSyncTs, cursor: cursor),
      );

      for (final record in response.records) {
        await _applyRemoteRecord(record);
      }

      cursor = response.hasMore ? response.nextCursor : null;

      if (!response.hasMore) {
        await _writeLastSyncTimestamp(response.serverTimestamp);
      }
    } while (cursor != null);
  }

  /// Upserts a remote record into the appropriate local drift table.
  Future<void> _applyRemoteRecord(Map<String, dynamic> record) async {
    final entityType = record['entityType'] as String?;
    switch (entityType) {
      case 'bullet':
        await _upsertBullet(record);
      case 'person':
        await _upsertPerson(record);
      // Additional entity types handled in future phases.
      default:
        break;
    }
  }

  Future<void> _upsertBullet(Map<String, dynamic> r) async {
    final now = r['updatedAt'] as String? ??
        DateTime.now().toUtc().toIso8601String();
    await _db.into(_db.bullets).insertOnConflictUpdate(
      BulletsCompanion.insert(
        id: r['id'] as String,
        dayId: r['dayId'] as String,
        content: r['content'] as String? ?? '',
        type: Value(r['type'] as String? ?? 'note'),
        status: Value(r['status'] as String? ?? 'open'),
        position: r['position'] as int? ?? 0,
        createdAt: r['createdAt'] as String? ?? now,
        updatedAt: now,
        deviceId: r['deviceId'] as String? ?? 'remote',
        syncId: Value(r['syncId'] as String?),
        isDeleted: Value(r['isDeleted'] as int? ?? 0),
      ),
    );
  }

  Future<void> _upsertPerson(Map<String, dynamic> r) async {
    final now = r['updatedAt'] as String? ??
        DateTime.now().toUtc().toIso8601String();
    await _db.into(_db.people).insertOnConflictUpdate(
      PeopleCompanion.insert(
        id: r['id'] as String,
        name: r['name'] as String? ?? '',
        notes: Value(r['notes'] as String?),
        reminderCadenceDays: Value(r['reminderCadenceDays'] as int?),
        lastInteractionAt: Value(r['lastInteractionAt'] as String?),
        createdAt: r['createdAt'] as String? ?? now,
        updatedAt: now,
        deviceId: r['deviceId'] as String? ?? 'remote',
        syncId: Value(r['syncId'] as String?),
        isDeleted: Value(r['isDeleted'] as int? ?? 0),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Push: upload local pending changes
  // ---------------------------------------------------------------------------

  Future<void> _push() async {
    final items = await _queue.drainQueue();
    if (items.isEmpty) return;

    var records = items.map(_queue.toSyncRecord).toList();
    // E2E encryption (Pro tier): encrypt payloads where the source bullet
    // has encryptionEnabled = true and an encryption key is configured.
    if (encryptionKey != null) {
      records = records.map((r) {
        final encEnabled = r.payload['encryptionEnabled'];
        if (encEnabled == 1 || encEnabled == true) {
          final encrypted = _encryption.encrypt(
            jsonEncode(r.payload),
            encryptionKey!,
          );
          return SyncRecord(
            entityType: r.entityType,
            entityId: r.entityId,
            operation: r.operation,
            payload: {'encrypted': encrypted, 'encryptionEnabled': 1},
            syncId: r.syncId,
          );
        }
        return r;
      }).toList();
    }
    final successIds = <String>[];

    SyncPushResponse response;
    try {
      response = await _apiClient.push(SyncPushRequest(records: records));
    } catch (e) {
      // If the push fails entirely, mark all items as failed.
      for (final item in items) {
        await _queue.reportFailed(item.id, e.toString());
      }
      return;
    }

    // Mark successfully applied items as synced.
    for (final item in items) {
      if (!_isConflict(item.entityId, response.conflicts)) {
        successIds.add(item.id);
      }
    }
    await _queue.confirmSynced(successIds);

    // Record each conflict in the local audit log.
    for (final conflict in response.conflicts) {
      await _recordConflict(conflict);
    }
  }

  bool _isConflict(
    String entityId,
    List<ConflictInfo> conflicts,
  ) {
    return conflicts.any((c) {
      final client = c.clientItem;
      return client['entityId'] == entityId ||
          (client['payload'] as Map?)?['id'] == entityId;
    });
  }

  Future<void> _recordConflict(ConflictInfo conflict) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final clientPayload = conflict.clientItem['payload'] as Map? ?? {};
    final serverItem = conflict.serverItem;

    final entityType =
        conflict.clientItem['entityType'] as String? ?? 'unknown';
    final entityId =
        clientPayload['id'] as String? ??
        conflict.clientItem['entityId'] as String? ??
        _uuid.v4();

    await _db.into(_db.conflictRecords).insertOnConflictUpdate(
      ConflictRecordsCompanion.insert(
        id: _uuid.v4(),
        entityType: entityType,
        entityId: entityId,
        localSnapshot: jsonEncode(clientPayload),
        remoteSnapshot: jsonEncode(serverItem),
        detectedAt: now,
      ),
    );

    // Apply the winning server version locally (LWW: server wins).
    await _applyRemoteRecord({
      ...serverItem,
      'entityType': entityType,
    });
  }

  // ---------------------------------------------------------------------------
  // Last-sync timestamp persistence (stored as a special row in pending_sync)
  // ---------------------------------------------------------------------------

  static const _metaEntityType = '__meta__';
  static const _metaEntityId   = 'lastSyncTimestamp';
  static const _epoch           = '1970-01-01T00:00:00Z';

  Future<String> _readLastSyncTimestamp() async {
    final rows = await (_db.select(_db.pendingSync)
          ..where((t) =>
              t.entityType.equals(_metaEntityType) &
              t.entityId.equals(_metaEntityId)))
        .get();
    if (rows.isEmpty) return _epoch;
    return rows.first.payload;
  }

  Future<void> _writeLastSyncTimestamp(String ts) async {
    await _db.into(_db.pendingSync).insertOnConflictUpdate(
      PendingSyncCompanion.insert(
        id: 'meta-last-sync',
        entityType: _metaEntityType,
        entityId: _metaEntityId,
        operation: 'meta',
        payload: ts,
        createdAt: ts,
        isSynced: const Value(1),
      ),
    );
  }
}
