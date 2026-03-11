# Contract: People Providers — New Providers (004)

**File**: `app/lib/providers/people_provider.dart`

---

## `interactionSummaryProvider(String personId)` → `AsyncValue<InteractionSummary>`

```dart
@riverpod
Future<InteractionSummary> interactionSummary(
  InteractionSummaryRef ref,
  String personId,
)
```

Delegates to `PeopleDao.getInteractionSummary(personId)`. Not a stream — re-fetched on demand via `ref.invalidate`.

**Invalidation trigger**: Called after any `insertLink`, `removeLink`, or soft-delete that affects this person.

---

## `recentBulletsForPersonProvider(String personId)` → `AsyncValue<List<Bullet>>`

```dart
@riverpod
Future<List<Bullet>> recentBulletsForPerson(
  RecentBulletsForPersonRef ref,
  String personId,
)
```

Returns up to 10 most recent bullets. Not a stream. Re-fetched via `ref.invalidate` after any link mutation.

**Replaces**: `bulletsForPersonProvider` (which was a stream of ALL bullets — no longer appropriate for the main profile screen).

---

## `pinnedBulletsForPersonProvider(String personId)` → `AsyncValue<List<Bullet>>`

```dart
@riverpod
Future<List<Bullet>> pinnedBulletsForPerson(
  PinnedBulletsForPersonRef ref,
  String personId,
)
```

Delegates to `PeopleDao.getPinnedBulletsForPerson(personId)`. Re-fetched via `ref.invalidate` after `setPinned` calls.

---

## `PersonTimelineNotifier(String personId)` — paginated timeline

```dart
@riverpod
class PersonTimeline extends _$PersonTimeline {
  static const _pageSize = 20;

  // state: (items, hasMore, isLoadingMore, typeFilter)
  @override
  Future<PersonTimelineState> build(String personId);

  void setTypeFilter(String? filter); // null = all
  Future<void> loadNextPage();
}

class PersonTimelineState {
  final List<TimelineItem> items;
  final bool hasMore;
  final bool isLoadingMore;
  final String? typeFilter;
}
```

**Behavior**:
- `build()` loads the first page (offset 0, limit 20) and groups results into `TimelineItem` list.
- `setTypeFilter(filter)` resets offset to 0, clears items, reloads.
- `loadNextPage()` increments offset by 20, appends new `TimelineItem`s; sets `hasMore = false` when page returns fewer than 20 rows.
- Month headers (`TimelineMonthHeader`) are inserted when the month-year string changes between consecutive rows.
- Concurrent `loadNextPage()` calls while `isLoadingMore = true` are no-ops.
