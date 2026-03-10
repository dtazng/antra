import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:antra/database/app_database.dart';

part 'bullets_dao.g.dart';

const _uuid = Uuid();

@DriftAccessor(
  tables: [DayLogs, Bullets, Tags, BulletTagLinks, BulletPersonLinks, PendingSync],
)
class BulletsDao extends DatabaseAccessor<AppDatabase> with _$BulletsDaoMixin {
  BulletsDao(super.db);

  // ---------------------------------------------------------------------------
  // DayLog helpers
  // ---------------------------------------------------------------------------

  /// Returns the [DayLog] for [date] (YYYY-MM-DD), creating it if absent.
  Future<DayLog> getOrCreateDayLog(String date) async {
    final existing = await (select(dayLogs)
          ..where((t) => t.date.equals(date)))
        .getSingleOrNull();
    if (existing != null) return existing;

    final now = DateTime.now().toUtc().toIso8601String();
    final id = _uuid.v4();
    await into(dayLogs).insert(
      DayLogsCompanion.insert(
        id: id,
        date: date,
        createdAt: now,
        updatedAt: now,
        deviceId: _deviceId,
      ),
    );
    return (select(dayLogs)..where((t) => t.date.equals(date))).getSingle();
  }

  // ---------------------------------------------------------------------------
  // Bullet CRUD
  // ---------------------------------------------------------------------------

  /// Watches all non-deleted bullets for a given [dayId], ordered by position.
  Stream<List<Bullet>> watchBulletsForDay(String dayId) {
    return (select(bullets)
          ..where((t) => t.dayId.equals(dayId) & t.isDeleted.equals(0))
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .watch();
  }

  /// Inserts a bullet and enqueues a pending sync row — all in one transaction.
  Future<void> insertBullet(BulletsCompanion companion) async {
    await transaction(() async {
      await into(bullets).insert(companion);
      await _enqueueBulletSync(companion.id.value, 'create', companion);
    });
  }

  /// Updates the status of a bullet and enqueues a sync.
  Future<void> updateBulletStatus(String id, String status) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await transaction(() async {
      await (update(bullets)..where((t) => t.id.equals(id))).write(
        BulletsCompanion(
          status: Value(status),
          updatedAt: Value(now),
        ),
      );
      final updated = await _getBullet(id);
      if (updated != null) {
        await _enqueueBulletSyncFromRow(updated, 'update');
      }
    });
  }

