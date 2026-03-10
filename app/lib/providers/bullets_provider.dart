import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/database/daos/bullets_dao.dart';
import 'package:antra/providers/database_provider.dart';

part 'bullets_provider.g.dart';

/// Watches all bullets for a given [date] (YYYY-MM-DD).
///
/// Returns an empty list while the database is loading.
@riverpod
Stream<List<Bullet>> bulletsForDay(BulletsForDayRef ref, String date) async* {
  final db = await ref.watch(appDatabaseProvider.future);
  final dao = BulletsDao(db);
  final dayLog = await dao.getOrCreateDayLog(date);
  yield* dao.watchBulletsForDay(dayLog.id);
}
