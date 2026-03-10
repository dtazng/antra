import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:antra/database/app_database.dart';

part 'task_lifecycle_dao.g.dart';

const _uuid = Uuid();

/// Columns selected for a full Bullet row (includes v2 lifecycle columns).
const _bulletCols =
    'b.id, b.day_id, b.type, b.content, b.status, b.position, '
    'b.migrated_to_id, b.encryption_enabled, b.created_at, b.updated_at, '
    'b.sync_id, b.device_id, b.is_deleted, '
    'b.scheduled_date, b.carry_over_count, b.completed_at, b.canceled_at';

@DriftAccessor(tables: [Bullets, TaskLifecycleEvents, DayLogs])
class TaskLifecycleDao extends DatabaseAccessor<AppDatabase>
    with _$TaskLifecycleDaoMixin {
  TaskLifecycleDao(super.db);

  // ---------------------------------------------------------------------------
  // Lifecycle events
  // ---------------------------------------------------------------------------

  /// Watches all lifecycle events for a task in chronological order.
  Stream<List<TaskLifecycleEvent>> watchEventsForBullet(String bulletId) {
    return (select(taskLifecycleEvents)
          ..where((t) => t.bulletId.equals(bulletId))
          ..orderBy([(t) => OrderingTerm.asc(t.occurredAt)]))
        .watch();
  }

  /// Inserts a new lifecycle event for [bulletId] with [eventType].
  /// [metadata] is optional JSON string (e.g. '{"scheduledDate":"2025-03-15"}').
  ///
  // Lifecycle events are local-only in v1. Sync integration deferred.
  // This method intentionally does NOT call _enqueueSync().
  Future<void> insertEvent(
    String bulletId,
    String eventType, {
    String? metadata,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await into(taskLifecycleEvents).insert(
      TaskLifecycleEventsCompanion.insert(
        id: _uuid.v4(),
        bulletId: bulletId,
        eventType: eventType,
        metadata: Value(metadata),
        occurredAt: now,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Carry-over query (US1)
  // ---------------------------------------------------------------------------

  /// Returns tasks that should appear in the "From Yesterday" section.
  ///
  /// Rules:
  /// - The bullet's day_log.date = [yesterday]
  /// - type = 'task', status = 'open', is_deleted = 0
  /// - scheduled_date IS NULL or scheduled_date <= [today] (not future-scheduled)
  /// - created_at > [sevenDaysAgo] (older tasks go to Weekly Review instead)
  Future<List<Bullet>> getCarryOverTasks(
    String yesterday,
    String today,
    String sevenDaysAgo,
  ) {
    return customSelect(
      'SELECT $_bulletCols FROM bullets b '
      'INNER JOIN day_logs dl ON dl.id = b.day_id '
      "WHERE dl.date = ? AND b.type = 'task' AND b.status = 'open' "
      'AND b.is_deleted = 0 '
      'AND (b.scheduled_date IS NULL OR b.scheduled_date <= ?) '
      'AND b.created_at > ? '
      'ORDER BY b.created_at ASC',
      variables: [
        Variable(yesterday),
        Variable(today),
        Variable(sevenDaysAgo),
      ],
      readsFrom: {bullets, dayLogs},
    ).get().then((rows) => rows.map(_mapRowToBullet).toList());
  }

  /// Watches tasks that should appear in the "From Yesterday" section reactively.
  Stream<List<Bullet>> watchCarryOverTasks(
    String yesterday,
    String today,
    String sevenDaysAgo,
  ) {
    return customSelect(
      'SELECT $_bulletCols FROM bullets b '
      'INNER JOIN day_logs dl ON dl.id = b.day_id '
      "WHERE dl.date = ? AND b.type = 'task' AND b.status = 'open' "
      'AND b.is_deleted = 0 '
      'AND (b.scheduled_date IS NULL OR b.scheduled_date <= ?) '
      'AND b.created_at > ? '
      'ORDER BY b.created_at ASC',
      variables: [
        Variable(yesterday),
        Variable(today),
        Variable(sevenDaysAgo),
      ],
      readsFrom: {bullets, dayLogs},
    ).watch().map((rows) => rows.map(_mapRowToBullet).toList());
  }

  // ---------------------------------------------------------------------------
  // Weekly review query (US3)
  // ---------------------------------------------------------------------------

  /// Watches tasks eligible for Weekly Review: active tasks older than 7 days
  /// that are not future-scheduled, not completed, not canceled, not in backlog.
  Stream<List<Bullet>> watchWeeklyReviewTasks(
    String today,
    String sevenDaysAgo,
  ) {
    return customSelect(
      'SELECT $_bulletCols FROM bullets b '
      "WHERE b.type = 'task' AND b.status = 'open' AND b.is_deleted = 0 "
      'AND b.created_at <= ? '
      'AND (b.scheduled_date IS NULL OR b.scheduled_date <= ?) '
      'ORDER BY b.created_at ASC',
      variables: [Variable(sevenDaysAgo), Variable(today)],
      readsFrom: {bullets},
    ).watch().map((rows) => rows.map(_mapRowToBullet).toList());
  }

  // ---------------------------------------------------------------------------
  // Single bullet lookup
  // ---------------------------------------------------------------------------

  /// Watches a single bullet by id.
  Stream<Bullet?> watchBullet(String bulletId) {
    return (select(bullets)..where((t) => t.id.equals(bulletId)))
        .watchSingleOrNull();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Bullet _mapRowToBullet(QueryRow row) => Bullet(
        id: row.read<String>('id'),
        dayId: row.read<String>('day_id'),
        type: row.read<String>('type'),
        content: row.read<String>('content'),
        status: row.read<String>('status'),
        position: row.read<int>('position'),
        migratedToId: row.readNullable<String>('migrated_to_id'),
        encryptionEnabled: row.read<int>('encryption_enabled'),
        createdAt: row.read<String>('created_at'),
        updatedAt: row.read<String>('updated_at'),
        syncId: row.readNullable<String>('sync_id'),
        deviceId: row.read<String>('device_id'),
        isDeleted: row.read<int>('is_deleted'),
        scheduledDate: row.readNullable<String>('scheduled_date'),
        carryOverCount: row.read<int>('carry_over_count'),
        completedAt: row.readNullable<String>('completed_at'),
        canceledAt: row.readNullable<String>('canceled_at'),
      );
}
