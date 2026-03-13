# Feature Specification: UI Polish — Composer, Task Cards & Tab Bar

**Feature Branch**: `009-ui-polish`
**Created**: 2026-03-13
**Status**: Draft
**Input**: Refine the composer, task cards, note/task presentation, and tab bar design of the personal CRM app so the experience feels more cohesive, polished, and aligned with the calm bullet-journal style.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Task Completion (Priority: P1)

A user sees a task they previously logged and wants to mark it as done. They tap the checkbox/circle on the left of the task card. The task immediately shows a checked visual state with reduced emphasis, confirming the action. The task remains visible in the day view in its completed state so the user can review what was accomplished.

**Why this priority**: Tasks behaving as real todos is the most functionally valuable change. Without completion state, tasks are indistinguishable from notes beyond a label — this is the highest-impact fix.

**Independent Test**: Can be tested by logging a task, viewing it in the timeline, tapping the completion control, and verifying the visual state changes and persists after app restart.

**Acceptance Scenarios**:

1. **Given** a task entry in the day view timeline, **When** the user taps the leading completion control, **Then** the task shows a checked state, the text appears at reduced emphasis (muted color and/or strikethrough), and the change persists across sessions.
2. **Given** a completed task, **When** the user taps the completion control again, **Then** the task reverts to incomplete state.
3. **Given** a completed task, **When** the user views the person detail screen for a linked person, **Then** the task appears in that person's history with its current completion state shown.
4. **Given** a completed task, **When** the app is restarted, **Then** the completion state is preserved.

---

### User Story 2 — Remove Redundant Task Label (Priority: P2)

A user glances at the day view timeline. Tasks are clearly recognizable without a text badge repeating "TASK" on the right — the completion control on the left and the checked/unchecked visual treatment carry that identity without clutter. Notes and tasks feel visually distinct but the difference is structural rather than decorative.

**Why this priority**: Removing visual clutter is a fast, high-impact UX improvement that makes the entire feed feel cleaner. It directly supports the bullet-journal aesthetic.

**Independent Test**: Can be tested by logging both a note and a task, viewing the timeline, and confirming that task identity is communicated through structure (leading icon/control) without a text label on the right.

**Acceptance Scenarios**:

1. **Given** a task entry in the timeline, **When** the user views the day feed, **Then** no text badge reading "TASK" or equivalent appears on the right side of the card.
2. **Given** a note and a task side by side, **When** the user glances at the feed, **Then** the two types are visually distinguishable by the leading indicator alone.

---

### User Story 3 — Dynamic Card Height (Priority: P3)

A user logs a longer note or task — for example a paragraph of meeting context or a multi-line action item. The card grows to show the full text rather than truncating with ellipsis. The layout remains readable and the card spacing adjusts naturally.

**Why this priority**: Truncation frustrates users who entered meaningful content. Dynamic height makes the app feel trustworthy and complete.

**Independent Test**: Can be tested by creating entries with 2–5 lines of text and verifying full content is visible with natural line wrapping in all card states.

**Acceptance Scenarios**:

1. **Given** an entry with more than one line of text, **When** the user views the timeline, **Then** the full text is shown without ellipsis and the card height adjusts to fit.
2. **Given** a very long entry (10+ lines), **When** displayed in the timeline, **Then** the text wraps naturally and the card expands; all leading icons/actions remain top-aligned.
3. **Given** a dynamically tall card, **When** the user swipes to delete it, **Then** the swipe gesture works correctly across the full card height.

---

### User Story 4 — Simplified Composer (Priority: P4)

A user opens the log composer to quickly capture a note or task. The type selector shows a single concise label ("Note" or "Task") with no sublabel beneath it. The input field looks visually integrated and rounded, not a rectangular block inside the card. The overall composer feels lighter and faster.

**Why this priority**: The composer is the most-used entry point. Simplifying it and fixing the visual roughness improves every interaction session.

**Independent Test**: Can be tested by opening the composer and verifying: no sublabel appears beneath the type switch, the text input area has a rounded appearance that integrates with the card, and focus/keyboard states preserve the rounded shape.

**Acceptance Scenarios**:

1. **Given** the composer is visible, **When** the user inspects the type switch, **Then** only a single label ("Note" or "Task") appears, with no secondary helper text below it.
2. **Given** the composer is in idle state, **When** the user taps the text field to focus it, **Then** the input area remains visually rounded and does not appear as a sharp-cornered rectangle inside the card.
3. **Given** the composer with keyboard open, **When** the user types multiple lines, **Then** the rounded input shape is preserved and the card does not show sharp bottom corners.

---

### User Story 5 — Redesigned Tab Bar (Priority: P5)

