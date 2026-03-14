# Data Model: Composer Redesign & Timeline Polish

**Feature**: `012-composer-redesign`
**Date**: 2026-03-14

---

## Schema Changes

**None.** All required columns already exist on the `bullets` table from `011-life-log` (schema version 5).

---

## Relevant Existing Fields (bullets table)

| Column | Type | Purpose in this feature |
|--------|------|------------------------|
| `follow_up_date` | TEXT (nullable) | ISO date string set at bullet creation when user selects a follow-up time in the composer |
| `follow_up_status` | TEXT (nullable) | Set to `'pending'` at creation if a follow-up date is chosen; managed by `NeedsAttentionProvider` thereafter |
| `follow_up_snoozed_until` | TEXT (nullable) | Not touched by composer; managed by Needs Attention actions |
| `follow_up_completed_at` | TEXT (nullable) | Not touched by composer; set when user marks Done in Needs Attention |
| `source_id` | TEXT (nullable) | Not touched by composer; used for completion events |

---

## Composer State (in-memory only)

The expanded/collapsed state of the composer and the selected follow-up date are **ephemeral UI state** held in `_BulletCaptureBarState`. They are not persisted to the database or to any provider. Resetting on Done or Cancel is handled in the widget's `_cancel()` method.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `_isExpanded` | `bool` | `false` | Whether the action row is visible |
| `_selectedFollowUpDate` | `String?` | `null` | ISO date string chosen via the follow-up picker; cleared after save |

---

## Follow-Up Date Values

| Preset | Computed Value |
|--------|---------------|
| Later today | `DateTime(now.year, now.month, now.day, 23, 59)` → ISO date portion `yyyy-MM-dd` |
| Tomorrow | `DateTime(now.year, now.month, now.day + 1)` |
| In 3 days | `DateTime(now.year, now.month, now.day + 3)` |
| Next week | `DateTime(now.year, now.month, now.day + 7)` |
| Custom date | User-selected via platform date picker; minimum `now + 1 day` |

Only the **date portion** (`yyyy-MM-dd`) is stored in `follow_up_date` — consistent with how the existing `addFollowUpToEntry` method works and how `watchPendingFollowUps(today)` queries it.
