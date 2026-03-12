# Data Model: AI-style Day View

**Feature**: `006-day-view`
**Date**: 2026-03-11

---

## Overview

No new database tables are required. All Day View entities are either derived from existing tables or held in memory. The existing schema (v3) provides all required fields.

---

## Existing Tables Used (Read-Only or via Existing Write Paths)

### `people` (existing, v3)

Fields consumed by Day View:

| Field | Type | Used For |
|---|---|---|
| `id` | TEXT PK | Linking suggestions to people |
| `name` | TEXT | Card display |
| `notes` | TEXT? | Expanded card context |
| `birthday` | TEXT? (YYYY-MM-DD) | Birthday suggestion generation |
| `lastInteractionAt` | TEXT? (ISO 8601) | Contact gap calculation |
| `needsFollowUp` | INTEGER (0/1) | Follow-up card generation |
| `followUpDate` | TEXT? (YYYY-MM-DD) | Follow-up card urgency |
| `relationshipType` | TEXT? | Card subtitle context |
| `isDeleted` | INTEGER | Filter out deleted contacts |

### `bullets` (existing)

Used for Quick Log writes and today timeline:

| Field | Type | Used For |
|---|---|---|
| `id` | TEXT PK | Timeline item identity |
| `dayId` | TEXT FK | Associate with today's DayLog |
| `type` | TEXT | 'event' for Coffee/Call/Message, 'note' for Note |
| `content` | TEXT | Quick Log auto-generated or user-typed |
| `createdAt` | TEXT (ISO 8601) | Timeline sort + timestamp display |

### `bullet_person_links` (existing)

Used for daily goal count + timeline filtering:

| Field | Type | Used For |
|---|---|---|
| `bulletId` | TEXT FK | Join to bullets |
| `personId` | TEXT FK | Join to people |
| `createdAt` | TEXT | Goal count filter (today only) |
| `isDeleted` | INTEGER | Exclude soft-deleted links |

### `day_logs` (existing)

Used to get/create today's DayLog before inserting bullets:

| Field | Type | Used For |
|---|---|---|
| `id` | TEXT PK | Parent for today's bullets |
| `date` | TEXT (YYYY-MM-DD) | Find today's log |

---

## In-Memory Derived Entities

These are Dart model classes, not database tables. They are computed from existing data and held in Riverpod provider state.

### `Suggestion`

Computed by `SuggestionEngine` from `People` data. Not persisted.

```
Suggestion {
  type:        SuggestionType   // Reconnect | Birthday | FollowUp | Memory
  personId:    String           // FK to people.id
  personName:  String           // Denormalized for display
  personNotes: String?          // From people.notes
  signalText:  String           // Human-readable: "Last contact: 32 days ago"
  score:       int              // Priority score (higher = shown first)
  metadata:    Map<String, dynamic>  // Type-specific: { daysAgo, birthdayDate, followUpDate }
}
```

**`SuggestionType` values:**
- `reconnect` — contact gap > 30 days, no birthday or follow-up signal
- `birthday` — birthday within 7 days (before or on birthday)
- `followUp` — `needsFollowUp = 1`
- `memory` — first interaction with this person is exactly N years ago (±3 days)

**Scoring rules:**
- `birthday` within 7 days: 3 points
- `followUp` flag set: 2 points
- Contact gap 90+ days: 2 points
- Contact gap 30–89 days: 1 point
- `memory` (anniversary): 1 point (additive if combined)
- Contacts interacted with today: excluded entirely

**Emission rules:**
- Sort by score descending, then alphabetically by name
- Emit the top 4 after excluding today's contacts

---

### `DailyGoal`

Computed from `bullet_person_links` for today. Not persisted.

```
DailyGoal {
  target:    int   // Always 3 in MVP
  reached:   int   // COUNT(DISTINCT personId) in bullet_person_links where dayLog.date = today
  completed: bool  // reached >= target
}
```

**Derived via**: SQL count on `bullet_person_links` joined to `day_logs` filtered to today's date.

---

### `TodayInteraction`

One entry in the today timeline. Computed from `bullets` + `bullet_person_links`.

```
TodayInteraction {
  bulletId:      String    // From bullets.id
  personId:      String    // From bullet_person_links.personId
  personName:    String    // Denormalized from people.name
  content:       String    // From bullets.content
  type:          String    // 'event' | 'note'
  interactionLabel: String // Derived: "Coffee", "Call", "Message", "Note"
  loggedAt:      DateTime  // From bullets.createdAt
}
```

**Derived via**: Today's bullets (`dayId = today's DayLog.id`) that have at least one non-deleted `bullet_person_links` entry. Sorted by `createdAt` descending.

**`interactionLabel` derivation**:
```
content starts with '☕' → "Coffee"
content starts with '📞' → "Call"
content starts with '✉️' → "Message"
type = 'note'            → "Note"
fallback                  → "Interaction"
```

---

## State Held in Riverpod Providers (Not DB)

| State | Provider | Held In |
|---|---|---|
| Suggestion list | `SuggestionNotifier` | `AsyncNotifierProvider` |
| Dismissed suggestion IDs | `SuggestionNotifier` | In-memory `Set<String>` keyed by personId |
| Expanded card ID | `SuggestionNotifier` | `String?` in state |
| Daily goal | `dailyGoalProvider` | Computed `StreamProvider` |
| Today timeline | `todayInteractionsProvider` | Computed `StreamProvider` |
| Quick Log open type | `QuickLogNotifier` | Local widget state |

---

## Write Paths (Day View → Existing DB)

Day View introduces no new write paths. All writes use existing DAO methods:

| Action | DAO Method |
|---|---|
| Quick Log save | `BulletsDao.insertBullet` + `PeopleDao.insertLink` |
| Card action: "Complete" (task) | `TaskLifecycleService.completeTask` |
| Card action: "Log meeting" (event) | `BulletsDao.insertBullet` + `PeopleDao.insertLink` |
| Card action: "Message / Call" | `BulletsDao.insertBullet` + `PeopleDao.insertLink` |
| Card action: "Set follow-up" | `PeopleDao.setFollowUp` |

`PeopleDao.insertLink` already auto-clears `needsFollowUp` and updates `lastInteractionAt`, which automatically re-triggers the `SuggestionEngine` stream — no manual invalidation needed.
