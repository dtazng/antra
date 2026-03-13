# UI Contracts: Day View — Bullet Journal Refinement

**Feature**: `001-day-view-journal`
**Date**: 2026-03-13

---

## Contract 1: BulletJournalComposer (replacing QuickLogBar)

**Widget**: `BulletCaptureBar` (adapted) — pinned at the bottom of `DayViewScreen`

### Inputs

| Input | Type | Required | Description |
|-------|------|----------|-------------|
| `date` | `String` (YYYY-MM-DD) | ✅ | The date to log the entry to |
| `onBulletSaved` | `void Function(String bulletId)` | optional | Called after successful save |

### Visual States

| State | Description |
|-------|-------------|
| **Idle** | Single text field showing hint text "What happened today…" (or equivalent). Person picker icon visible. No type selection visible. |
| **Active (typing)** | Keyboard visible. Text field active. `@mention` overlay appears above keyboard when `@word` is typed. Submit button becomes active when text is non-empty. |
| **@mention overlay** | Up to 5 matching contacts shown. "Create [name]" row shown when partial `@name` has no exact match. |
| **Submitting** | Submit button shows spinner. Text field is non-interactive. |
| **Post-save reset** | Composer fades out briefly, clears text, keyboard hides, returns to Idle state. Completes within 300ms of save confirmation. |

### Behaviour Rules

1. **Type is not user-selectable**. All entries are saved with `type = 'note'` silently.
2. **Person link is optional**. A non-empty text field is the only requirement to enable the submit button.
3. **`@mention` creates links**. After saving, `@Name` tokens that resolve to existing people create `BulletPersonLinks` with `linkType = 'mention'`.
4. **Inline person creation** opens `CreatePersonSheet` as a modal bottom sheet (current route stays intact). On success, the new person is selected as the `@mention` target.
5. **Empty text blocks submission**. The submit button is disabled when `text.trim().isEmpty`.
6. **Keyboard management**. The composer respects `MediaQuery.viewInsetsOf(context).bottom` to avoid double-padding when the keyboard is visible.
7. **Glass aesthetic**. The container uses `GlassSurface(style: GlassStyle.bar)`. Text is white. Hint text is `Colors.white38`. The `@mention` overlay uses `Colors.white.withValues(alpha: 0.08)` tint + `Colors.white.withValues(alpha: 0.12)` border.

---

## Contract 2: FollowUpCard (SuggestionCard — rendering rules)

**Widget**: `SuggestionCard` — unchanged; contract defines when/how it is rendered in `DayViewScreen`

### Rendering Rules

| Rule | Description |
|------|-------------|
| **One card per person** | For each `Suggestion` in `suggestionsFilteredProvider`, at most one `SuggestionCard` is rendered. No deduplication across sections is needed because there is now only one section. |
| **No summary card** | `RelationshipBriefing` is not rendered. No aggregation header ("You have N things to do") appears anywhere on the screen. |
| **Dismissed cards disappear** | When `onDismiss` is called, the card is removed from the feed for the current session. The provider continues to watch for future changes. |
| **Empty state** | When `suggestionsFilteredProvider` returns an empty list (or all suggestions are dismissed), an `_EmptyState` widget is shown: soft icon + message. No progress bar, no count. |

### Empty State Copy

When no follow-up cards remain:
> "Nothing to do — you're all caught up."

---

## Contract 3: DateNavigator (next-button boundary)

**Widget**: `_DateNavigator` inside `DayViewScreen`

### Inputs

| Input | Type | Description |
|-------|------|-------------|
| `label` | `String` | Display label ("Today", "Yesterday", or formatted date) |
| `onPrev` | `VoidCallback` | Navigate to previous day |
| `onNext` | `VoidCallback` | Navigate to next day (only called when `showNext = true`) |
| `onTapLabel` | `VoidCallback` | Open date picker |
| `showNext` | `bool` | Controls visibility of the right arrow |

### Rendering Rules

| Condition | Right Arrow Visibility |
|-----------|------------------------|
| `showNext = true` (selected date is before today) | Visible and tappable |
| `showNext = false` (selected date is today) | **Hidden** — replaced with `SizedBox(width: [arrow-width])` to preserve layout balance |

### Computation

```
showNext = _displayDate (midnight) < DateTime.now() (midnight)
```

Computed in `DayViewScreen.build()` and passed to `_DateNavigator`.

---

## Contract 4: DayViewScreen layout (post-refactor)

**Widget**: `DayViewScreen`

### Section Order (top to bottom, within scrollable area)

| Section | Widget | Condition |
|---------|--------|-----------|
| Follow-up cards | `SuggestionCard` × N | Shown when `suggestionsFilteredProvider` is non-empty and not all dismissed |
| Follow-up empty state | `_EmptyState` | Shown when no follow-up cards remain |
| Today's timeline | `TodayInteractionTimeline` | Always shown (empty state handled internally) |

### Removed Sections

| Section | Widget | Disposition |
|---------|--------|-------------|
| Summary briefing card | `RelationshipBriefing` | Removed from render tree |
| Daily goal progress card | `DailyGoalWidget` | Removed from render tree |

### Pinned Element

| Element | Position | Behaviour |
|---------|----------|-----------|
| `BulletCaptureBar` (journal composer) | Bottom of `AuroraBackground` Stack, `Positioned(left:0, right:0, bottom:0)` | Always visible, receives the currently displayed `_dateKey` |

### Provider Watch Changes

| Provider | Before | After |
|----------|--------|-------|
| `suggestionsFilteredProvider` | Watched | Still watched (feeds `SuggestionCard`) |
| `dailyGoalProvider` | Watched | **Removed** |
| `todayInteractionsProvider` | Watched | Still watched (feeds `TodayInteractionTimeline`) |
