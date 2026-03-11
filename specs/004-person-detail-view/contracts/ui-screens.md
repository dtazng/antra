# Contract: UI Screens & Widgets (004)

---

## PersonProfileScreen (rewritten)

**File**: `app/lib/screens/people/person_profile_screen.dart`
**Navigation entry**: existing — no call sites change
**Widget type**: `ConsumerWidget` (unchanged)

### Section render order (CustomScrollView with SliverList)

```
1. _HeaderSection          — avatar, name, company/role, last interaction, follow-up badge
2. _QuickActionsBar        — 4 icon+label buttons: Log, Note, Follow-up, Edit
3. _RelationshipSummaryCard — stat chips: total / 30d / 90d / per-type
4. _RecentActivitySection  — 5 rows default, "Show more" → 10, "View All Activity" link
5. _PinnedNotesSection     — hidden when empty; list of pinned note cards
6. _InsightsSection        — hidden when no active insight
7. _DeleteButton           — existing destructive action at bottom
```

### `_HeaderSection`

- Avatar: `CircleAvatar` radius 32, initial-based (existing pattern)
- Name: `titleLarge` typography
- Company/role line: if either non-null, format as `[role] · [company]`
- Last interaction: `_LastInteractionLabel` (existing, moved here from below avatar)
- Follow-up badge: `PersonStatusBadge(person)` (existing widget, shown in header)

### `_QuickActionsBar`

Four `_QuickActionButton` tiles (Column with Icon + label text):

| Action | Icon | Behavior |
|--------|------|----------|
| Log | `Icons.add_circle_outline` | Opens `LogInteractionSheet(personId: ...)` |
| Note | `Icons.sticky_note_2_outlined` | Opens `LogInteractionSheet(personId: ..., initialType: 'note')` |
| Follow-up | `Icons.flag_outlined` | Opens `_FollowUpSection` as bottom sheet, or scrolls to it |
| Edit | `Icons.edit_outlined` | Opens `EditPersonSheet(person: ...)` |

### `_RelationshipSummaryCard`

- Container with `surfaceContainerHighest` background, 12px border radius
- Three `_StatChip` widgets in a Row: "N total", "N this month", "N last 90d"
- If `byType` has ≥ 2 types with count > 0: a `Wrap` of smaller type chips below (e.g., "12 notes · 5 tasks")
- Shows `InteractionSummary.empty` state: "No interactions yet" in center

### `_RecentActivitySection`

- Section header: "Recent Activity" (`titleSmall`) + "View All →" `TextButton` aligned right
- Initially shows 5 rows. "Show more" text button expands to 10.
- Each `_ActivityRow`: type icon (16px) + content (1-line ellipsis, 14px) + relative date (12px, right-aligned)
- Empty state: `Icons.link_off_outlined` + "No interactions linked yet"
- Tapping a row navigates to `BulletDetailScreen` or `TaskDetailScreen` per `bullet.type`

### `_PinnedNotesSection`

- Hidden entirely when `pinnedBulletsForPersonProvider` returns empty list
- Section header: "Pinned" (`titleSmall`) + "+" icon button to add a pinned note (opens `LogInteractionSheet(initialType: 'note', pinOnSave: true)`)
- Each `_PinnedNoteCard`:
  - Content text, max 3 lines, `TextOverflow.ellipsis`
  - "Show more" `TextButton` if content > 3 lines (expands card in place)
  - Long-press → bottom sheet with "Unpin" and "Open full entry" actions
  - Unpin calls `PeopleDao.setPinned(bulletId, personId, pinned: false)` + `ref.invalidate(pinnedBulletsForPersonProvider(personId))`

### `_InsightsSection`

