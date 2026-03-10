# Implementation Plan: Personal CRM

**Branch**: `003-personal-crm` | **Date**: 2026-03-10 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/003-personal-crm/spec.md`

## Summary

Augment the existing People + BulletPersonLinks infrastructure to deliver a lightweight personal CRM: rich person profiles (company, role, email, tags, relationship type, follow-up), real-time people search with sort/filter, @mention → create-person flow in the capture bar, linked-person display on all log detail screens, and stale/follow-up surfacing in the people list. Schema migrates v2 → v3 via additive ALTER TABLE columns.

## Technical Context

**Language/Version**: Dart 3.3+ / Flutter 3.19+
**Primary Dependencies**: drift 2.18, flutter_riverpod 2.5, riverpod_annotation 2.3, uuid 4.x, intl 0.19, flutter_local_notifications 17 (existing)
**Storage**: SQLite via drift + SQLCipher. Schema version 2 → 3 (additive migration, no data loss).
**Testing**: flutter_test (unit + widget tests)
**Target Platform**: iOS, Android, Web
**Project Type**: Mobile app (cross-platform Flutter)
**Performance Goals**: Timeline of 200 bullets < 1s; people list of 500 < 2s (SC-002, SC-007); @mention autocomplete resolves in < 200ms (SC-003)
**Constraints**: Offline-capable (local-first), encrypted at rest (SQLCipher), sync-compatible (all writes enqueue to pending_sync)
**Scale/Scope**: Up to 500 people, 10 tags per person, 200 bullets per person timeline

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. Code Quality ✅ PASS

- All new DAO methods follow the existing single-responsibility pattern (`PeopleDao`, typed drift DAOs).
- New columns and migration are additive — no dead code or backward-compatibility shims.
- Tag storage as comma-separated string is the simplest correct approach; no premature abstraction into a junction table.
- All naming follows snake_case files, `Provider` suffix for Riverpod providers, `Dao` suffix for DAOs.

### II. Testing Standards ✅ PASS

- All 5 user story acceptance scenarios are enumerable as automated tests.
- Offline path must be exercised: schema migration test (v2→v3), link insert/query test all use in-memory drift DB.
- Duplicate detection, follow-up auto-clear, and stale indicator logic are pure Dart — unit testable without Flutter.

### III. UX Consistency ✅ PASS

- "Create [name]" row in @mention overlay preserves capture speed (no new screen mid-capture).
- Linked person chip follows existing chip pattern in `BulletDetailScreen` (hashtag chips).
- Stale/follow-up badges are passive decorations — they do not block any action (Calm by default).
- Empty states defined for all new list/timeline views.
- Destructive "Delete person" requires confirmation bottom sheet (existing pattern from log delete).

### IV. Performance ✅ PASS

- FTS5 `people_fts` already indexes name+notes; company added in v3 migration rebuild.
- People list sort is SQL ORDER BY (not Dart sort on full list).
- Tag/relationship-type filters are Dart-side on a maximum of 500 rows — negligible cost.
- `watchBulletsForPerson` stream is already efficient (indexed JOIN); 200 rows well within 1s budget.

### Privacy & Data Integrity ✅ PASS

- All new columns included in `pending_sync` payload for cloud sync compatibility.
- Soft-delete only — person deletion cascades to links but never physically removes bullets.
- No new external data transmission; all data stays local until user-initiated sync.

**Post-design re-check**: All gates still pass after Phase 1 design. No violations to justify.

## Project Structure

### Documentation (this feature)

```text
specs/003-personal-crm/
├── plan.md              # This file
├── research.md          # Phase 0: decisions on tags, FTS, duplicate detection, etc.
├── data-model.md        # Phase 1: schema v3 spec, migration SQL, Dart model mapping
├── quickstart.md        # Phase 1: implementation order, commands, testing focus
├── contracts/
│   ├── people-dao.md    # PeopleDao new method contracts
│   ├── people-provider.md # Riverpod provider contracts
│   └── ui-screens.md    # Screen/widget contracts (UI behaviors)
└── tasks.md             # Phase 2 output (/speckit.tasks — NOT created here)
```

### Source Code (modified files)

```text
app/
├── lib/
│   ├── database/
│   │   ├── tables/
│   │   │   ├── people.dart                   # +10 new columns
│   │   │   └── bullet_person_links.dart      # +linkType column
│   │   ├── daos/
│   │   │   └── people_dao.dart               # +8 new methods, updated insertLink
│   │   └── app_database.dart                 # schemaVersion 2→3, migration block
│   ├── providers/
│   │   └── people_provider.dart              # +3 providers, +PeopleScreenNotifier
│   ├── screens/
│   │   ├── people/
│   │   │   ├── people_screen.dart            # +search, sort, filter, stale badges
│   │   │   ├── person_profile_screen.dart    # +all fields, follow-up, reactive
│   │   │   ├── create_person_sheet.dart      # +duplicate check, initialName param
│   │   │   ├── edit_person_sheet.dart        # NEW: full field editor
│   │   │   └── person_picker_sheet.dart      # NEW: search + select person
│   │   └── daily_log/
│   │       ├── bullet_detail_screen.dart     # +linked person section
│   │       └── task_detail_screen.dart       # +linked person section
│   └── widgets/
│       ├── bullet_capture_bar.dart           # +Create [name] row in @mention
│       └── person_status_badge.dart          # NEW: stale/follow-up badge widget
└── test/
    └── personal_crm/                         # NEW: test suite
        ├── people_dao_test.dart
        ├── people_provider_test.dart
        └── people_screen_test.dart
```

## Complexity Tracking

No constitution violations. Table not required.
