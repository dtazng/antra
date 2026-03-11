# Contract: PeopleDao — New Methods (004)

**File**: `app/lib/database/daos/people_dao.dart`

---

## `getInteractionSummary(String personId) → Future<InteractionSummary>`

Returns aggregated interaction counts for a person. Never throws; returns `InteractionSummary.empty` if person has no linked bullets.

**SQL**: Single `customSelect` using `COUNT(CASE WHEN ...)` — see data-model.md §"Interaction Summary Query".

**Parameters**:
- `personId`: non-empty UUID of the person

**Returns**: `InteractionSummary` with `total`, `last30Days`, `last90Days`, `byType` populated.

---

## `getRecentBulletsForPerson(String personId, {int limit = 10}) → Future<List<Bullet>>`

Returns up to `limit` most recent non-deleted bullets linked to the person, ordered `created_at DESC`.

**Parameters**:
- `personId`: non-empty UUID
- `limit`: 1–20, default 10

**Returns**: `List<Bullet>`, possibly empty. Guaranteed ordered newest-first.

---

## `getBulletsForPersonPaged(String personId, {String? typeFilter, required int limit, required int offset}) → Future<List<Bullet>>`

Returns one page of bullets for the full timeline. Used exclusively by `PersonTimelineNotifier`.

**Parameters**:
- `personId`: non-empty UUID
- `typeFilter`: `null` (all types) | `'note'` | `'task'` | `'event'`
- `limit`: page size, typically 20
- `offset`: 0-based row offset

**Returns**: `List<Bullet>`, length 0..limit. Empty list when no more data — this signals end of pagination.

---

## `getPinnedBulletsForPerson(String personId) → Future<List<Bullet>>`

Returns all pinned notes for a person, ordered by `bpl.created_at ASC` (oldest pin first).

**Constraint**: Only bullets of `type = 'note'` can be pinned (enforced in `setPinned`).

**Returns**: `List<Bullet>`, possibly empty.

---

## `setPinned(String bulletId, String personId, {required bool pinned}) → Future<void>`

Sets or clears the `is_pinned` flag on the `bullet_person_links` row.

**Preconditions**:
- The `(bulletId, personId)` link must exist and not be soft-deleted
- The bullet must be of `type = 'note'` (enforced by caller/UI — not enforced by DAO)

**Behavior**: Updates `is_pinned = 1` or `0` on the matching row. Enqueues a sync payload for the updated link.

---

## Updated: `insertLink` (existing method, no signature change)

`insertLink` already exists. No changes to signature or behavior for this feature. The `is_pinned` column defaults to 0 on insert — no code change needed.
