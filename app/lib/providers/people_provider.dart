import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/database/daos/people_dao.dart';
import 'package:antra/providers/database_provider.dart';

part 'people_provider.g.dart';

@riverpod
Stream<List<PeopleData>> allPeople(AllPeopleRef ref) async* {
  final db = await ref.watch(appDatabaseProvider.future);
  yield* PeopleDao(db).watchAllPeople();
}

@riverpod
Stream<List<Bullet>> bulletsForPerson(
  BulletsForPersonRef ref,
  String personId,
) async* {
  final db = await ref.watch(appDatabaseProvider.future);
  yield* PeopleDao(db).watchBulletsForPerson(personId);
}
