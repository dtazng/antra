# Data Model: Log UX Refinement

**Branch**: `008-log-ux-refine` | **Date**: 2026-03-13

---

## Overview

This feature introduces no new database tables and no schema migrations. All required relationships already exist. The changes are confined to:

1. **UI state model** in `BulletCaptureBar` (multi-person list vs single person)
2. **DAO additions** for bullet soft-delete undo (reverse is_deleted update)
3. **Widget data flow** — `TodayInteraction` already carries `type`; no model changes needed

---

## Existing Entities (unchanged)

### Bullet (table: `bullets`)

| Field | Type | Notes |
|-------|------|-------|
| id | String (UUID) | Primary key |
| day_id | String | FK → day_logs.id |
| content | String | Raw journal text, may contain @mentions |
| type | String | `'note'` or `'task'` — stored explicitly |
| status | String | `'open'` or `'done'` |
| position | int | Display order within day |
| created_at | String (ISO-8601 UTC) | Immutable timestamp |
| updated_at | String (ISO-8601 UTC) | Last modified |
| is_deleted | int | Soft delete flag: 0 = active, 1 = deleted |

**Invariant**: `type` is always set at creation time from the composer toggle value; it is never inferred from content.

---

### BulletPersonLink (table: `bullet_person_links`)

| Field | Type | Notes |
|-------|------|-------|
| id | String (UUID) | Primary key |
| bullet_id | String | FK → bullets.id |
| person_id | String | FK → people.id |
| link_type | String | `'mention'` — how the link was created |
| is_deleted | int | Soft delete flag |
| is_pinned | int | Pin flag (unused in this feature) |

**Key property**: One bullet can have multiple `BulletPersonLink` rows. There is no unique constraint on `(bullet_id)` — only `(bullet_id, person_id)` must be unique per active link. This table already supports multi-person linking at the DB level.

---

### Person (table: `people`)

No changes. The person detail view queries `bullet_person_links` to find bullets for a person — adding more links to a bullet automatically surfaces that bullet in each linked person's timeline without additional queries.

---

## UI State Model Changes

### BulletCaptureBar (widget state)

**Before**:
```
_linkedPerson: PeopleData?   // single optional person
```

**After**:
```
_linkedPeople: List<PeopleData>   // ordered list; may be empty; deduplicated by id
```

**Invariant**: No duplicate persons (by `id`) in `_linkedPeople`. When a person is added via @mention or picker, if they are already in the list they are silently skipped.

---

### PersonPickerSheet (return type change)

**Before**: `Navigator.pop(person)` → caller receives `PeopleData?`

**After**: `Navigator.pop(selectedPeople)` → caller receives `List<PeopleData>` (empty list if dismissed with nothing selected)

**Backward compatibility**: The one existing caller (`BulletCaptureBar`) is updated in the same PR. No other callers exist.

---

## DAO Additions

### BulletsDao — `undoSoftDeleteBullet(String id)`

A new method to reverse a soft delete within the undo window:

```
UPDATE bullets SET is_deleted = 0, updated_at = <now> WHERE id = ?
```

This is the inverse of the existing `softDeleteBullet` method. Used when the user taps "Undo" in the snackbar.

---

## Data Flow: Swipe-to-Delete with Undo

```
User swipes entry left
  → onDismissed fires
  → BulletsDao.softDeleteBullet(bulletId)         // is_deleted = 1
  → ScaffoldMessenger shows SnackBar("Undo", duration: 4s)
  → (if Undo tapped within 4s)
      BulletsDao.undoSoftDeleteBullet(bulletId)   // is_deleted = 0
  → (if 4s expires without Undo)
      no further action; soft delete is permanent
```

The `watchAllBulletsForDay` stream already filters `is_deleted = 0`, so the entry disappears from the timeline immediately on soft delete and reappears immediately on undo.

---

## Data Flow: Multi-Person Link on Save

```
_submit()
  for each person in _linkedPeople:
    PeopleDao.insertLink(bulletId, person.id, linkType: 'mention')

  // @mention extraction from text (unchanged):
  for each @name in _extractMentions(content):
    person = PeopleDao.getPersonByName(name)
    if person != null AND person.id not already in _linkedPeople:
      PeopleDao.insertLink(bulletId, person.id, linkType: 'mention')
```

Deduplication between explicit picker selection and @mention text is done at submit time by checking `_linkedPeople.any((p) => p.id == person.id)` before calling `insertLink`.