A user navigates between tabs. The tab bar looks like it belongs to the same app as the day cards and composer — same design language, muted tones, subtle active state, no bright generic pill. It feels calm, thumb-friendly, and premium rather than stock-looking.

**Why this priority**: Navigation is always visible but primarily a polish item that doesn't block core functionality.

**Independent Test**: Can be tested by switching between all tabs and verifying the tab bar uses the app's color palette, has a subtle active state, and does not clash visually with the rest of the interface.

**Acceptance Scenarios**:

1. **Given** the app is open on any screen, **When** the user views the tab bar, **Then** it uses muted, dark tones consistent with the rest of the interface rather than a bright generic default style.
2. **Given** the active tab, **When** the user inspects the active indicator, **Then** it is subtle and elegant — not a loud pill or bright highlight — and the icon/label treatment distinguishes active from inactive without being distracting.
3. **Given** the tab bar adjacent to the composer, **When** the user views the full bottom of the screen, **Then** the tab bar and composer feel visually related and part of the same design system.

---

### Edge Cases

- What happens when a task card is very long (10+ lines) and the user swipes to delete — does the swipe detect correctly across the whole card?
- How does a completed task appear if it also has linked people shown on the card?
- What happens when the user switches from Note to Task in the composer with text already entered — does the label/visual update instantly?
- What if the tab bar is navigated to while the keyboard is open — does layout remain stable?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Users MUST be able to mark a task entry as complete directly from the task card in the timeline.
- **FR-002**: Users MUST be able to toggle a completed task back to incomplete.
- **FR-003**: Completed tasks MUST remain visible inline in the day view with a visual treatment indicating completion (reduced emphasis and/or strikethrough text).
- **FR-004**: Completion state MUST persist across app restarts.
- **FR-005**: Completed tasks linked to a person MUST appear in that person's detail/history view with current completion state shown.
- **FR-006**: The "TASK" text badge on the right side of task cards MUST be removed; task identity MUST be conveyed through the leading completion control and its icon treatment alone.
- **FR-007**: Task cards and note cards MUST be visually distinguishable by their leading indicator without relying on a text label.
- **FR-008**: Entry cards MUST expand vertically to show full content without ellipsis truncation; content MUST wrap naturally across multiple lines.
- **FR-009**: Leading icons and action controls MUST align to the top of the card for multi-line entries.
- **FR-010**: Swipe-to-delete gesture MUST remain functional regardless of card height.
- **FR-011**: The sublabel below the Note/Task type switch in the composer MUST be removed.
- **FR-012**: The type switch MUST remain self-explanatory with the single label "Note" or "Task" only.
- **FR-013**: The log input field MUST appear visually rounded and integrated into the composer card in all states: idle, focused, multiline, and keyboard-open.
- **FR-014**: The tab bar MUST use the app's muted, dark color palette and avoid bright or generic default styling.
- **FR-015**: The active tab indicator MUST be subtle — no large bright highlight or pill shape that clashes with the app's dark aesthetic.
- **FR-016**: Task completion state MUST be stored as an explicit field in the data model, not inferred from UI state.

### Key Entities

- **Bullet / Entry**: Represents a logged note or task. Gains an explicit `completedAt` timestamp (nullable) to distinguish open from done. The `type` field (note/task) remains unchanged.
- **Task Completion Event**: Toggling a task's completion updates the stored completion timestamp. No separate event log — the bullet record itself holds state.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can mark a task as complete in 1 tap; completion state is visible immediately with no loading delay.
- **SC-002**: 100% of task entries in the timeline show no "TASK" text badge on the right side of the card.
- **SC-003**: 100% of entries with more than one line of text display their full content without ellipsis in the day view timeline.
- **SC-004**: The composer type switch shows exactly one label line with no sublabel in all states.
- **SC-005**: The tab bar background and active state use only colors from the existing app palette (dark/muted tones); no white or bright default colors are visible.
- **SC-006**: Task completion state survives an app restart — a completed task remains completed after re-launch.

## Assumptions

- Completed tasks stay in the day view feed inline (not moved to a separate section), keeping the bullet-journal metaphor of a complete record of the day.
- Completion is stored as a nullable `completedAt` timestamp on the bullet record; a non-null value means complete.
- No animation beyond an immediate visual state change is required for completion; a brief opacity/color transition is acceptable.
- Dynamic card height has no upper limit — all content is shown. If an entry is extremely long, the user can scroll rather than truncating.
- The tab bar redesign updates styling/tokens only; navigation structure (tabs, order, icons) remains unchanged.
- Removing the sublabel from the composer requires no migration — it is a purely visual change.
