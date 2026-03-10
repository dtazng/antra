import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/database/daos/task_lifecycle_dao.dart';
import 'package:antra/providers/database_provider.dart';
import 'package:antra/services/task_lifecycle_service.dart';

part 'task_lifecycle_provider.g.dart';

final _dateFormat = DateFormat('yyyy-MM-dd');

String _localDateString(DateTime dt) => _dateFormat.format(dt.toLocal());

/// Provides the [TaskLifecycleService] singleton backed by the app database.
@riverpod
Future<TaskLifecycleService> taskLifecycleService(
  TaskLifecycleServiceRef ref,
) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return TaskLifecycleService(db: db, deviceId: 'local');
}

/// Watches tasks that appear in the "From Yesterday" section of Today.
///
/// Mutually exclusive with [weeklyReviewTasksProvider] — tasks older than
/// 7 days are excluded here and appear in Weekly Review instead.
@riverpod
Stream<List<Bullet>> carryOverTasks(CarryOverTasksRef ref) async* {
  final db = await ref.watch(appDatabaseProvider.future);
  final dao = TaskLifecycleDao(db);

  final now = DateTime.now();
  final today = _localDateString(now);
  final yesterday = _localDateString(now.subtract(const Duration(days: 1)));
  final sevenDaysAgo = _localDateString(now.subtract(const Duration(days: 7)));

  yield* dao.watchCarryOverTasks(yesterday, today, sevenDaysAgo);
}

/// Watches tasks eligible for the Weekly Review queue.
///
/// Returns active tasks with created_at older than 7 days that are not
/// future-scheduled, not completed, not canceled, and not in backlog.
@riverpod
Stream<List<Bullet>> weeklyReviewTasks(WeeklyReviewTasksRef ref) async* {
  final db = await ref.watch(appDatabaseProvider.future);
  final dao = TaskLifecycleDao(db);

  final now = DateTime.now();
  final today = _localDateString(now);
  final sevenDaysAgo = _localDateString(now.subtract(const Duration(days: 7)));

  yield* dao.watchWeeklyReviewTasks(today, sevenDaysAgo);
}

/// Watches all lifecycle events for a specific task (bullet), in order.
@riverpod
Stream<List<TaskLifecycleEvent>> taskLifecycleEvents(
  TaskLifecycleEventsRef ref,
  String bulletId,
) async* {
  final db = await ref.watch(appDatabaseProvider.future);
  final dao = TaskLifecycleDao(db);
  yield* dao.watchEventsForBullet(bulletId);
}

/// Watches a single bullet by id. Used by TaskDetailScreen.
@riverpod
Stream<Bullet?> singleBullet(SingleBulletRef ref, String bulletId) async* {
  final db = await ref.watch(appDatabaseProvider.future);
  final dao = TaskLifecycleDao(db);
  yield* dao.watchBullet(bulletId);
}
