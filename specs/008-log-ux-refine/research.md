# Research: Log UX Refinement

**Branch**: `008-log-ux-refine` | **Date**: 2026-03-13

---

## Decision 1: Corner Radius Fix Strategy

**Decision**: Add an optional `borderRadius` override parameter to `GlassSurface` rather than adding a new `GlassStyle` variant.

**Rationale**: `GlassStyle.bar` intentionally uses `BorderRadius.vertical(top: ...)` for surfaces that sit flush at the screen bottom (e.g., a fixed nav bar). The composer card is a floating card, not a flush bar. The simplest non-breaking fix is to allow `GlassSurface` to accept an optional `borderRadius` override; callers that don't pass it keep existing behavior. `BulletCaptureBar` then passes `borderRadius: BorderRadius.circular(AntraRadius.card)` to get all four corners rounded. This avoids proliferating `GlassStyle` variants.

**Alternatives considered**:
- Add `GlassStyle.floatingBar` — rejected; adds a variant for what is a simple per-call override need.
- Switch composer to `GlassStyle.card` — rejected; the card style has a different `blurSigma`, `tintOpacity`, and elevation shadow which changes the visual appearance in unintended ways.
- Wrap `GlassSurface` in a `ClipRRect` in `BulletCaptureBar` — rejected; creates redundant clip layers and doesn't fix the underlying `Container` borderRadius.

---

## Decision 2: Task vs Note Visual Distinction

**Decision**: Differentiate notes and tasks with both a leading icon and a subtle type badge inline with the entry content row. Notes keep a small bullet dot (`•`); tasks show a hollow checkbox outline icon. A small "TASK" label in uppercase muted text appears to the right of the content text, never for notes.

**Rationale**: The distinction must be scannable without reading content. A leading icon alone is a small tap target and can be overlooked. Adding a text label ("TASK") as secondary metadata makes the type immediately readable in a linear list. The label is muted (white38) to preserve the calm editorial aesthetic and not compete with content.

**Alternatives considered**:
- Color-coded left border stripe per type — rejected; adds visual noise and the aurora palette already uses color for person identity accents.
- Full badge chip — rejected; too loud for the calm bullet-journal style.
- Icon only, no label — kept as the leading indicator but insufficient alone per acceptance criteria requiring "obvious at a glance."

---

## Decision 3: Improved Type Switch Microcopy and Placement

**Decision**: Replace the bare icon toggle with a labeled tap target showing the mode name in 13pt text and a subtitle in 11pt muted text below it, within a compact 48×36 tap zone on the left side of the composer. Tapping the entire zone cycles Note ↔ Task.

**Microcopy**:
- Note mode: label = "Note", subtitle = "Context or observation"
- Task mode: label = "Task", subtitle = "Follow-up or action"

**Rationale**: Two lines of text in a small zone (label + subtitle) match the bullet-journal format where type is implicit from a visual glyph + brief label. The subtitle is short enough to fit without wrapping. Placing the toggle in the leftmost zone mirrors where bullet-type markers appear in traditional bullet journals (left of content).

**Alternatives considered**:
- Segmented control (Note | Task) — rejected; takes too much horizontal space in a compact composer bar.
- Tooltip on long-press — rejected; not discoverable for new users.
- Separate row above the text field — rejected; adds height to the composer and competes with the linked-people chips row.

---

## Decision 4: Multi-Person Picker — Interaction Pattern

**Decision**: Convert `PersonPickerSheet` to a multi-select sheet. Tapping a person toggles a checkmark on their row (no immediate dismissal). A "Done" button at the top confirms the selection and pops with `List<PeopleData>`. `BulletCaptureBar` merges the returned list into `_linkedPeople`, deduplicating by `id`. Each linked person appears as a chip with a remove (×) button above the text field.

**Rationale**: Multi-select is more efficient than re-opening the picker for each person. Deferred confirmation (Done button) prevents accidental half-complete selections. Returning `List<PeopleData>` (possibly empty) is backward compatible with callers that only care about single selection — they take the first element if needed.

**@mention behavior change**: `_selectSuggestion` currently sets `_linkedPerson`. It will instead add to `_linkedPeople` if the person is not already in the list, then clear the mention overlay. The @mention replaces the typed `@word` in the text field as before but no longer sets a single exclusive person.

**Alternatives considered**:
- Keep single-select, allow opening picker multiple times — rejected; poor UX for common "log lunch with Sarah and James" case.
- Inline chip input (like email cc field) — rejected; requires more implementation complexity and is inconsistent with existing picker pattern.

---

## Decision 5: Swipe-to-Delete Interaction Pattern

**Decision**: Use Flutter's `Dismissible` widget with `direction: DismissDirection.endToStart`, `confirmDismiss: (_) async => false` (never auto-confirm), and a custom red background with a trash icon. On drag past 40% of card width, a "Delete" button is visually revealed. On `onDismissed`, immediately soft-delete the bullet (is_deleted = 1) and show a `SnackBar` with an "Undo" action for 4 seconds. If Undo is tapped, reverse the soft delete by setting is_deleted = 0.

**Rationale**:
- `Dismissible` is Flutter's platform-standard swipe-to-delete mechanism, well-understood by users.
- `confirmDismiss: (_) async => false` prevents the automatic item removal; manual removal + undo snackbar gives full control.
- Soft-delete with 4-second undo (not hard delete) matches the existing deletion pattern in the codebase and satisfies the constitution's "destructive actions require undo window" principle.
- 4 seconds matches Gmail/Android material design undo snackbar standard.

**Alternatives considered**:
- Swipe to reveal a "Delete" button, then tap to confirm in a dialog — rejected; two-step modal confirmation is too heavy for this calm app and is more disruptive than undo.
- Custom `GestureDetector` drag detection — rejected; `Dismissible` handles velocity, threshold, and animation natively.
- Hard delete immediately — rejected; violates the constitution (destructive actions must offer undo).

---

## Decision 6: No New Packages Required

**Decision**: All five features can be implemented with existing dependencies (flutter, flutter_riverpod, drift, intl, uuid). No new packages needed.

**Rationale**:
- Corner radius fix: pure widget parameter change
- Task/note distinction: widget styling only
- Type switch: widget rebuild
- Multi-person picker: stateful widget change
- Swipe-to-delete: `Dismissible` is part of Flutter core; `ScaffoldMessenger.showSnackBar` is core
- Soft-delete and undo: existing `softDeleteBullet` DAO method + inverse update query

**Alternatives considered**:
- `flutter_slidable` package for richer swipe actions — rejected; overkill for a single delete action; Dismissible handles it natively and avoids a dependency.