  /// Updates the content of a bullet and enqueues a sync.
  Future<void> updateBulletContent(String id, String content) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await transaction(() async {
      await (update(bullets)..where((t) => t.id.equals(id))).write(
        BulletsCompanion(
          content: Value(content),
          updatedAt: Value(now),
        ),
      );
      final updated = await _getBullet(id);
      if (updated != null) {
        await _enqueueBulletSyncFromRow(updated, 'update');
      }
    });
  }

  /// Soft-deletes a bullet (sets isDeleted=1) and enqueues a delete sync.
  Future<void> softDeleteBullet(String id) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await transaction(() async {
      await (update(bullets)..where((t) => t.id.equals(id))).write(
        BulletsCompanion(
          isDeleted: const Value(1),
          updatedAt: Value(now),
        ),
      );
      await _enqueueSync('bullet', id, 'delete', {'id': id});
    });
  }

  // ---------------------------------------------------------------------------
  // Tag parsing (inline #tag support)
  // ---------------------------------------------------------------------------

  /// Parses #hashtags from [content], upserts each tag (lowercase),
  /// and inserts bullet_tag_links rows — all in a single transaction.
  Future<void> insertBulletWithTags(
    BulletsCompanion companion,
    String content,
  ) async {
    final tagNames = _extractHashtags(content);
    await transaction(() async {
      await into(bullets).insert(companion);
      for (final name in tagNames) {
        final tagId = await _upsertTag(name);
        await _insertTagLink(companion.id.value, tagId);
      }
      await _enqueueBulletSync(companion.id.value, 'create', companion);
    });
  }

  // ---------------------------------------------------------------------------
  // FTS5 search (US3)
  // ---------------------------------------------------------------------------

  static const _bulletCols =
      'b.id, b.day_id, b.type, b.content, b.status, b.position, '
      'b.migrated_to_id, b.encryption_enabled, b.created_at, b.updated_at, '
      'b.sync_id, b.device_id, b.is_deleted, '
      'b.scheduled_date, b.carry_over_count, b.completed_at, b.canceled_at';

  /// Full-text search across bullet content using the bullets_fts FTS5 index.
  /// Returns all non-deleted bullets whose content matches [query].
  Stream<List<Bullet>> searchBullets(String query) {
    if (query.trim().isEmpty) return Stream.value([]);
    final ftsQuery = '${query.replaceAll('"', '').trim()}*';
    return customSelect(
      'SELECT $_bulletCols FROM bullets b '
      'INNER JOIN bullets_fts ON bullets_fts.rowid = b.rowid '
      'WHERE bullets_fts MATCH ? AND b.is_deleted = 0 '
      'ORDER BY b.updated_at DESC',
      variables: [Variable(ftsQuery)],
      readsFrom: {bullets},
    ).watch().map((rows) => rows.map(_mapRowToBullet).toList());
  }

  /// Filters bullets linked to [tagName] via bullet_tag_links.
  Stream<List<Bullet>> filterByTag(String tagName) {
    return customSelect(
      'SELECT $_bulletCols FROM bullets b '
      'INNER JOIN bullet_tag_links btl ON btl.bullet_id = b.id '
      'INNER JOIN tags t ON t.id = btl.tag_id '
      'WHERE t.name = ? AND b.is_deleted = 0 AND btl.is_deleted = 0 '
      'ORDER BY b.updated_at DESC',
      variables: [Variable(tagName.toLowerCase())],
      readsFrom: {bullets, bulletTagLinks, tags},
    ).watch().map((rows) => rows.map(_mapRowToBullet).toList());
  }

  /// Filters bullets linked to [personId] via bullet_person_links.
  Stream<List<Bullet>> filterByPerson(String personId) {
    return customSelect(
      'SELECT $_bulletCols FROM bullets b '
      'INNER JOIN bullet_person_links bpl ON bpl.bullet_id = b.id '
      'WHERE bpl.person_id = ? AND b.is_deleted = 0 AND bpl.is_deleted = 0 '
      'ORDER BY b.updated_at DESC',
      variables: [Variable(personId)],
      readsFrom: {bullets, bulletPersonLinks},
    ).watch().map((rows) => rows.map(_mapRowToBullet).toList());
  }

  /// Filters bullets whose parent day_log.date falls within [from]..[to] (inclusive).
  Stream<List<Bullet>> filterByDateRange(String from, String to) {
    return customSelect(
      'SELECT $_bulletCols FROM bullets b '
      'INNER JOIN day_logs dl ON dl.id = b.day_id '
      'WHERE dl.date BETWEEN ? AND ? AND b.is_deleted = 0 '
      'ORDER BY dl.date DESC, b.position ASC',
      variables: [Variable(from), Variable(to)],
      readsFrom: {bullets, dayLogs},
    ).watch().map((rows) => rows.map(_mapRowToBullet).toList());
  }

  // ---------------------------------------------------------------------------
  // Review helpers (US5)
  // ---------------------------------------------------------------------------

  /// Returns open tasks (type=task, status=open) within the given date range.
  Future<List<Bullet>> getOpenTasksForPeriod(String from, String to) {
    return customSelect(
      'SELECT $_bulletCols FROM bullets b '
      'INNER JOIN day_logs dl ON dl.id = b.day_id '
      "WHERE b.type = 'task' AND b.status = 'open' "
      'AND dl.date BETWEEN ? AND ? AND b.is_deleted = 0 '
      'ORDER BY dl.date ASC, b.position ASC',
      variables: [Variable(from), Variable(to)],
      readsFrom: {bullets, dayLogs},
    ).get().then((rows) => rows.map(_mapRowToBullet).toList());
  }

  /// Returns events (type=event) within the given date range.
  Future<List<Bullet>> getEventsForPeriod(String from, String to) {
    return customSelect(
      'SELECT $_bulletCols FROM bullets b '
      'INNER JOIN day_logs dl ON dl.id = b.day_id '
      "WHERE b.type = 'event' "
      'AND dl.date BETWEEN ? AND ? AND b.is_deleted = 0 '
      'ORDER BY dl.date ASC, b.position ASC',
      variables: [Variable(from), Variable(to)],
      readsFrom: {bullets, dayLogs},
    ).get().then((rows) => rows.map(_mapRowToBullet).toList());
  }

  /// Migrates a task bullet: sets source to status=migrated, creates a new
  /// open task in today's log. Returns the new bullet's ID.
  @Deprecated(
    'Use TaskLifecycleService.keepForToday() instead. '
    'Legacy migrated rows created by this method are still readable.',
  )
  Future<String> migrateBullet(String bulletId, String todayDate) async {
    final source = await _getBullet(bulletId);
    if (source == null) throw StateError('Bullet $bulletId not found');

    final todayLog = await getOrCreateDayLog(todayDate);
    final now = DateTime.now().toUtc().toIso8601String();
    final newId = _uuid.v4();

    await transaction(() async {
      // Mark source as migrated.
      await (update(bullets)..where((t) => t.id.equals(bulletId))).write(
        BulletsCompanion(
          status: const Value('migrated'),
          migratedToId: Value(newId),
          updatedAt: Value(now),
        ),
      );
      await _enqueueBulletSyncFromRow(source.copyWith(status: 'migrated'), 'update');

      // Insert migrated copy in today's log.
      final companion = BulletsCompanion.insert(
        id: newId,
        dayId: todayLog.id,
        type: Value(source.type),
        content: source.content,
        status: const Value('open'),
        position: 0,
        createdAt: now,
        updatedAt: now,
        deviceId: _deviceId,
      );
      await into(bullets).insert(companion);
      await _enqueueBulletSync(newId, 'create', companion);
    });
    return newId;
  }

  /// Returns the [DayLog] for a given [dayId] UUID, or null if not found.
  Future<DayLog?> getDayLogById(String dayId) =>
      (select(dayLogs)..where((t) => t.id.equals(dayId))).getSingleOrNull();

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Bullet _mapRowToBullet(QueryRow row) => Bullet(
        id: row.read<String>('id'),
        dayId: row.read<String>('day_id'),
        type: row.read<String>('type'),
        content: row.read<String>('content'),
        status: row.read<String>('status'),
        position: row.read<int>('position'),
        migratedToId: row.readNullable<String>('migrated_to_id'),
        encryptionEnabled: row.read<int>('encryption_enabled'),
        createdAt: row.read<String>('created_at'),
        updatedAt: row.read<String>('updated_at'),
        syncId: row.readNullable<String>('sync_id'),
        deviceId: row.read<String>('device_id'),
        isDeleted: row.read<int>('is_deleted'),
        scheduledDate: row.readNullable<String>('scheduled_date'),
        carryOverCount: row.read<int>('carry_over_count'),
        completedAt: row.readNullable<String>('completed_at'),
        canceledAt: row.readNullable<String>('canceled_at'),
      );

  Future<Bullet?> _getBullet(String id) =>
      (select(bullets)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> _enqueueBulletSync(
    String id,
    String operation,
    BulletsCompanion companion,
  ) async {
    final payload = {
      'id': id,
      'dayId': companion.dayId.value,
      'type': companion.type.value,
      'content': companion.content.value,
      'status': companion.status.value,
      'position': companion.position.value,
      'createdAt': companion.createdAt.value,
      'updatedAt': companion.updatedAt.value,
      'deviceId': companion.deviceId.value,
    };
    await _enqueueSync('bullet', id, operation, payload);
  }

  Future<void> _enqueueBulletSyncFromRow(Bullet row, String operation) async {
    final payload = {
      'id': row.id,
      'dayId': row.dayId,
      'type': row.type,
      'content': row.content,
      'status': row.status,
      'position': row.position,
      'createdAt': row.createdAt,
      'updatedAt': row.updatedAt,
      'deviceId': row.deviceId,
    };
    await _enqueueSync('bullet', row.id, operation, payload);
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

  /// Upserts a tag by lowercase [name] and returns its ID.
  Future<String> _upsertTag(String name) async {
    final lower = name.toLowerCase();
    final existing = await (select(tags)
          ..where((t) => t.name.equals(lower)))
        .getSingleOrNull();
    if (existing != null) return existing.id;

    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await into(tags).insert(
      TagsCompanion.insert(
        id: id,
        name: lower,
        createdAt: now,
        deviceId: _deviceId,
      ),
    );
    return id;
  }

  Future<void> _insertTagLink(String bulletId, String tagId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await into(bulletTagLinks).insertOnConflictUpdate(
      BulletTagLinksCompanion.insert(
        bulletId: bulletId,
        tagId: tagId,
        createdAt: now,
        deviceId: _deviceId,
      ),
    );
  }

  /// Extracts lowercase hashtag names from [content] (e.g. "#work" → "work").
  List<String> _extractHashtags(String content) {
    final regex = RegExp(r'#(\w+)');
    return regex
        .allMatches(content)
        .map((m) => m.group(1)!.toLowerCase())
        .toSet()
        .toList();
  }

  /// Stable device identifier sourced from AppConfig in production.
  /// Injected via constructor in tests.
  String get _deviceId => 'local';
}
