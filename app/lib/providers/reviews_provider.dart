import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/database/daos/bullets_dao.dart';
import 'package:antra/database/daos/reviews_dao.dart';
import 'package:antra/providers/database_provider.dart';

part 'reviews_provider.g.dart';

@riverpod
Stream<List<Review>> allReviews(AllReviewsRef ref) async* {
  final db = await ref.watch(appDatabaseProvider.future);
  yield* ReviewsDao(db).watchReviews();
}

@riverpod
Future<List<Bullet>> openTasksForPeriod(
  OpenTasksForPeriodRef ref,
  String startDate,
  String endDate,
) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return BulletsDao(db).getOpenTasksForPeriod(startDate, endDate);
}

@riverpod
Future<List<Bullet>> eventsForPeriod(
  EventsForPeriodRef ref,
  String startDate,
  String endDate,
) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return BulletsDao(db).getEventsForPeriod(startDate, endDate);
}
