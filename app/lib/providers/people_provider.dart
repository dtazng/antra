import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/database/daos/people_dao.dart';
import 'package:antra/models/timeline_item.dart';
import 'package:antra/providers/database_provider.dart';

part 'people_provider.g.dart';

// ---------------------------------------------------------------------------
// Existing providers (unchanged)
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// New providers
// ---------------------------------------------------------------------------

/// Sorted (and optionally follow-up-filtered) people stream.
@riverpod
Stream<List<PeopleData>> peopleSorted(
  PeopleSortedRef ref,
  PeopleSort sort, {
  bool needsFollowUpOnly = false,
}) async* {
  final db = await ref.watch(appDatabaseProvider.future);
  yield* PeopleDao(db).watchPeopleSorted(sort, needsFollowUpOnly: needsFollowUpOnly);
}

/// Reactive single-person stream. Emits null when deleted/not found.
@riverpod
Stream<PeopleData?> singlePerson(
  SinglePersonRef ref,
  String personId,
) async* {
  final db = await ref.watch(appDatabaseProvider.future);
  yield* PeopleDao(db).watchPersonById(personId);
}

/// Returns the first linked person for a bullet, or null.
@riverpod
Future<PeopleData?> linkedPersonForBullet(
  LinkedPersonForBulletRef ref,
  String bulletId,
) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return PeopleDao(db).getLinkedPersonForBullet(bulletId);
}

// ---------------------------------------------------------------------------
// People screen state: sort + filter
// ---------------------------------------------------------------------------

/// Immutable state for the PeopleScreen filter/sort bar.
class PeopleScreenState {
  const PeopleScreenState({
    this.sort = PeopleSort.lastInteraction,
    this.searchQuery = '',
    this.relationshipType,
    this.tag,
    this.needsFollowUpOnly = false,
  });

  final PeopleSort sort;
  final String searchQuery;
  final String? relationshipType;
  final String? tag;
  final bool needsFollowUpOnly;

  PeopleScreenState copyWith({
    PeopleSort? sort,
    String? searchQuery,
    String? relationshipType,
    bool clearRelationshipType = false,
    String? tag,
    bool clearTag = false,
    bool? needsFollowUpOnly,
  }) {
    return PeopleScreenState(
      sort: sort ?? this.sort,
      searchQuery: searchQuery ?? this.searchQuery,
      relationshipType: clearRelationshipType ? null : (relationshipType ?? this.relationshipType),
      tag: clearTag ? null : (tag ?? this.tag),
      needsFollowUpOnly: needsFollowUpOnly ?? this.needsFollowUpOnly,
    );
  }
}

// ---------------------------------------------------------------------------
// Person Detail View providers (v4)
// ---------------------------------------------------------------------------

/// Aggregated interaction summary for the profile summary card.
@riverpod
Future<InteractionSummary> interactionSummary(
  InteractionSummaryRef ref,
  String personId,
) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return PeopleDao(db).getInteractionSummary(personId);
}

/// Up to 10 most recent bullets for the profile recent activity section.
@riverpod
Future<List<Bullet>> recentBulletsForPerson(
  RecentBulletsForPersonRef ref,
  String personId,
) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return PeopleDao(db).getRecentBulletsForPerson(personId);
}

/// All pinned notes for the profile pinned notes section.
@riverpod
Future<List<Bullet>> pinnedBulletsForPerson(
  PinnedBulletsForPersonRef ref,
  String personId,
) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return PeopleDao(db).getPinnedBulletsForPerson(personId);
}

/// Immutable state for the paginated full activity timeline.
class PersonTimelineState {
  const PersonTimelineState({
    this.items = const [],
    this.hasMore = true,
    this.isLoadingMore = false,
    this.typeFilter,
  });

  final List<TimelineItem> items;
  final bool hasMore;
  final bool isLoadingMore;
  final String? typeFilter;

  PersonTimelineState copyWith({
    List<TimelineItem>? items,
    bool? hasMore,
    bool? isLoadingMore,
    String? typeFilter,
    bool clearTypeFilter = false,
  }) {
    return PersonTimelineState(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      typeFilter:
          clearTypeFilter ? null : (typeFilter ?? this.typeFilter),
    );
  }
}

@riverpod
class PersonTimeline extends _$PersonTimeline {
  static const _pageSize = 20;
  int _offset = 0;

  @override
  Future<PersonTimelineState> build(String personId) async {
    _offset = 0;
    final page = await _loadPage(typeFilter: null);
    return PersonTimelineState(
      items: _groupItems(page),
      hasMore: page.length == _pageSize,
    );
  }

  Future<void> setTypeFilter(String? filter) async {
    _offset = 0;
    state = const AsyncValue.loading();
    final page = await _loadPage(typeFilter: filter);
    state = AsyncValue.data(PersonTimelineState(
      items: _groupItems(page),
      hasMore: page.length == _pageSize,
      typeFilter: filter,
    ));
  }

  Future<void> loadNextPage() async {
    final current = state.valueOrNull;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));
    // Count only actual activity rows (not month headers) to derive next offset.
    final activityCount =
        current.items.whereType<TimelineActivityRow>().length;
    _offset = activityCount;
    final page = await _loadPage(typeFilter: current.typeFilter);

    state = AsyncValue.data(current.copyWith(
      items: current.items + _groupItems(page, existingItems: current.items),
      hasMore: page.length == _pageSize,
      isLoadingMore: false,
    ));
  }

  Future<List<Bullet>> _loadPage({required String? typeFilter}) async {
    final db = await ref.read(appDatabaseProvider.future);
    return PeopleDao(db).getBulletsForPersonPaged(
      personId,
      typeFilter: typeFilter,
      limit: _pageSize,
      offset: _offset,
    );
  }

  /// Groups a page of bullets into [TimelineItem] list, inserting month headers
  /// when the month-year changes. [existingItems] is used to determine the last
  /// header already rendered so we avoid duplicate headers at page boundaries.
  List<TimelineItem> _groupItems(
    List<Bullet> page, {
    List<TimelineItem> existingItems = const [],
  }) {
    String? lastMonth = existingItems.whereType<TimelineMonthHeader>().lastOrNull?.label;
    final result = <TimelineItem>[];
    for (final bullet in page) {
      final dt = DateTime.tryParse(bullet.createdAt)?.toLocal();
      final label = dt != null ? DateFormat('MMMM y').format(dt) : '';
      if (label != lastMonth) {
        result.add(TimelineMonthHeader(label));
        lastMonth = label;
      }
      result.add(TimelineActivityRow(bullet));
    }
    return result;
  }
}

// ---------------------------------------------------------------------------
// People screen state: sort + filter
// ---------------------------------------------------------------------------

@riverpod
class PeopleScreenNotifier extends _$PeopleScreenNotifier {
  @override
  PeopleScreenState build() => const PeopleScreenState();

  void setSort(PeopleSort sort) => state = state.copyWith(sort: sort);

  void setSearchQuery(String query) => state = state.copyWith(searchQuery: query);

  void setRelationshipTypeFilter(String? type) => type == null
      ? state = state.copyWith(clearRelationshipType: true)
      : state = state.copyWith(relationshipType: type);

  void setTagFilter(String? tag) => tag == null
      ? state = state.copyWith(clearTag: true)
      : state = state.copyWith(tag: tag);

  void setNeedsFollowUpOnly(bool value) =>
      state = state.copyWith(needsFollowUpOnly: value);

  void clearFilters() => state = const PeopleScreenState(sort: PeopleSort.lastInteraction);
}
