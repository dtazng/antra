# Implementation Plan: Person Detail View

**Branch**: `004-person-detail-view` | **Date**: 2026-03-10 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/004-person-detail-view/spec.md`

## Summary

Redesign `PersonProfileScreen` from an infinite chronological log into a structured, summary-first relationship overview. The main profile screen gains six well-defined sections: identity header, quick actions bar, relationship summary stats, recent activity preview (≤10 entries), pinned notes, and relationship insights. A new `PersonFullTimelineScreen` handles paginated infinite-scroll history with month-year grouping and type-based filtering. A new `LogInteractionSheet` widget provides fast in-context logging from the profile. Schema migrates v3 → v4 via one additive `ALTER TABLE` to add `is_pinned` on `bullet_person_links`.

---

## Technical Context

**Language/Version**: Dart 3.3+ / Flutter 3.19+
**Primary Dependencies**: drift 2.18, flutter_riverpod 2.5, riverpod_annotation 2.3, uuid 4.x, intl 0.19
**Storage**: SQLite via drift + SQLCipher. Schema version 3 → 4 (additive migration, no data loss).
**Testing**: flutter_test (unit + widget tests — not included unless explicitly requested)
**Target Platform**: iOS, Android, Web
**Project Type**: Mobile app (cross-platform Flutter)
**Performance Goals**: Profile screen renders in < 500ms for 500 linked interactions (SC-001); full timeline next-page loads in < 300ms (SC-004); 60 fps scroll on supported devices (Constitution §IV)
**Constraints**: Offline-capable (local-first), encrypted at rest (SQLCipher), sync-compatible (all link mutations enqueue to pending_sync)
**Scale/Scope**: ≤ 500 people, ≤ 500 interactions per person, page size 20 for full timeline

---

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. Code Quality ✅ PASS

- `PersonProfileScreen` body is restructured into small, single-responsibility private widgets (`_HeaderSection`, `_QuickActionsBar`, `_RelationshipSummaryCard`, `_RecentActivitySection`, `_PinnedNotesSection`, `_InsightsSection`). Each has one clear reason to change.
- `PersonTimelineNotifier` follows the existing `@riverpod class ... extends _$...` pattern. State is immutable `PersonTimelineState` data class.
- `LogInteractionSheet` follows the `CreatePersonSheet` / `EditPersonSheet` pattern — `ConsumerStatefulWidget` in its own file.
- No dead code: `_QuickEditSheet` was already removed. `bulletsForPersonProvider` (all-bullets stream) is replaced by `recentBulletsForPersonProvider` and `PersonTimelineNotifier` — the old provider will be removed if no other screens use it.
- `isPinned` stored on `BulletPersonLinks` (research Decision 1). Clean additive column.

### II. Testing Standards ✅ PASS

- This feature does not explicitly request tests (per spec and constitution Principle II: "required where it provides durable value; not required as a ritual").
- All 5 acceptance scenario sets in the spec are enumerable as manual test cases in `quickstart.md`.
- Offline path: all new DAO methods use the existing in-memory drift DB; any future tests can use the same approach.

### III. UX Consistency ✅ PASS

- Quick action buttons use the same `Icon + label` pattern already established in other bottom bars.
- `LogInteractionSheet` uses the same bottom sheet structure as `CreatePersonSheet`.
- `_PinnedNoteCard` long-press → bottom sheet confirmation follows the same "destructive action requires confirmation sheet" pattern (unpin is not destructive, but the pattern is consistent).
- Empty states defined for all new sections and the full timeline.
- `_InsightsSection` is passive and non-intrusive — calm by default (Constitution §III).
- Full timeline uses `SliverList` with mixed header/row items — established Flutter idiom matching the existing `CollectionDetailScreen` pattern.

### IV. Performance ✅ PASS

- Main profile loads at most 10 bullets (recent) + pinned bullets + one aggregation query. All queries are indexed. Well within 500ms budget.
- Full timeline uses offset-based pagination with page size 20 — no full-table scan on open.
- `InteractionSummary` computed via single SQL `COUNT(CASE WHEN ...)` — one round-trip, sub-millisecond at 500 rows.
- `ScrollController` threshold at 300px from bottom gives 2–3 rows of scroll time to pre-load — smooth perceived performance.
- No synchronous work on the UI thread for any new operation.

### Privacy & Data Integrity ✅ PASS

- `isPinned` column included in `_enqueueSync` payload for `BulletPersonLinks` mutations (sync-compatible).
- No new external data transmission.
- All new writes follow soft-delete pattern. No hard deletes introduced.

**Post-design re-check**: All gates still pass after Phase 1 design. No violations to justify.

---

## Project Structure

### Documentation (this feature)

```text
specs/004-person-detail-view/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0: 8 decisions on isPinned placement, pagination, etc.
├── data-model.md        # Phase 1: schema v3→v4, SQL queries, Dart data classes
├── quickstart.md        # Phase 1: 30-step implementation order, test scenarios
├── contracts/
│   ├── people-dao.md    # New/updated DAO method contracts
│   ├── people-provider.md # New provider contracts (PersonTimelineNotifier, etc.)
│   └── ui-screens.md    # Screen/widget UI behavior contracts
└── tasks.md             # Phase 2 output (/speckit.tasks — NOT created here)
```

### Source Code (modified/new files)

```text
app/
├── lib/
│   ├── database/
│   │   ├── tables/
│   │   │   └── bullet_person_links.dart     # +isPinned column
│   │   ├── daos/
│   │   │   └── people_dao.dart              # +5 new methods (summary, paged, pinned, setPinned, recent)
│   │   └── app_database.dart                # schemaVersion 3→4, migration block
│   ├── models/
│   │   └── timeline_item.dart               # NEW: sealed TimelineItem class
│   ├── providers/
│   │   └── people_provider.dart             # +4 new providers, PersonTimelineNotifier
│   ├── screens/
│   │   └── people/
│   │       ├── person_profile_screen.dart   # REWRITE: structured section layout
│   │       └── person_full_timeline_screen.dart # NEW: paginated full timeline
│   └── widgets/
│       └── log_interaction_sheet.dart       # NEW: quick log from profile
└── test/
    └── person_detail/                       # NEW (if tests requested): not in scope
```

---

## Complexity Tracking

No constitution violations. Table not required.
