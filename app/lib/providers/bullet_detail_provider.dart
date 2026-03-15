import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:antra/database/daos/bullets_dao.dart';
import 'package:antra/database/daos/people_dao.dart';
import 'package:antra/models/bullet_detail.dart';
import 'package:antra/models/linked_person.dart';
import 'package:antra/providers/database_provider.dart';

part 'bullet_detail_provider.g.dart';

@riverpod
Future<BulletDetail?> bulletDetail(BulletDetailRef ref, String bulletId) async {
  final db = await ref.watch(appDatabaseProvider.future);
  final bullet = await BulletsDao(db).getBulletById(bulletId);
  if (bullet == null) return null;
  final rawPersons = await PeopleDao(db).getLinkedPeopleForBullet(bulletId);
  final persons =
      rawPersons.map((p) => LinkedPerson(id: p.id, name: p.name)).toList();
  return BulletDetail.fromBullet(bullet, persons);
}
