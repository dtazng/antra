# Contract: People Providers

**File**: `app/lib/providers/people_provider.dart`
**Layer**: Riverpod providers (code-gen `@riverpod`)
**Consumer**: `PeopleScreen`, `PersonProfileScreen`, `BulletDetailScreen`, `TaskDetailScreen`, `BulletCaptureBar`

---

## Existing providers (unchanged)

| Provider | Type | Args | Description |
|----------|------|------|-------------|
| `allPeopleProvider` | `Stream<List<PeopleData>>` | — | All non-deleted people, name ASC |
| `bulletsForPersonProvider` | `Stream<List<Bullet>>` | `String personId` | Bullets linked to person, newest first |

---

## New providers

### `peopleSortedProvider`
```dart
@riverpod
Stream<List<PeopleData>> peopleSorted(
  PeopleSortedRef ref,
  PeopleSort sort, {
  bool needsFollowUpOnly = false,
})
```
- Delegates to `PeopleDao.watchPeopleSorted(sort, needsFollowUpOnly: needsFollowUpOnly)`.
- Used by `PeopleScreen` when sort or filter state changes.
- Default: `sort = PeopleSort.lastInteraction`, `needsFollowUpOnly = false`.

---

### `singlePersonProvider`
```dart
@riverpod
Stream<PeopleData?> singlePerson(SinglePersonRef ref, String personId)
```
- Delegates to `PeopleDao.watchPersonById(personId)`.
- Used by `PersonProfileScreen` to stay reactive while the user edits the profile.

---

### `linkedPersonForBulletProvider`
```dart
@riverpod
Future<PeopleData?> linkedPersonForBullet(
  LinkedPersonForBulletRef ref,
  String bulletId,
)
```
- Delegates to `PeopleDao.getLinkedPersonForBullet(bulletId)`.
- Used by `BulletDetailScreen` and `TaskDetailScreen` to show the linked person chip.
- Returns `null` if no person is linked.

---

## State model: `PeopleScreenNotifier`

A `StateNotifier` (or `@riverpod` notifier) holding the `PeopleScreen` filter/sort state.

```dart
@riverpod
class PeopleScreenNotifier extends _$PeopleScreenNotifier {
  // initial state
  PeopleScreenState build() => const PeopleScreenState();

  void setSort(PeopleSort sort);
  void setSearchQuery(String query);
  void setRelationshipTypeFilter(String? type);  // null = all
  void setTagFilter(String? tag);               // null = all tags
  void setNeedsFollowUpOnly(bool value);
  void clearFilters();
}

class PeopleScreenState {
  final PeopleSort sort;           // default: lastInteraction
  final String searchQuery;        // default: ''
  final String? relationshipType;  // default: null
  final String? tag;               // default: null
  final bool needsFollowUpOnly;    // default: false
}
```

The `PeopleScreen` widget watches `peopleScreenNotifierProvider` and applies Dart-side filters (relationshipType, tag, search) on top of the SQL-sorted stream.

---

## Provider invalidation rules

- `singlePersonProvider(id)` is auto-invalidated by drift's reactive stream when `people` table changes.
- `linkedPersonForBulletProvider(bulletId)` is a `Future`, not a stream — must be refreshed manually after link/unlink. Use `ref.invalidate(linkedPersonForBulletProvider(bulletId))` after `insertLink`/`removeLink`.
- `peopleSortedProvider` rebuilds when `PeopleScreenNotifier` state changes (new args passed to provider).
