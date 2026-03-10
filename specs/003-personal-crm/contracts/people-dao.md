# Contract: PeopleDao (Extended)

**File**: `app/lib/database/daos/people_dao.dart`
**Layer**: Data Access Object (extends existing)
**Consumer**: Riverpod providers in `app/lib/providers/people_provider.dart`

---

## Existing methods (unchanged)

| Method | Signature | Notes |
|--------|-----------|-------|
| `watchAllPeople` | `Stream<List<PeopleData>>` | Ordered by name, no filters |
| `getPersonByName` | `Future<PeopleData?> (String name)` | Exact case-insensitive match |
| `insertPerson` | `Future<void> (PeopleCompanion)` | Transactional + sync enqueue |
| `updatePerson` | `Future<void> (PeopleCompanion)` | Transactional + sync enqueue |
| `softDeletePerson` | `Future<void> (String id)` | Sets isDeleted=1, enqueues delete |
| `updateLastInteractionAt` | `Future<void> (String personId, String timestamp)` | Updates cache + enqueues sync |
| `insertLink` | `Future<void> (String bulletId, String personId)` | Defaults linkType='mention' |
| `watchBulletsForPerson` | `Stream<List<Bullet>> (String personId)` | Newest first |
| `softDeleteLinksForBullet` | `Future<void> (String bulletId)` | Soft-deletes all links for bullet |

---

## New methods (added in v3)

### `watchPersonById`
```dart
Stream<PeopleData?> watchPersonById(String id)
```
- Returns a reactive stream of a single person record.
- Emits `null` if the person is deleted or not found.
- Used by `PersonProfileScreen` to stay reactive to edits.

---

### `searchPeople`
```dart
Future<List<PeopleData>> searchPeople(String query)
```
- Uses FTS5 `people_fts MATCH` for name/notes/company search.
- Query string is sanitized (append `*` for prefix match: `alice → alice*`).
- Returns non-deleted people only, ordered by `lastInteractionAt DESC`.
- Empty query returns all people (delegates to `watchAllPeople` path).
- Called from `PeopleScreen` search bar (debounced 200ms in UI).

---

### `findSimilarPeople`
```dart
Future<List<PeopleData>> findSimilarPeople(String name)
```
- Combines exact case-insensitive match (`getPersonByName`) + `LIKE '%fragment%'` on first name token.
- Returns up to 5 matches, non-deleted only.
- Used by `CreatePersonSheet` for duplicate detection (FR-028).

---

### `watchPeopleSorted`
```dart
Stream<List<PeopleData>> watchPeopleSorted(PeopleSort sort, {bool needsFollowUpOnly = false})
```
- `PeopleSort.lastInteraction` → `ORDER BY last_interaction_at DESC NULLS LAST`
- `PeopleSort.nameAZ` → `ORDER BY name ASC`
- `PeopleSort.recentlyCreated` → `ORDER BY created_at DESC`
- `needsFollowUpOnly = true` → adds `WHERE needs_follow_up = 1`
- Always excludes `is_deleted = 1`.
- Tag and relationship-type filtering applied Dart-side by caller.

---

### `insertLink` (updated signature)
```dart
Future<void> insertLink(String bulletId, String personId, {String linkType = 'mention'})
```
- Adds `linkType` parameter (default `'mention'`).
- Automatically calls `updateLastInteractionAt` and clears `needsFollowUp` in same transaction.
- **Invariant**: After a successful `insertLink`, `person.needsFollowUp == 0` and `person.lastInteractionAt` is current timestamp.

---

### `removeLink`
```dart
Future<void> removeLink(String bulletId, String personId)
```
- Soft-deletes the specific `bullet_person_links` row for (bulletId, personId).
- Does NOT recompute `lastInteractionAt` (that field is denormalized and updated forward-only in v1).
- Enqueues delete sync for the link record.

---

### `softDeleteLinksForPerson`
```dart
Future<void> softDeleteLinksForPerson(String personId)
```
- Soft-deletes all `bullet_person_links` rows where `person_id = personId`.
- Called as part of `softDeletePerson` transaction.
- After this call, no bullets appear in the deleted person's timeline.

---

### `getLinkedPersonForBullet`
```dart
Future<PeopleData?> getLinkedPersonForBullet(String bulletId)
```
- Returns the first non-deleted linked person for a bullet, or `null`.
- Used by `BulletDetailScreen` and `TaskDetailScreen` to show the linked person chip.
- In v1 only the first link is surfaced in the UI.

---

### `setFollowUp`
```dart
Future<void> setFollowUp(String personId, {required bool needs, String? followUpDate})
```
- Updates `needsFollowUp` and `followUpDate` in one call.
- `needs = false` → clears both `needsFollowUp = 0` and `followUpDate = null`.
- `needs = true, followUpDate = null` → sets flag without date.
- `needs = true, followUpDate = 'YYYY-MM-DD'` → sets flag and date.
- Enqueues update sync.

---

## Error contracts

| Condition | Behavior |
|-----------|----------|
| `insertLink` called with non-existent personId | drift FK violation — caller must ensure person exists |
| `searchPeople` with FTS5-unsafe chars (`"`, `-`, `*` bare) | sanitized: special chars stripped before query |
| `watchPersonById` for deleted person | emits `null` — UI shows "not found" state |
| `findSimilarPeople` with empty string | returns empty list |
