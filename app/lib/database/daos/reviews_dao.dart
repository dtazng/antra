import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:antra/database/app_database.dart';

part 'reviews_dao.g.dart';

const _uuid = Uuid();

@DriftAccessor(tables: [Reviews, PendingSync])
class ReviewsDao extends DatabaseAccessor<AppDatabase> with _$ReviewsDaoMixin {
  ReviewsDao(super.db);

  /// Watches all non-deleted reviews, newest first.
  Stream<List<Review>> watchReviews() {
    return (select(reviews)
          ..where((t) => t.isDeleted.equals(0))
          ..orderBy([(t) => OrderingTerm.desc(t.startDate)]))
        .watch();
  }

  /// Inserts a new review and enqueues a create sync.
  Future<void> insertReview(ReviewsCompanion companion) async {
    await transaction(() async {
      await into(reviews).insert(companion);
      await _enqueueSync(companion.id.value, 'create', companion);
    });
  }

  /// Returns the review for the given period, creating one if it doesn't exist.
  Future<Review> getOrCreateReview(
    String periodType,
    String startDate,
    String endDate,
  ) async {
    final existing = await (select(reviews)
          ..where((t) =>
              t.periodType.equals(periodType) &
              t.startDate.equals(startDate) &
              t.isDeleted.equals(0)))
        .getSingleOrNull();
    if (existing != null) return existing;

    final now = DateTime.now().toUtc().toIso8601String();
    final id = _uuid.v4();
    final companion = ReviewsCompanion.insert(
      id: id,
      periodType: periodType,
      startDate: startDate,
      endDate: endDate,
      createdAt: now,
      updatedAt: now,
      deviceId: 'local',
    );
    await insertReview(companion);
    return (select(reviews)..where((t) => t.id.equals(id))).getSingle();
  }

  /// Updates summary notes for a review and enqueues a sync.
  Future<void> updateSummaryNotes(String id, String notes) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await transaction(() async {
      await (update(reviews)..where((t) => t.id.equals(id))).write(
        ReviewsCompanion(
          summaryNotes: Value(notes),
          updatedAt: Value(now),
        ),
      );
      final updated = await _getReview(id);
      if (updated != null) {
        await _enqueueSyncFromRow(updated, 'update');
      }
    });
  }

  /// Marks a review as complete with an optional summary notes update.
  Future<void> markComplete(String id, {String? summaryNotes}) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await transaction(() async {
      await (update(reviews)..where((t) => t.id.equals(id))).write(
        ReviewsCompanion(
          completedAt: Value(now),
          summaryNotes: summaryNotes != null ? Value(summaryNotes) : const Value.absent(),
          updatedAt: Value(now),
        ),
      );
      final updated = await _getReview(id);
      if (updated != null) {
        await _enqueueSyncFromRow(updated, 'update');
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<Review?> _getReview(String id) =>
      (select(reviews)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> _enqueueSync(
    String id,
    String operation,
    ReviewsCompanion companion,
  ) async {
    final payload = {
      'id': id,
      'periodType': companion.periodType.value,
      'startDate': companion.startDate.value,
      'endDate': companion.endDate.value,
      'summaryNotes':
          companion.summaryNotes.present ? companion.summaryNotes.value : null,
      'completedAt':
          companion.completedAt.present ? companion.completedAt.value : null,
      'createdAt': companion.createdAt.present ? companion.createdAt.value : null,
      'updatedAt': companion.updatedAt.present ? companion.updatedAt.value : null,
      'deviceId': companion.deviceId.present ? companion.deviceId.value : null,
    };
    await _enqueueSyncRaw('review', id, operation, payload);
  }

  Future<void> _enqueueSyncFromRow(Review row, String operation) async {
    final payload = {
      'id': row.id,
      'periodType': row.periodType,
      'startDate': row.startDate,
      'endDate': row.endDate,
      'summaryNotes': row.summaryNotes,
      'completedAt': row.completedAt,
      'createdAt': row.createdAt,
      'updatedAt': row.updatedAt,
      'deviceId': row.deviceId,
    };
    await _enqueueSyncRaw('review', row.id, operation, payload);
  }

  Future<void> _enqueueSyncRaw(
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
