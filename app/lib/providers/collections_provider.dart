import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/database/daos/collections_dao.dart';
import 'package:antra/providers/database_provider.dart';

part 'collections_provider.g.dart';

@riverpod
Stream<List<Collection>> allCollections(AllCollectionsRef ref) async* {
  final db = await ref.watch(appDatabaseProvider.future);
  yield* CollectionsDao(db).watchAllCollections();
}
