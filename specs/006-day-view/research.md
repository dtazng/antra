# Research: AI-style Day View with Relationship Briefing and Morphing Cards

**Feature**: `006-day-view`
**Date**: 2026-03-11

---

## Decision 1: Screen Placement — Where Does Day View Live?

**Decision**: The Day View replaces Tab 0 (`DailyLogScreen`) as the primary app entry point. The existing bullet-journal Daily Log is relocated to a secondary screen accessible from within the Day View (e.g., a "Journal" button or the tab bar's existing "Log" entry point).

**Rationale**: The spec explicitly states Day View is "the primary screen users see when opening the app." Tab 0 is the first screen on launch. Making it Tab 1 (People) would conflict with the existing People screen and bury the feature. Replacing Tab 0 is the natural fit.

**Alternatives considered**:

- **Add a new Tab 0, shift everything right**: Adds a 6th tab — violates the existing 5-tab structure. Rejected: increases nav complexity.
- **Replace the People tab (Tab 1)**: The People list still needs to exist. Rejected: would eliminate a necessary screen.
- **Keep DailyLogScreen at Tab 0, Day View as a floating overlay**: Too complex for MVP and breaks expected navigation patterns. Rejected.

**Impact**: `RootTabScreen` must be updated. `DailyLogScreen` remains but is navigated to from within Day View rather than being Tab 0.

---

## Decision 2: Suggestion Engine — Where Does It Live?

**Decision**: `SuggestionEngine` is a pure Dart service class (no Flutter imports) instantiated by a Riverpod `@riverpod` provider. It queries `PeopleDao` for all non-deleted people and computes `Suggestion` objects in-memory. The provider is a `Stream` that re-emits on any People data change.

**Rationale**:

- Pure Dart class = trivially unit-testable in isolation.
- Riverpod stream = reactive; any interaction logged (which updates `lastInteractionAt`) automatically refreshes the suggestion feed without manual invalidation.
- No new tables or schema migrations needed.
- All required signals already exist in the `People` table: `birthday`, `lastInteractionAt`, `needsFollowUp`, `followUpDate`.

**Suggestion scoring algorithm**:

```text
Birthday within 7 days:   3 points  (highest priority)
needsFollowUp = true:     2 points  (follow-up pending)
No contact in 30–90 days: 1 point   (reconnect prompt)
No contact in 90+ days:   2 points  (stronger reconnect urgency)
First interaction date =
  N years ago (±3 days):  1 point   (memory card)
```

- Sort by score descending, then by name.
- Emit top 4 as `Suggestion` objects.
- Filter out contacts interacted with today.

**Alternatives considered**:

- **Server-side suggestion ranking**: Requires network, adds latency, breaks offline mode. Rejected: violates constitution's local-first requirement.
- **Persisted `suggestions` table**: Over-engineered for MVP. Suggestions change daily; recomputing is fast (<10ms for 200 contacts). Rejected.

---

## Decision 3: Daily Goal Tracking — Persisted or Computed?

**Decision**: Computed from existing data. The daily goal count = number of distinct people reached via `bullet_person_links` today (bullets with `day_id` matching today's day log). No new table.

**Rationale**: `bullet_person_links` already records every interaction and links it to a `DayLog`. Counting distinct people with person links for today's day log is a single SQL query. Persisting a separate `DailyGoal` table adds a write path that must stay in sync with `bullet_person_links` — unnecessary complexity.

**Goal target**: Hardcoded default of 3 for MVP. Future: user preference in settings.

**Alternatives considered**:

- **New `daily_goals` table**: Adds a write path, a new DAO, sync complexity. Not justified until goal configuration is specced. Rejected for MVP.
- **Count total bullets (not distinct people)**: Less meaningful — logging 5 notes to the same person would complete the goal. Distinct-people count is more aligned with the "reach out" goal. Rejected.

---

## Decision 4: Quick Log Interaction Types → Bullet Model Mapping

**Decision**: The 4 Quick Log types (Coffee, Call, Message, Note) are stored as `type = 'event'` bullets with a structured content prefix, except Note which uses `type = 'note'`. No schema change.

| Quick Log Type | Bullet Type | Content Format |
| --- | --- | --- |
| Coffee ☕ | `event` | `☕ Coffee with [person name]` (auto-generated) or user-edited |
| Call 📞 | `event` | `📞 Call with [person name]` (auto-generated) |
| Message ✉️ | `event` | `✉️ Message to [person name]` (auto-generated) |
| Note ✍️ | `note` | User-typed content |

**Rationale**: Reuses existing `Bullets` schema without migration. The existing `LogInteractionSheet` already creates bullets + person links; `QuickLogBar` extends this pattern. The emoji prefix provides visual differentiation in the timeline and is queryable via `LIKE` if needed later.

**Alternatives considered**:

- **New `interaction_subtype` column on `Bullets`**: Would require a schema migration (v4 → v5) and `build_runner` regeneration. Premature for MVP. Rejected.
- **New `interactions` table separate from `Bullets`**: Significant data model divergence. Breaks search, collections, and sync that all operate on `bullets`. Rejected.

---

## Decision 5: Suggestion Card Expand/Collapse Animation

**Decision**: Use Flutter's built-in `AnimatedSize` + `AnimatedCrossFade` widgets for in-place card expansion. No third-party animation package.

**Rationale**: Constitution Principle I requires following platform idioms. Flutter's `AnimatedSize` handles content height changes with a smooth curve. `AnimatedCrossFade` handles the collapsed/expanded content swap. Together they produce a 200–300ms smooth expand animation using only the Flutter SDK.

**Implementation pattern**:

```dart
AnimatedSize(
  duration: const Duration(milliseconds: 250),
  curve: Curves.easeInOut,
  child: expanded ? _ExpandedContent() : _CollapsedContent(),
)
```

**Alternatives considered**:

- **`animations` package (Material motion)**: Adds a dependency for a feature that Flutter's built-in widgets can handle. Rejected.
- **Custom `Tween` + `AnimationController`**: More code, same visual result. Rejected.

---

## Decision 6: Today Timeline — Data Source

**Decision**: The today timeline reuses `bulletsForDayProvider(today)` filtered to only bullets that have at least one `bullet_person_links` entry. This surfaces interaction-type bullets (linked to a person) separately from journal bullets.

**Rationale**: The timeline is not a full journal replay — it's a "who did I interact with today" view. Filtering to person-linked bullets gives exactly that. `BulletsDao` already supports querying by day. A lightweight Riverpod stream filter does the rest with no new DAO query.

**Alternatives considered**:

- **Separate `today_interactions` query**: Adds DAO complexity. `bulletsForDayProvider` + client-side join filter is sufficient for ≤100 bullets/day. Rejected for MVP.

---

## Decision 7: Suggestion Card Dismissal

**Decision**: In-memory dismissal only for MVP. Dismissed cards are tracked in `SuggestionNotifier` state and excluded from the rendered list. They return on the next app launch.

**Rationale**: Persistent dismissal requires a new table or preferences key and complicates the data model. For MVP, in-memory is sufficient. The spec's open question ("do dismissed cards return the next day?") is answered by: yes, they return on next launch.

**Alternatives considered**:

- **Persist dismissals in `SharedPreferences`**: Lightweight. Can be added in a follow-up feature. Deferred to post-MVP.

---

## No Schema Migration Required

All Day View features can be implemented without modifying the existing database schema (currently at v4). The existing tables provide:

- `people.lastInteractionAt` → contact gap detection
- `people.birthday` → birthday cards
- `people.needsFollowUp` + `followUpDate` → follow-up cards
- `people.notes` → expanded card context
- `bullet_person_links` → daily goal count + timeline filtering
- `bullets` → Quick Log storage + today timeline

The first scheduled schema migration for Day View features will be in a future spec if `interactionSubtype` is needed for analytics or filtering.

> **Confirmed**: Current schema is v4 (v3→v4 added `isPinned` on `BulletPersonLinks`). No Day View work requires a v5 migration.