- Hidden entirely when no insight applies (see logic below)
- Single `Container` with `tertiaryContainer` or `errorContainer` background per severity
- Insight priority order (first matching shown):
  1. Overdue follow-up (`needsFollowUp = 1` AND `followUpDate` is past) → red tone, "Follow-up overdue — due [date]"
  2. Upcoming follow-up (`needsFollowUp = 1` AND `followUpDate` is future) → amber tone, "Follow up due in N days"
  3. Needs follow-up, no date → amber tone, "Marked as needs follow-up"
  4. Stale by cadence (`reminderCadenceDays` set AND `lastInteractionAt` > cadence days ago) → grey tone, "Last contact N days ago — consider reaching out"
- All messages are declarative, no exclamation marks

---

## PersonFullTimelineScreen (new)

**File**: `app/lib/screens/people/person_full_timeline_screen.dart`
**Navigation**: `Navigator.push` from "View All Activity" in `_RecentActivitySection`
**Widget type**: `ConsumerStatefulWidget`

### Structure

```
AppBar
  title: "[name]'s Activity"
  actions: [type filter chip row OR filter icon → bottom sheet]

Body: CustomScrollView
  SliverPersistentHeader (filter chip bar, sticky)
    chips: All | Notes | Tasks | Events
  SliverList (TimelineItem list)
    TimelineMonthHeader → SliverStickyHeader or Container with label
    TimelineActivityRow  → _ActivityRow (same widget as in PersonProfileScreen)
  SliverToBoxAdapter (load-more indicator / end-of-list message)
```

### Pagination behavior

- `PersonTimelineNotifier` holds accumulated `List<TimelineItem>` + `hasMore` + `isLoadingMore`
- `ScrollController` attached to `CustomScrollView`; listener calls `notifier.loadNextPage()` when `pixels >= maxScrollExtent - 300`
- Loading indicator: `CircularProgressIndicator` in a `SliverToBoxAdapter` at bottom, visible only when `isLoadingMore = true`
- End of list: "All interactions loaded" message in `SliverToBoxAdapter` when `hasMore = false`

### Filter behavior

- Tapping a filter chip calls `notifier.setTypeFilter(type)` which resets to page 0 and rebuilds the list
- Active filter chip is `selected: true` with filled background

### Empty states

- No interactions (no filter): `Icons.history_toggle_off` + "No interactions yet" + "Log one from the profile screen"
- No interactions for active filter: `Icons.filter_list_off` + "No [type] logged yet" + "Clear filter" button

---

## LogInteractionSheet (new widget)

**File**: `app/lib/widgets/log_interaction_sheet.dart`
**Widget type**: `ConsumerStatefulWidget`

### Parameters

```dart
class LogInteractionSheet extends ConsumerStatefulWidget {
  final String personId;
  final String personName;
  final String initialType; // 'note' | 'event' | 'task', default 'note'
  final bool pinOnSave;     // if true, calls setPinned after insertLink
}
```

### UI

```
Bottom sheet (isScrollControlled: true)
  Drag handle
  Person badge chip (non-interactive, shows @personName)
  Type selector row: Note | Event | Task (SegmentedButton or FilterChip row)
  TextField (multiline, autofocus, "What happened? Add a note…")
  [If type = 'task': due date row (optional)]
  Save button (FilledButton)
```

### Save behavior

1. Validate: content non-empty
2. Get today's `DayLog` (or create one): use existing `DayLogsDao.getOrCreateToday()` pattern
3. Insert `Bullet` with `type`, `content`, `dayId`, `position` (append at end), `deviceId: 'local'`
4. Call `PeopleDao.insertLink(bullet.id, personId, linkType: 'manual')`
5. If `pinOnSave`: call `PeopleDao.setPinned(bullet.id, personId, pinned: true)`
6. Invalidate `recentBulletsForPersonProvider(personId)`, `interactionSummaryProvider(personId)`, `pinnedBulletsForPersonProvider(personId)` (if pinOnSave)
7. `Navigator.pop(context, bullet)` — returns created bullet so caller can react

### Empty / error states

- Save button disabled when content is empty
- If save fails: show `SnackBar` "Failed to save. Please try again."
