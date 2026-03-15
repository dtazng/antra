# Data Model: Person Special Dates, Compact UI, Voice Logging, and Intelligent Logging UX

**Branch**: `017-voice-smart-logging` | **Date**: 2026-03-15

---

## Overview

This feature requires:
1. A new `PersonImportantDates` drift table (client) + `person_important_dates` table (Go backend)
2. Six new nullable columns on the existing `Bullets` drift table (voice log fields)
3. A new `SmartPromptDismissals` drift table (client-only, not synced)
4. Two new nullable columns on the `persons` backend table (birthday shortcut + last-important-date cache)

All client-side changes require a drift schema migration (v5 → v6). All backend changes require a new goose migration file.

---

## Entity: PersonImportantDate

**Purpose**: Represents a named date (birthday, anniversary, etc.) associated with a person, with an optional reminder rule.

### Client — drift table: `PersonImportantDates`

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `id` | TEXT (UUID) | NO | Client-generated UUID primary key |
| `personId` | TEXT (UUID) | NO | FK → people.id |
| `label` | TEXT | NO | Human label e.g. "Birthday", "Anniversary" |
| `isBirthday` | INTEGER (bool) | NO | 1 = birthday special treatment, default 0 |
| `month` | INTEGER | NO | 1–12 |
| `day` | INTEGER | NO | 1–31 |
| `year` | INTEGER | YES | Optional; null = recur annually with no year shown |
| `reminderOffsetDays` | INTEGER | YES | null = no reminder; negative = before; 0 = on day; positive = after |
| `reminderRecurrence` | TEXT | YES | 'yearly' \| 'once' \| null |
| `note` | TEXT | YES | Optional personal note |
| `createdAt` | TEXT | NO | ISO 8601 UTC |
| `updatedAt` | TEXT | NO | ISO 8601 UTC (LWW key) |
| `syncId` | TEXT | YES | Server-assigned UUID after sync |
| `deviceId` | TEXT | NO | Last-writing device |
| `isDeleted` | INTEGER | NO | Soft delete tombstone, default 0 |

**Primary key**: `id`
**Index**: `(personId, isDeleted)` — for querying all active dates for a person

### Backend — PostgreSQL table: `person_important_dates`

```sql
CREATE TABLE person_important_dates (
    id           UUID        NOT NULL PRIMARY KEY,  -- client-generated
    user_id      UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    person_id    UUID        NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
    label        TEXT        NOT NULL,
    is_birthday  BOOLEAN     NOT NULL DEFAULT false,
    month        INTEGER     NOT NULL CHECK (month BETWEEN 1 AND 12),
    day          INTEGER     NOT NULL CHECK (day BETWEEN 1 AND 31),
    year         INTEGER,
    reminder_offset_days INTEGER,
    reminder_recurrence  TEXT CHECK (reminder_recurrence IN ('yearly', 'once')),
    note         TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at   TIMESTAMPTZ
);
CREATE INDEX ix_pid_person_deleted ON person_important_dates (person_id, deleted_at);
CREATE INDEX ix_pid_user_updated   ON person_important_dates (user_id, updated_at);
```

---

## Entity: Bullet (voice log extensions)

**Purpose**: Extend existing `Bullets` table with voice log fields. All new columns are nullable — existing rows are unaffected.

### Client — additional columns on `Bullets` drift table

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `audioFilePath` | TEXT | YES | Relative path to .m4a file in app documents dir |
| `audioDurationSeconds` | INTEGER | YES | Duration in whole seconds |
| `transcriptText` | TEXT | YES | Final transcript; null if not a voice log |
| `transcriptionStatus` | TEXT | YES | 'pending' \| 'transcribing' \| 'complete' \| 'failed' \| null |
| `sourceType` | TEXT | YES | 'typed' \| 'voice' \| null (null = legacy typed) |

**Interpretation**: A bullet is a voice log when `sourceType = 'voice'`. `transcriptionStatus` drives the UI state.

### Backend — additional columns on `logs` table

```sql
ALTER TABLE logs
    ADD COLUMN audio_file_path       TEXT,
    ADD COLUMN audio_duration_seconds INTEGER,
    ADD COLUMN transcript_text       TEXT,
    ADD COLUMN transcription_status  TEXT CHECK (transcription_status IN ('pending','transcribing','complete','failed')),
    ADD COLUMN source_type           TEXT CHECK (source_type IN ('typed','voice'));
```

---

## Entity: SmartPromptDismissal

**Purpose**: Track dismissed smart prompts so they don't resurface before the snooze/suppress window expires. Client-only — not synced to backend.

### Client — drift table: `SmartPromptDismissals`

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `id` | INTEGER | NO | Auto-increment primary key |
| `personId` | TEXT | YES | FK → people.id (null for global prompts) |
| `promptType` | TEXT | NO | 'inactivity' \| 'follow_up' \| 'important_date' |
| `importantDateId` | TEXT | YES | FK → person_important_dates.id (for important_date type) |
| `dismissedUntil` | TEXT | NO | ISO date after which the prompt may resurface |
| `createdAt` | TEXT | NO | ISO 8601 UTC |

**Primary key**: `id` (auto-increment)
**Index**: `(personId, promptType)` — for fast lookup

---

## Reminder Preset → Storage Mapping

| UI Preset | `reminderOffsetDays` | `reminderRecurrence` |
|-----------|---------------------|---------------------|
| No reminder | null | null |
| On the day | 0 | 'yearly' |
| 1 day before | -1 | 'yearly' |
| 3 days before | -3 | 'yearly' |
| 1 week before | -7 | 'yearly' |
| 2 weeks before | -14 | 'yearly' |
| 1 month before | -30 | 'yearly' |
| Custom (yearly) | user-defined integer | 'yearly' |
| Custom (once) | user-defined integer | 'once' |

---

## Schema Migration Summary

### Client (drift): v5 → v6

1. **Add table** `PersonImportantDates` (new table — additive, no data loss)
2. **Add columns** to `Bullets`: `audioFilePath`, `audioDurationSeconds`, `transcriptText`, `transcriptionStatus`, `sourceType` (all nullable — additive, no data loss)
3. **Add table** `SmartPromptDismissals` (new table — client-only, not synced)

### Backend (goose): migration `00002_voice_and_important_dates.sql`

1. **Create table** `person_important_dates`
2. **Alter table** `logs` — add 5 nullable columns
3. **Add indexes** on both new/altered tables

---

## Entity Relationships

```
users
  └── persons
        └── person_important_dates  (one person → many dates)
  └── logs (formerly bullets in client)
        ├── log_person_links        (many-to-many with persons)
        └── [audio_file_path, transcript_text, ...]  (voice log fields inline)

SmartPromptDismissals  (client-only)
  └── references persons.id
  └── references person_important_dates.id
```

---

## Validation Rules

- `month` must be 1–12; `day` must be 1–31 (calendar validity enforced in UI, not DB)
- `reminderRecurrence` is required when `reminderOffsetDays` is not null
- `transcriptionStatus` must be non-null when `sourceType = 'voice'`
- `audioDurationSeconds` must be ≥ 1 when `audioFilePath` is set
- `isBirthday` can be true for at most one row per person (enforced in DAO, not DB constraint)
