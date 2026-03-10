import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/database/daos/people_dao.dart';
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
