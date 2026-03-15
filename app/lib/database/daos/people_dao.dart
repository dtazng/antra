import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:antra/database/app_database.dart';

part 'people_dao.g.dart';

const _uuid = Uuid();

/// Sort options for the people list.
enum PeopleSort { lastInteraction, nameAZ, recentlyCreated }

/// Aggregated interaction counts for a person's detail screen summary card.
class InteractionSummary {
  final int total;
  final int last30Days;
  final int last90Days;

  /// Per-type counts, e.g. `{'note': 12, 'task': 5, 'event': 3}`.
  final Map<String, int> byType;

  const InteractionSummary({
    required this.total,
    required this.last30Days,
    required this.last90Days,
    required this.byType,
  });

  static const empty = InteractionSummary(
    total: 0,
    last30Days: 0,
    last90Days: 0,
    byType: {},
  );
}

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

  /// Watches a single person by id. Emits null when deleted or not found.
  Stream<PeopleData?> watchPersonById(String id) {
    return (select(people)
          ..where((t) => t.id.equals(id) & t.isDeleted.equals(0)))
        .watchSingleOrNull();
  }

  /// Returns a person by exact case-insensitive name, or null.
  Future<PeopleData?> getPersonByName(String name) {
    return (select(people)
          ..where((t) => t.name.lower().equals(name.toLowerCase()))
          ..where((t) => t.isDeleted.equals(0)))
        .getSingleOrNull();
  }

  /// Searches people using FTS5 on name/notes/company.
  /// Empty [query] returns all non-deleted people ordered by lastInteractionAt DESC.
  Future<List<PeopleData>> searchPeople(String query) async {
    if (query.trim().isEmpty) {
      return (select(people)
            ..where((t) => t.isDeleted.equals(0))
            ..orderBy([(t) => OrderingTerm.desc(t.lastInteractionAt)]))
          .get();
    }

    // Sanitize: remove FTS5 special chars, then append * for prefix match.
    final sanitized = query.trim().replaceAll(RegExp(r'["\-*]'), '') + '*';
    final rows = await customSelect(
      '''
      SELECT p.*
      FROM people p
      JOIN people_fts ON p.rowid = people_fts.rowid
      WHERE people_fts MATCH ?
        AND p.is_deleted = 0
      ORDER BY p.last_interaction_at DESC
      ''',
      variables: [Variable.withString(sanitized)],
      readsFrom: {people},
    ).get();
    return rows.map((row) => people.map(row.data)).toList();
  }

  /// Returns up to 5 people whose name is similar to [name].
  /// Combines LIKE on first name token, sorted with exact match first.
  Future<List<PeopleData>> findSimilarPeople(String name) async {
    if (name.trim().isEmpty) return [];

    final lowerName = name.trim().toLowerCase();
    final firstToken = lowerName.split(' ').first;

    final results = await (select(people)
          ..where(
            (t) => t.isDeleted.equals(0) & t.name.lower().like('%$firstToken%'),
          )
          ..limit(10))
        .get();

    // Sort: exact match first, then starts-with, then contains.
    results.sort((a, b) {
      final aName = a.name.toLowerCase();
      final bName = b.name.toLowerCase();
      if (aName == lowerName) return -1;
      if (bName == lowerName) return 1;
      final aStarts = aName.startsWith(lowerName) ? 0 : 1;
      final bStarts = bName.startsWith(lowerName) ? 0 : 1;
      return aStarts - bStarts;
    });

    return results.take(5).toList();
  }

  /// Watches people sorted by [sort] with optional follow-up filter.
  Stream<List<PeopleData>> watchPeopleSorted(
    PeopleSort sort, {
    bool needsFollowUpOnly = false,
  }) {
    final query = select(people)
      ..where((t) {
        final notDeleted = t.isDeleted.equals(0);
        if (needsFollowUpOnly) {
          return notDeleted & t.needsFollowUp.equals(1);
        }
        return notDeleted;
      });

    switch (sort) {
      case PeopleSort.nameAZ:
        query.orderBy([(t) => OrderingTerm.asc(t.name)]);
      case PeopleSort.recentlyCreated:
        query.orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
      case PeopleSort.lastInteraction:
        query.orderBy([
          (t) => OrderingTerm(
                expression: t.lastInteractionAt,
                mode: OrderingMode.desc,
                nulls: NullsOrder.last,
              ),
        ]);
    }

    return query.watch();
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

  /// Soft-deletes a person, cascades to all their links, and enqueues a delete sync.
  Future<void> softDeletePerson(String id) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await transaction(() async {
      await (update(people)..where((t) => t.id.equals(id))).write(
        PeopleCompanion(
          isDeleted: const Value(1),
          updatedAt: Value(now),
        ),
      );
      // Cascade: soft-delete all links for this person (FR-004).
      await softDeleteLinksForPerson(id);
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

  /// Sets or clears the follow-up flag and optional date for a person.
  Future<void> setFollowUp(
    String personId, {
    required bool needs,
    String? followUpDate,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await transaction(() async {
      await (update(people)..where((t) => t.id.equals(personId))).write(
        PeopleCompanion(
          needsFollowUp: Value(needs ? 1 : 0),
          followUpDate: Value(needs ? followUpDate : null),
          updatedAt: Value(now),
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

  /// Inserts a bullet–person link, clears needsFollowUp, updates lastInteractionAt,
  /// and enqueues a create sync.
  Future<void> insertLink(
    String bulletId,
    String personId, {
    String linkType = 'mention',
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await transaction(() async {
      await into(bulletPersonLinks).insertOnConflictUpdate(
        BulletPersonLinksCompanion.insert(
          bulletId: bulletId,
          personId: personId,
          createdAt: now,
          linkType: Value(linkType),
          deviceId: 'local',
        ),
      );
      // Auto-clear follow-up flag when a new interaction is logged (FR-026).
      await (update(people)..where((t) => t.id.equals(personId))).write(
        PeopleCompanion(
          needsFollowUp: const Value(0),
          lastInteractionAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await _enqueueSync('bullet_person_link', '$bulletId:$personId', 'create', {
        'bulletId': bulletId,
        'personId': personId,
        'createdAt': now,
        'linkType': linkType,
      });
    });
  }

  /// Soft-deletes the specific (bulletId, personId) link and enqueues a delete sync.
  Future<void> removeLink(String bulletId, String personId) async {
    await transaction(() async {
      await (update(bulletPersonLinks)
            ..where(
              (t) => t.bulletId.equals(bulletId) & t.personId.equals(personId),
            ))
          .write(const BulletPersonLinksCompanion(isDeleted: Value(1)));
      await _enqueueSync(
        'bullet_person_link',
        '$bulletId:$personId',
        'delete',
        {'bulletId': bulletId, 'personId': personId},
      );
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

  /// Soft-deletes all bullet_person_links for a given person (called on person delete).
  Future<void> softDeleteLinksForPerson(String personId) async {
    await (update(bulletPersonLinks)
          ..where((t) => t.personId.equals(personId)))
        .write(const BulletPersonLinksCompanion(isDeleted: Value(1)));
  }

  /// Returns the first non-deleted linked person for a bullet, or null.
  Future<PeopleData?> getLinkedPersonForBullet(String bulletId) async {
    final query = select(bulletPersonLinks).join([
      innerJoin(people, people.id.equalsExp(bulletPersonLinks.personId)),
    ])
      ..where(bulletPersonLinks.bulletId.equals(bulletId) &
          bulletPersonLinks.isDeleted.equals(0) &
          people.isDeleted.equals(0))
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row?.readTable(people);
  }

  /// Returns all non-deleted linked people for a bullet, ordered by link_type
  /// then person name. Replaces [getLinkedPersonForBullet] where full list is needed.
  Future<List<PeopleData>> getLinkedPeopleForBullet(String bulletId) async {
    final query = select(bulletPersonLinks).join([
      innerJoin(people, people.id.equalsExp(bulletPersonLinks.personId)),
    ])
      ..where(bulletPersonLinks.bulletId.equals(bulletId) &
          bulletPersonLinks.isDeleted.equals(0) &
          people.isDeleted.equals(0))
      ..orderBy([
        OrderingTerm.asc(bulletPersonLinks.linkType),
        OrderingTerm.asc(people.name),
      ]);
    final rows = await query.get();
    return rows.map((row) => row.readTable(people)).toList();
  }

  // ---------------------------------------------------------------------------
  // Person Detail View — aggregation, pagination, pinning (v4)
  // ---------------------------------------------------------------------------

  /// Returns aggregated interaction counts for a person.
  /// One SQL round-trip using COUNT(CASE WHEN ...) expressions.
  Future<InteractionSummary> getInteractionSummary(String personId) async {
    final now = DateTime.now().toUtc();
    final cutoff30 = now.subtract(const Duration(days: 30)).toIso8601String();
    final cutoff90 = now.subtract(const Duration(days: 90)).toIso8601String();

    final rows = await customSelect(
      '''
      SELECT
        COUNT(*) AS total,
        COUNT(CASE WHEN b.created_at >= ? THEN 1 END) AS last_30,
        COUNT(CASE WHEN b.created_at >= ? THEN 1 END) AS last_90,
        COUNT(CASE WHEN b.type = 'note'  THEN 1 END) AS type_note,
        COUNT(CASE WHEN b.type = 'task'  THEN 1 END) AS type_task,
        COUNT(CASE WHEN b.type = 'event' THEN 1 END) AS type_event
      FROM bullet_person_links bpl
      JOIN bullets b ON b.id = bpl.bullet_id
      WHERE bpl.person_id = ?
        AND bpl.is_deleted = 0
        AND b.is_deleted = 0
      ''',
      variables: [
        Variable.withString(cutoff30),
        Variable.withString(cutoff90),
        Variable.withString(personId),
      ],
      readsFrom: {bulletPersonLinks, bullets},
    ).get();

    if (rows.isEmpty) return InteractionSummary.empty;
    final row = rows.first.data;
    final total = (row['total'] as int?) ?? 0;
    if (total == 0) return InteractionSummary.empty;

    final byType = <String, int>{};
    final noteCount = (row['type_note'] as int?) ?? 0;
    final taskCount = (row['type_task'] as int?) ?? 0;
    final eventCount = (row['type_event'] as int?) ?? 0;
    if (noteCount > 0) byType['note'] = noteCount;
    if (taskCount > 0) byType['task'] = taskCount;
    if (eventCount > 0) byType['event'] = eventCount;

    return InteractionSummary(
      total: total,
      last30Days: (row['last_30'] as int?) ?? 0,
      last90Days: (row['last_90'] as int?) ?? 0,
      byType: byType,
    );
  }

  /// Returns up to [limit] most recent non-deleted bullets linked to [personId].
  Future<List<Bullet>> getRecentBulletsForPerson(
    String personId, {
    int limit = 10,
  }) async {
    final rows = await customSelect(
      '''
      SELECT b.*
      FROM bullet_person_links bpl
      JOIN bullets b ON b.id = bpl.bullet_id
      WHERE bpl.person_id = ?
        AND bpl.is_deleted = 0
        AND b.is_deleted = 0
      ORDER BY b.created_at DESC
      LIMIT ?
      ''',
      variables: [
        Variable.withString(personId),
        Variable.withInt(limit),
      ],
      readsFrom: {bulletPersonLinks, bullets},
    ).get();
    return rows.map((row) => bullets.map(row.data)).toList();
  }

  /// Returns one page of bullets for the full activity timeline.
  Future<List<Bullet>> getBulletsForPersonPaged(
    String personId, {
    String? typeFilter,
    required int limit,
    required int offset,
  }) async {
    final typeClause = typeFilter != null ? 'AND b.type = ?' : '';
    final variables = [
      Variable.withString(personId),
      if (typeFilter != null) Variable.withString(typeFilter),
      Variable.withInt(limit),
      Variable.withInt(offset),
    ];
    final rows = await customSelect(
      '''
      SELECT b.*
      FROM bullet_person_links bpl
      JOIN bullets b ON b.id = bpl.bullet_id
      WHERE bpl.person_id = ?
        AND bpl.is_deleted = 0
        AND b.is_deleted = 0
        $typeClause
      ORDER BY b.created_at DESC
      LIMIT ? OFFSET ?
      ''',
      variables: variables,
      readsFrom: {bulletPersonLinks, bullets},
    ).get();
    return rows.map((row) => bullets.map(row.data)).toList();
  }

  /// Returns all pinned notes for [personId], ordered oldest-pin-first.
  Future<List<Bullet>> getPinnedBulletsForPerson(String personId) async {
    final rows = await customSelect(
      '''
      SELECT b.*
      FROM bullet_person_links bpl
      JOIN bullets b ON b.id = bpl.bullet_id
      WHERE bpl.person_id = ?
        AND bpl.is_pinned = 1
        AND bpl.is_deleted = 0
        AND b.is_deleted = 0
        AND b.type = 'note'
      ORDER BY bpl.created_at ASC
      ''',
      variables: [Variable.withString(personId)],
      readsFrom: {bulletPersonLinks, bullets},
    ).get();
    return rows.map((row) => bullets.map(row.data)).toList();
  }

  /// Sets or clears the [isPinned] flag on a specific bullet–person link.
  Future<void> setPinned(
    String bulletId,
    String personId, {
    required bool pinned,
  }) async {
    await (update(bulletPersonLinks)
          ..where(
            (t) => t.bulletId.equals(bulletId) & t.personId.equals(personId),
          ))
        .write(BulletPersonLinksCompanion(isPinned: Value(pinned ? 1 : 0)));
    await _enqueueSync('bullet_person_link', '$bulletId:$personId', 'update', {
      'bulletId': bulletId,
      'personId': personId,
      'isPinned': pinned ? 1 : 0,
    });
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
      'name': companion.name.present ? companion.name.value : null,
      'notes': companion.notes.present ? companion.notes.value : null,
      'reminderCadenceDays': companion.reminderCadenceDays.present
          ? companion.reminderCadenceDays.value
          : null,
      'company': companion.company.present ? companion.company.value : null,
      'role': companion.role.present ? companion.role.value : null,
      'email': companion.email.present ? companion.email.value : null,
      'phone': companion.phone.present ? companion.phone.value : null,
      'birthday': companion.birthday.present ? companion.birthday.value : null,
      'location': companion.location.present ? companion.location.value : null,
      'tags': companion.tags.present ? companion.tags.value : null,
      'relationshipType': companion.relationshipType.present
          ? companion.relationshipType.value
          : null,
      'needsFollowUp':
          companion.needsFollowUp.present ? companion.needsFollowUp.value : null,
      'followUpDate':
          companion.followUpDate.present ? companion.followUpDate.value : null,
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
      'company': row.company,
      'role': row.role,
      'email': row.email,
      'phone': row.phone,
      'birthday': row.birthday,
      'location': row.location,
      'tags': row.tags,
      'relationshipType': row.relationshipType,
      'needsFollowUp': row.needsFollowUp,
      'followUpDate': row.followUpDate,
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
