import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/database/daos/task_lifecycle_dao.dart';

const _uuid = Uuid();

/// Pure Dart service (no Flutter imports) that owns all task lifecycle
/// state transitions. All writes go through this service — UI code never
/// writes task status directly.
///
/// Every method runs inside a [db.transaction()] to ensure atomicity.
class TaskLifecycleService {
  final AppDatabase _db;
  final String _deviceId;
  late final TaskLifecycleDao _dao;

  TaskLifecycleService({required AppDatabase db, required String deviceId})
      : _db = db,
        _deviceId = deviceId {
    _dao = TaskLifecycleDao(_db);
  }

  // ---------------------------------------------------------------------------
  // State transitions
  // ---------------------------------------------------------------------------

  /// Marks a task as complete.
  /// Sets status='complete', completedAt=now, appends 'completed' event.
  Future<void> completeTask(String bulletId) async {
    await _db.transaction(() async {
      final now = DateTime.now().toUtc().toIso8601String();
      await (_db.update(_db.bullets)..where((t) => t.id.equals(bulletId)))
          .write(
        BulletsCompanion(
          status: const Value('complete'),
          completedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await _dao.insertEvent(bulletId, 'completed');
    });
  }

  /// Cancels a task immediately. Use [reactivateTask] to undo within 3 seconds.
  /// Sets status='cancelled', canceledAt=now, appends 'canceled' event.
  Future<void> cancelTask(String bulletId) async {
    await _db.transaction(() async {
      final now = DateTime.now().toUtc().toIso8601String();
      await (_db.update(_db.bullets)..where((t) => t.id.equals(bulletId)))
          .write(
        BulletsCompanion(
          status: const Value('cancelled'),
          canceledAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await _dao.insertEvent(bulletId, 'canceled');
    });
  }

  /// Moves a task into today's log without changing its status.
  /// Updates dayId to today's DayLog, increments carryOverCount,
  /// appends 'kept_for_today' event.
  Future<void> keepForToday(String bulletId, String todayDate) async {
    final todayLog = await _getOrCreateDayLog(todayDate);
    final yesterday = _previousDateString(todayDate);

    await _db.transaction(() async {
      final now = DateTime.now().toUtc().toIso8601String();
      final bullet = await (_db.select(_db.bullets)
            ..where((t) => t.id.equals(bulletId)))
          .getSingle();

      await (_db.update(_db.bullets)..where((t) => t.id.equals(bulletId)))
          .write(
        BulletsCompanion(
          dayId: Value(todayLog.id),
          carryOverCount: Value(bullet.carryOverCount + 1),
          updatedAt: Value(now),
        ),
      );
      await _dao.insertEvent(
        bulletId,
        'kept_for_today',
        metadata: jsonEncode({'fromDate': yesterday, 'toDate': todayDate}),
      );
    });
  }

  /// Schedules a task for a specific date. Pass null to clear the schedule.
  /// Sets scheduledDate=[date], appends 'scheduled' event.
  Future<void> scheduleTask(String bulletId, String? date) async {
    await _db.transaction(() async {
      final now = DateTime.now().toUtc().toIso8601String();
      await (_db.update(_db.bullets)..where((t) => t.id.equals(bulletId)))
          .write(
        BulletsCompanion(
          scheduledDate: Value(date),
          updatedAt: Value(now),
        ),
      );
      await _dao.insertEvent(
        bulletId,
        'scheduled',
        metadata: jsonEncode({'scheduledDate': date}),
      );
    });
  }

  /// Moves a task to the backlog. Clears any scheduled date.
  /// Sets status='backlog', clears scheduledDate, appends 'moved_to_backlog' event.
  Future<void> moveToBacklog(String bulletId) async {
    await _db.transaction(() async {
      final now = DateTime.now().toUtc().toIso8601String();
      await (_db.update(_db.bullets)..where((t) => t.id.equals(bulletId)))
          .write(
        BulletsCompanion(
          status: const Value('backlog'),
          scheduledDate: const Value(null),
          updatedAt: Value(now),
        ),
      );
      await _dao.insertEvent(bulletId, 'moved_to_backlog');
    });
  }

  /// Reactivates a backlog or canceled task into today's log.
  /// Sets status='open', updates dayId to today, appends 'reactivated' event.
  Future<void> reactivateTask(String bulletId, String todayDate) async {
    final todayLog = await _getOrCreateDayLog(todayDate);

    await _db.transaction(() async {
      final now = DateTime.now().toUtc().toIso8601String();
      await (_db.update(_db.bullets)..where((t) => t.id.equals(bulletId)))
          .write(
        BulletsCompanion(
          status: const Value('open'),
          dayId: Value(todayLog.id),
          canceledAt: const Value(null),
          updatedAt: Value(now),
        ),
      );
      await _dao.insertEvent(bulletId, 'reactivated');
    });
  }

  /// Converts a task to a note. Terminal action — the item leaves all queues.
  /// Sets type='note', appends 'converted_to_note' event.
  Future<void> convertToNote(String bulletId) async {
    await _db.transaction(() async {
      final now = DateTime.now().toUtc().toIso8601String();
      await (_db.update(_db.bullets)..where((t) => t.id.equals(bulletId)))
          .write(
        BulletsCompanion(
          type: const Value('note'),
          updatedAt: Value(now),
        ),
      );
      await _dao.insertEvent(bulletId, 'converted_to_note');
    });
  }

  /// Moves a task from the Weekly Review queue into this week's active log.
  /// Semantically identical to [keepForToday] — delegates to it.
  /// They are kept separate for lifecycle event readability.
  Future<void> moveToThisWeek(String bulletId, String todayDate) async {
    await keepForToday(bulletId, todayDate);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<DayLog> _getOrCreateDayLog(String date) async {
    final existing = await (_db.select(_db.dayLogs)
          ..where((t) => t.date.equals(date)))
        .getSingleOrNull();
    if (existing != null) return existing;

    final now = DateTime.now().toUtc().toIso8601String();
    final id = _uuid.v4();
    await _db.into(_db.dayLogs).insert(
          DayLogsCompanion.insert(
            id: id,
            date: date,
            createdAt: now,
            updatedAt: now,
            deviceId: _deviceId,
          ),
        );
    return (_db.select(_db.dayLogs)..where((t) => t.date.equals(date)))
        .getSingle();
  }

  /// Returns the ISO date string for the day before [dateString] (YYYY-MM-DD).
  String _previousDateString(String dateString) {
    final dt = DateTime.parse(dateString);
    final prev = dt.subtract(const Duration(days: 1));
    return '${prev.year.toString().padLeft(4, '0')}-'
        '${prev.month.toString().padLeft(2, '0')}-'
        '${prev.day.toString().padLeft(2, '0')}';
  }
}
