import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:antra/database/app_database.dart';

part 'people_dao.g.dart';

const _uuid = Uuid();

@DriftAccessor(tables: [People, BulletPersonLinks, Bullets, PendingSync])
class PeopleDao extends DatabaseAccessor<AppDatabase> with _$PeopleDaoMixin {
  PeopleDao(super.db);

  // ---------------------------------------------------------------------------
  // People CRUD
  // ---------------------------------------------------------------------------

  /// Watches all non-deleted people, ordered by name.
  Stream<List<PeopleData>> watchAllPeople() {
    return (select(people)
          ..where((t) => t.isDeleted.equals(0))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  /// Returns a person by exact case-insensitive name, or null.
  Future<PeopleData?> getPersonByName(String name) {
    return (select(people)
          ..where((t) => t.name.lower().equals(name.toLowerCase()))
          ..where((t) => t.isDeleted.equals(0)))
        .getSingleOrNull();
  }

  /// Inserts a new person and enqueues a create sync.
  Future<void> insertPerson(PeopleCompanion companion) async {
    await transaction(() async {
      await into(people).insert(companion);
      await _enqueuePersonSync(companion.id.value, 'create', companion);
    });
  }

  /// Updates an existing person and enqueues an update sync.
  Future<void> updatePerson(PeopleCompanion companion) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final withTimestamp = companion.copyWith(updatedAt: Value(now));
    await transaction(() async {
      await (update(people)
            ..where((t) => t.id.equals(companion.id.value)))
          .write(withTimestamp);
      await _enqueuePersonSync(companion.id.value, 'update', withTimestamp);
    });
  }

  /// Soft-deletes a person and enqueues a delete sync.
  Future<void> softDeletePerson(String id) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await transaction(() async {
      await (update(people)..where((t) => t.id.equals(id))).write(
        PeopleCompanion(
          isDeleted: const Value(1),
          updatedAt: Value(now),
        ),
      );
      await _enqueueSync('person', id, 'delete', {'id': id});
    });
  }

  /// Updates `lastInteractionAt` for a person and enqueues an update sync.
  Future<void> updateLastInteractionAt(String personId, String timestamp) async {
    await transaction(() async {
      await (update(people)..where((t) => t.id.equals(personId))).write(
        PeopleCompanion(
          lastInteractionAt: Value(timestamp),
          updatedAt: Value(timestamp),
        ),
      );
      final updated = await _getPerson(personId);
      if (updated != null) {
        await _enqueuePersonSyncFromRow(updated, 'update');
      }
    });
  }

  // ---------------------------------------------------------------------------
  // BulletPersonLinks
  // ---------------------------------------------------------------------------

  /// Inserts a bullet–person link and enqueues a create sync.
  Future<void> insertLink(String bulletId, String personId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await transaction(() async {
      await into(bulletPersonLinks).insertOnConflictUpdate(
        BulletPersonLinksCompanion.insert(
          bulletId: bulletId,
          personId: personId,
          createdAt: now,
          deviceId: 'local',
        ),
      );
      await _enqueueSync('bullet_person_link', '$bulletId:$personId', 'create', {
        'bulletId': bulletId,
        'personId': personId,
        'createdAt': now,
      });
    });
  }

  /// Watches all non-deleted bullets linked to [personId], newest first.
  Stream<List<Bullet>> watchBulletsForPerson(String personId) {
    final query = select(bulletPersonLinks).join([
      innerJoin(bullets, bullets.id.equalsExp(bulletPersonLinks.bulletId)),
    ])
      ..where(bulletPersonLinks.personId.equals(personId) &
          bulletPersonLinks.isDeleted.equals(0) &
          bullets.isDeleted.equals(0))
      ..orderBy([OrderingTerm.desc(bullets.createdAt)]);
    return query.map((row) => row.readTable(bullets)).watch();
  }

  /// Soft-deletes all bullet_person_links for a given bullet.
  Future<void> softDeleteLinksForBullet(String bulletId) async {
    await (update(bulletPersonLinks)
          ..where((t) => t.bulletId.equals(bulletId)))
        .write(const BulletPersonLinksCompanion(isDeleted: Value(1)));
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<PeopleData?> _getPerson(String id) =>
      (select(people)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> _enqueuePersonSync(
    String id,
    String operation,
    PeopleCompanion companion,
  ) async {
    final payload = {
      'id': id,
      'name': companion.name.value,
      'notes': companion.notes.present ? companion.notes.value : null,
      'reminderCadenceDays': companion.reminderCadenceDays.present
          ? companion.reminderCadenceDays.value
          : null,
      'createdAt': companion.createdAt.present ? companion.createdAt.value : null,
      'updatedAt': companion.updatedAt.present ? companion.updatedAt.value : null,
      'deviceId': companion.deviceId.present ? companion.deviceId.value : null,
    };
    await _enqueueSync('person', id, operation, payload);
  }

  Future<void> _enqueuePersonSyncFromRow(PeopleData row, String operation) async {
    final payload = {
      'id': row.id,
      'name': row.name,
      'notes': row.notes,
      'reminderCadenceDays': row.reminderCadenceDays,
      'lastInteractionAt': row.lastInteractionAt,
      'createdAt': row.createdAt,
      'updatedAt': row.updatedAt,
      'deviceId': row.deviceId,
    };
    await _enqueueSync('person', row.id, operation, payload);
  }

  Future<void> _enqueueSync(
    String entityType,
    String entityId,
    String operation,
    Map<String, dynamic> payload,
  ) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await into(pendingSync).insert(
      PendingSyncCompanion.insert(
        id: _uuid.v4(),
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        payload: jsonEncode(payload),
        createdAt: now,
      ),
    );
  }
}
