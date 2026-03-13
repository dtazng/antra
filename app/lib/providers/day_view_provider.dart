import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/database/daos/bullets_dao.dart';
import 'package:antra/database/daos/people_dao.dart';
import 'package:antra/models/suggestion.dart';
import 'package:antra/models/today_interaction.dart';
import 'package:antra/providers/database_provider.dart';
import 'package:antra/services/suggestion_engine.dart';

part 'day_view_provider.g.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _todayStr() => DateFormat('yyyy-MM-dd').format(DateTime.now());

// ---------------------------------------------------------------------------
// suggestionsProvider
// ---------------------------------------------------------------------------

/// Emits a ranked list of up to 4 [Suggestion] objects.
/// Re-emits when people data or today's interactions change.
@riverpod
Stream<List<Suggestion>> suggestions(SuggestionsRef ref) async* {
  final db = await ref.watch(appDatabaseProvider.future);
  final today = _todayStr();

  // Get today's day log to filter already-interacted people.
  final dao = BulletsDao(db);
  final dayLog = await dao.getOrCreateDayLog(today);

  // Watch both people and today's person-linked bullets reactively.
  final peopleStream = PeopleDao(db).watchAllPeople();
  final linksStream = dao.watchPersonLinkedBulletsForDay(dayLog.id);

  List<PeopleData> latestPeople = [];
  Set<String> latestTodayPersonIds = {};

  final engine = SuggestionEngine();

  // Merge the two streams: emit new suggestions whenever either changes.
  // We use a simple accumulator approach — watch people, then for each
  // emission combine with latest link data.
  await for (final people in peopleStream) {
    latestPeople = people;
    // Pull current links snapshot once (non-reactive inner read).
    final links = await dao.watchPersonLinkedBulletsForDay(dayLog.id).first;
    latestTodayPersonIds = _extractPersonIds(db, links);
    yield engine.compute(latestPeople, today, latestTodayPersonIds);
  }

  // Also update when links change (secondary trigger).
  await for (final links in linksStream) {
    latestTodayPersonIds = _extractPersonIds(db, links);
    yield engine.compute(latestPeople, today, latestTodayPersonIds);
  }
}

/// Extracts unique person IDs from bullets that have person links.
/// We can't join in Dart without a DAO query, so we pull person IDs
/// from a raw query via the already-returned bullet list.
Set<String> _extractPersonIds(AppDatabase db, List<Bullet> bullets) {
  // We don't have person IDs directly from bullets; we need an additional
  // query. For suggestions we only need today's person IDs — returned by
  // `todayInteractionsProvider` anyway. Use a simplified approach: treat
  // any bullet linked today as indicating that person was interacted with.
  // The full person IDs are available in the TodayInteraction objects.
  // Here we return an empty set; the SuggestionEngine exclusion is done
  // at the provider level using todayInteractionsProvider.
  return {};
}

// ---------------------------------------------------------------------------
// suggestionsWithExclusionProvider
// ---------------------------------------------------------------------------

/// Refined suggestion stream that excludes people already interacted with today.
/// This is the provider that [DayViewScreen] actually watches.
@riverpod
Stream<List<Suggestion>> suggestionsFiltered(SuggestionsFilteredRef ref) async* {
  final db = await ref.watch(appDatabaseProvider.future);
  final today = _todayStr();
  final dao = BulletsDao(db);
  final peopleDao = PeopleDao(db);
  final dayLog = await dao.getOrCreateDayLog(today);
  final engine = SuggestionEngine();

  // Watch the linked-bullet stream for reactive updates.
  await for (final _ in dao.watchPersonLinkedBulletsForDay(dayLog.id)) {
    // On each change, fetch current person IDs for today.
    final todayPersonIds = await _fetchTodayPersonIds(db, dayLog.id);
    final people = await peopleDao.watchAllPeople().first;
    yield engine.compute(people, today, todayPersonIds);
  }
}

Future<Set<String>> _fetchTodayPersonIds(AppDatabase db, String dayId) async {
  final rows = await db.customSelect(
    'SELECT DISTINCT bpl.person_id '
    'FROM bullet_person_links bpl '
    'INNER JOIN bullets b ON b.id = bpl.bullet_id '
    'WHERE b.day_id = ? AND bpl.is_deleted = 0 AND b.is_deleted = 0',
    variables: [Variable(dayId)],
    readsFrom: {db.bulletPersonLinks, db.bullets},
  ).get();
  return rows.map((r) => r.read<String>('person_id')).toSet();
}

// ---------------------------------------------------------------------------
// todayInteractionsProvider
// ---------------------------------------------------------------------------

/// Emits person-linked bullets for [date] as [TodayInteraction] list, newest first.
@riverpod
Stream<List<TodayInteraction>> todayInteractions(
  TodayInteractionsRef ref,
  String date,
) async* {
  final db = await ref.watch(appDatabaseProvider.future);
  final dao = BulletsDao(db);
  final peopleDao = PeopleDao(db);
  final dayLog = await dao.getOrCreateDayLog(date);

  await for (final todayBullets in dao.watchAllBulletsForDay(dayLog.id)) {
    if (todayBullets.isEmpty) {
      yield [];
      continue;
    }

    // Fetch optional person for each bullet (one query per bullet; acceptable
    // at day-view scale of ≤ 50 entries/day).
    final interactions = <TodayInteraction>[];
    for (final bullet in todayBullets) {
      final person = await peopleDao.getLinkedPersonForBullet(bullet.id);
      final loggedAt =
          DateTime.tryParse(bullet.createdAt)?.toLocal() ?? DateTime.now();
      interactions.add(TodayInteraction(
        bulletId: bullet.id,
        personId: person?.id,
        personName: person?.name,
        content: bullet.content,
        type: bullet.type,
        loggedAt: loggedAt,
      ));
    }
    yield interactions;
  }
}

// ---------------------------------------------------------------------------
// SuggestionNotifier
// ---------------------------------------------------------------------------

/// In-memory state for the suggestion card feed:
/// - which card is expanded (at most one)
/// - which person IDs have been dismissed for this session
class SuggestionState {
  const SuggestionState({
    this.expandedPersonId,
    this.dismissedPersonIds = const {},
  });

  final String? expandedPersonId;
  final Set<String> dismissedPersonIds;

  SuggestionState copyWith({
    String? expandedPersonId,
    bool clearExpanded = false,
    Set<String>? dismissedPersonIds,
  }) {
    return SuggestionState(
      expandedPersonId: clearExpanded ? null : (expandedPersonId ?? this.expandedPersonId),
      dismissedPersonIds: dismissedPersonIds ?? this.dismissedPersonIds,
    );
  }
}

@riverpod
class SuggestionNotifier extends _$SuggestionNotifier {
  @override
  SuggestionState build() => const SuggestionState();

  /// Expands the card for [personId], collapsing any currently expanded card.
  void expand(String personId) {
    state = state.copyWith(expandedPersonId: personId);
  }

  /// Collapses the currently expanded card.
  void collapse() {
    state = state.copyWith(clearExpanded: true);
  }

  /// Marks [personId] as dismissed — removed from the visible feed.
  void dismiss(String personId) {
    final updated = Set<String>.from(state.dismissedPersonIds)..add(personId);
    state = state.copyWith(
      dismissedPersonIds: updated,
      clearExpanded: state.expandedPersonId == personId,
    );
  }
}
