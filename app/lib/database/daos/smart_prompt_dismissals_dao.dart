import 'package:drift/drift.dart';

import 'package:antra/database/app_database.dart';

part 'smart_prompt_dismissals_dao.g.dart';

@DriftAccessor(tables: [SmartPromptDismissals])
class SmartPromptDismissalsDao extends DatabaseAccessor<AppDatabase>
    with _$SmartPromptDismissalsDaoMixin {
  SmartPromptDismissalsDao(super.db);

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  /// Returns the active (not yet expired) dismissal for a given person + prompt
  /// type combination, or null if none exists.
  Future<SmartPromptDismissal?> getActiveDismissal({
    required String personId,
    required String promptType,
    String? importantDateId,
  }) async {
    final today = _todayString();
    final q = select(smartPromptDismissals)
      ..where((t) =>
          t.personId.equals(personId) &
          t.promptType.equals(promptType) &
          t.dismissedUntil.isBiggerOrEqualValue(today));
    if (importantDateId != null) {
      q.where((t) => t.importantDateId.equals(importantDateId));
    }
    return q.getSingleOrNull();
  }

  /// Returns true if the prompt for [personId] + [promptType] is currently
  /// suppressed (dismissedUntil is today or future).
  Future<bool> isDismissed({
    required String? personId,
    required String promptType,
    String? importantDateId,
  }) async {
    final today = _todayString();
    var q = select(smartPromptDismissals)
      ..where((t) =>
          t.promptType.equals(promptType) &
          t.dismissedUntil.isBiggerOrEqualValue(today));
    if (personId != null) {
      q = q..where((t) => t.personId.equals(personId));
    }
    if (importantDateId != null) {
      q = q..where((t) => t.importantDateId.equals(importantDateId));
    }
    final result = await q.getSingleOrNull();
    return result != null;
  }

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  /// Inserts a new dismissal record.
  Future<void> insert({
    required String promptType,
    String? personId,
    String? importantDateId,
    required String dismissedUntil,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await into(smartPromptDismissals).insert(
      SmartPromptDismissalsCompanion.insert(
        personId: Value(personId),
        promptType: promptType,
        importantDateId: Value(importantDateId),
        dismissedUntil: dismissedUntil,
        createdAt: now,
      ),
    );
  }

  /// Removes all dismissal rows that have already expired (dismissedUntil < today).
  Future<void> deleteExpired() async {
    final today = _todayString();
    await (delete(smartPromptDismissals)
          ..where((t) => t.dismissedUntil.isSmallerThanValue(today)))
        .go();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static String _todayString() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}
