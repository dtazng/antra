import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/database/daos/task_lifecycle_dao.dart';

const _uuid = Uuid();

/// Opens an in-memory AppDatabase for testing.
AppDatabase _openTestDb() => AppDatabase(NativeDatabase.memory());

/// Returns a YYYY-MM-DD string for [daysAgo] days before today (local time).
String _dateOffset(int daysAgo) {
  final d = DateTime.now().toLocal().subtract(Duration(days: daysAgo));
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Returns an ISO 8601 UTC timestamp for [daysAgo] days before now.
String _tsOffset(int daysAgo) =>
    DateTime.now().toUtc().subtract(Duration(days: daysAgo)).toIso8601String();

/// Seeds one open task into [db] whose day_log date is [dayLogDate].
Future<String> _seedTask(
  AppDatabase db, {
  required String dayLogDate,
  int daysAgoCreated = 0,
}) async {
  final dayLogId = _uuid.v4();
  final bulletId = _uuid.v4();
  final ts = DateTime.now().toUtc().toIso8601String();

  await db.into(db.dayLogs).insertOnConflictUpdate(
        DayLogsCompanion.insert(
          id: dayLogId,
          date: dayLogDate,
          createdAt: ts,
          updatedAt: ts,
          deviceId: 'test',
        ),
      );

  await db.into(db.bullets).insert(
        BulletsCompanion.insert(
          id: bulletId,
          dayId: dayLogId,
          type: const Value('task'),
          content: 'Test task $dayLogDate',
          status: const Value('open'),
          position: 0,
          createdAt: _tsOffset(daysAgoCreated),
          updatedAt: ts,
          deviceId: 'test',
        ),
      );

  return bulletId;
}

void main() {
  late AppDatabase db;
  late TaskLifecycleDao dao;

  setUp(() {
    db = _openTestDb();
    dao = TaskLifecycleDao(db);
  });

  tearDown(() => db.close());

  group('watchCarryOverTasks — date range query', () {
    test('returns task from 3 days ago (passive carry-over, no action taken)', () async {
      // Arrange: task created and in DayLog 3 days ago; user never interacted.
      final threeDaysAgoDate = _dateOffset(3);
      await _seedTask(db, dayLogDate: threeDaysAgoDate, daysAgoCreated: 3);

      final today = _dateOffset(0);
      final sevenDaysAgo = _dateOffset(7);

      // Act
      final tasks = await dao.getCarryOverTasks(sevenDaysAgo, today);

      // Assert: task from 3 days ago should appear.
      expect(tasks, hasLength(1));
      expect(tasks.first.content, contains(threeDaysAgoDate));
    });

    test('returns task from 1 day ago', () async {
      final yesterdayDate = _dateOffset(1);
      await _seedTask(db, dayLogDate: yesterdayDate, daysAgoCreated: 1);

      final today = _dateOffset(0);
      final sevenDaysAgo = _dateOffset(7);

      final tasks = await dao.getCarryOverTasks(sevenDaysAgo, today);

      expect(tasks, hasLength(1));
    });

    test('returns task from 7 days ago (boundary — last day in carry-over window)', () async {
      final sevenDaysAgoDate = _dateOffset(7);
      await _seedTask(db, dayLogDate: sevenDaysAgoDate, daysAgoCreated: 7);

      final today = _dateOffset(0);
      final sevenDaysAgo = _dateOffset(7);

      final tasks = await dao.getCarryOverTasks(sevenDaysAgo, today);

      expect(tasks, hasLength(1));
    });

    test('does NOT return task from today (same-day task is not carried over)', () async {
      final todayDate = _dateOffset(0);
      await _seedTask(db, dayLogDate: todayDate, daysAgoCreated: 0);

      final today = _dateOffset(0);
      final sevenDaysAgo = _dateOffset(7);

      final tasks = await dao.getCarryOverTasks(sevenDaysAgo, today);

      expect(tasks, isEmpty);
    });

    test('does NOT return task older than 7 days (goes to Weekly Review instead)', () async {
      final eightDaysAgoDate = _dateOffset(8);
      await _seedTask(db, dayLogDate: eightDaysAgoDate, daysAgoCreated: 8);

      final today = _dateOffset(0);
      final sevenDaysAgo = _dateOffset(7);

      final tasks = await dao.getCarryOverTasks(sevenDaysAgo, today);

      expect(tasks, isEmpty);
    });

    test('does NOT return completed tasks', () async {
      final yesterdayDate = _dateOffset(1);
      final bulletId = await _seedTask(db, dayLogDate: yesterdayDate, daysAgoCreated: 1);
      // Mark as complete.
      await (db.update(db.bullets)..where((t) => t.id.equals(bulletId))).write(
        const BulletsCompanion(status: Value('complete')),
      );

      final today = _dateOffset(0);
      final sevenDaysAgo = _dateOffset(7);

      final tasks = await dao.getCarryOverTasks(sevenDaysAgo, today);

      expect(tasks, isEmpty);
    });

    test('does NOT return backlog tasks', () async {
      final yesterdayDate = _dateOffset(1);
      final bulletId = await _seedTask(db, dayLogDate: yesterdayDate, daysAgoCreated: 1);
      await (db.update(db.bullets)..where((t) => t.id.equals(bulletId))).write(
        const BulletsCompanion(status: Value('backlog')),
      );

      final today = _dateOffset(0);
      final sevenDaysAgo = _dateOffset(7);

      final tasks = await dao.getCarryOverTasks(sevenDaysAgo, today);

      expect(tasks, isEmpty);
    });

    test('returns tasks from multiple past days when user never interacted', () async {
      await _seedTask(db, dayLogDate: _dateOffset(1), daysAgoCreated: 1);
      await _seedTask(db, dayLogDate: _dateOffset(3), daysAgoCreated: 3);
      await _seedTask(db, dayLogDate: _dateOffset(6), daysAgoCreated: 6);

      final today = _dateOffset(0);
      final sevenDaysAgo = _dateOffset(7);

      final tasks = await dao.getCarryOverTasks(sevenDaysAgo, today);

      expect(tasks, hasLength(3));
    });
  });

  group('watchWeeklyReviewTasks', () {
    test('returns task older than 7 days', () async {
      final eightDaysAgoDate = _dateOffset(8);
      await _seedTask(db, dayLogDate: eightDaysAgoDate, daysAgoCreated: 8);

      final today = _dateOffset(0);
      final sevenDaysAgo = _dateOffset(7);

      final tasks = await dao.watchWeeklyReviewTasks(today, sevenDaysAgo).first;

      expect(tasks, hasLength(1));
    });

    test('does NOT return task within 7-day carry-over window', () async {
      final threeDaysAgoDate = _dateOffset(3);
      await _seedTask(db, dayLogDate: threeDaysAgoDate, daysAgoCreated: 3);

      final today = _dateOffset(0);
      final sevenDaysAgo = _dateOffset(7);

      final tasks = await dao.watchWeeklyReviewTasks(today, sevenDaysAgo).first;

      expect(tasks, isEmpty);
    });
  });
}
