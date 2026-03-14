import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:antra/database/daos/bullets_dao.dart';
import 'package:antra/database/daos/people_dao.dart';
import 'package:antra/models/needs_attention_item.dart';
import 'package:antra/providers/database_provider.dart';

part 'needs_attention_provider.g.dart';

String _todayStr() => DateFormat('yyyy-MM-dd').format(DateTime.now());

/// Streams the list of due follow-up suggestions.
///
/// Watches bullets where:
///   - follow_up_status = 'pending' AND follow_up_date <= today
///   - OR follow_up_status = 'snoozed' AND follow_up_snoozed_until <= today
///
/// Exposes [markDone], [snooze], and [dismiss] mutations.
@riverpod
class NeedsAttentionItems extends _$NeedsAttentionItems {
  @override
  Stream<List<NeedsAttentionItem>> build() async* {
    final db = await ref.watch(appDatabaseProvider.future);
    final bulletsDao = BulletsDao(db);
    final peopleDao = PeopleDao(db);
    final today = _todayStr();

    await for (final rawBullets in bulletsDao.watchPendingFollowUps(today)) {
      final items = <NeedsAttentionItem>[];
      for (final bullet in rawBullets) {
        final person = await peopleDao.getLinkedPersonForBullet(bullet.id);
        items.add(NeedsAttentionItem(
          bulletId: bullet.id,
          content: bullet.content,
          followUpDate: bullet.followUpDate ?? today,
          followUpStatus: bullet.followUpStatus ?? 'pending',
          personId: person?.id,
          personName: person?.name,
        ));
      }
      yield items;
    }
  }

  /// Marks the follow-up as done and inserts a completion_event bullet.
  Future<void> markDone(String bulletId) async {
    final db = await ref.read(appDatabaseProvider.future);
    final bulletsDao = BulletsDao(db);
    final peopleDao = PeopleDao(db);

    final person = await peopleDao.getLinkedPersonForBullet(bulletId);
    final content = person != null
        ? 'Followed up with ${person.name}'
        : 'Completed follow-up';

    final today = _todayStr();
    await bulletsDao.insertCompletionEvent(
      sourceId: bulletId,
      content: content,
      dayId: today,
    );
  }

  /// Snoozes the follow-up for 7 days.
  Future<void> snooze(String bulletId) async {
    final db = await ref.read(appDatabaseProvider.future);
    final bulletsDao = BulletsDao(db);
    final snoozedUntil = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().add(const Duration(days: 7)));
    await bulletsDao.updateFollowUpStatus(
      bulletId,
      'snoozed',
      snoozedUntil: snoozedUntil,
    );
  }

  /// Dismisses the follow-up permanently.
  Future<void> dismiss(String bulletId) async {
    final db = await ref.read(appDatabaseProvider.future);
    final bulletsDao = BulletsDao(db);
    await bulletsDao.updateFollowUpStatus(bulletId, 'dismissed');
  }
}
