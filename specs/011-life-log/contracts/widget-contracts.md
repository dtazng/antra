# Widget Contracts: Life Log & Follow-Up System

**Branch**: `011-life-log` | **Date**: 2026-03-13

---

## TimelineScreen

**File**: `app/lib/screens/timeline/timeline_screen.dart`

**Purpose**: Primary home screen. Renders the Needs Attention section above the infinite-scroll timeline.

```dart
class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});
}
```

**Behavior**:
- Watches `timelineEntriesProvider` (stream of `List<TimelineDay>`)
- Watches `needsAttentionItemsProvider` (stream of `List<NeedsAttentionItem>`)
- Renders a `CustomScrollView` with slivers:
  1. `SliverToBoxAdapter(child: NeedsAttentionSection(...))` — hidden when list is empty
  2. For each `TimelineDay`: `SliverPersistentHeader` (sticky date label) + `SliverList` (entries)
  3. `SliverToBoxAdapter(child: _EmptyState(...))` — shown only when timeline has zero entries
- Bottom padding accounts for `BulletCaptureBar` height + safe area

**Empty state**: A calm message ("Nothing logged yet. Start by writing your first entry.") when both `timelineEntries` and `needsAttentionItems` are empty.

---

## NeedsAttentionSection

**File**: `app/lib/widgets/needs_attention_section.dart`

**Purpose**: Horizontal-scroll strip of pending follow-up suggestion cards. Absent when list is empty.

```dart
class NeedsAttentionSection extends StatelessWidget {
  const NeedsAttentionSection({
    super.key,
    required this.items,
    required this.onDone,
    required this.onSnooze,
    required this.onDismiss,
  });

  final List<NeedsAttentionItem> items;
  final void Function(String bulletId) onDone;
  final void Function(String bulletId) onSnooze;
  final void Function(String bulletId) onDismiss;
}
```

**Behavior**:
- Returns `SizedBox.shrink()` when `items.isEmpty`
- Renders a `Column` with a section label ("Needs Attention") and a horizontal `ListView`
- Each card in the horizontal list is a `_SuggestionCard` (see below)
- Section label: `fontSize: 11, color: Colors.white38, fontWeight: FontWeight.w400, letterSpacing: 0.4`

---

## _SuggestionCard (private)

**File**: `app/lib/widgets/needs_attention_section.dart`

**Purpose**: Single suggestion card within the Needs Attention horizontal strip.

```dart
class _SuggestionCard extends StatelessWidget {
  final NeedsAttentionItem item;
  final VoidCallback onDone;
  final VoidCallback onSnooze;
  final VoidCallback onDismiss;
}
```

**Behavior**:
- Displays: person name (if any), log entry content as context, follow-up date
- Three action buttons: Done (checkmark), Snooze (clock), Dismiss (×)
- Uses `GlassSurface` with `borderOpacityOverride: AntraColors.chipGlassBorderOpacity`
- Fixed width (~260px) to enable horizontal scroll

---

## TimelineList (internal to TimelineScreen)

**File**: `app/lib/widgets/timeline_list.dart` (or inline in `timeline_screen.dart`)

**Purpose**: Renders the sliver group for a single `TimelineDay`.

```dart
// Returns a list of slivers: [SliverPersistentHeader, SliverList]
List<Widget> buildDaySliver(TimelineDay day, {
  required void Function(String bulletId) onTap,
  required void Function(String bulletId) onDelete,
  required void Function(String bulletId, String followUpDate) onAddFollowUp,
});
```

**Entry card behavior**:
- Log entry card: same glass card style as current `TodayInteractionTimeline` entry
- Completion event card: slightly dimmed (e.g., `Colors.white54` text) with a checkmark leading icon
- Swipe-to-delete available on both types (with undo snackbar)
- Tapping navigates to bullet detail

---

## StickyDateHeaderDelegate (private)

**Purpose**: Minimal `SliverPersistentHeaderDelegate` for sticky date separators.

```dart
class _StickyDateHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _StickyDateHeaderDelegate(this.label);
  final String label;

  @override double get minExtent => 36.0;
  @override double get maxExtent => 36.0;
}
```

**Visual**: `fontSize: 11, color: Colors.white38, fontWeight: FontWeight.w500, letterSpacing: 0.4`. Background: `AntraColors.auroraNavy` (or scaffold background) to pin cleanly over scrolling content.

---

## BulletCaptureBar (existing — no API change)

**File**: `app/lib/widgets/bullet_capture_bar.dart`

No constructor changes. The `_kTabBarClearance = 60.0` constant remains correct for the new 2-tab bar (same physical height). The bar is positioned identically within `TimelineScreen` as it was in `DayViewScreen` (via `Stack` + `Positioned(bottom: 0)`).

**Behavioral change**: The `getOrCreateDayLog` call in the DAO path is replaced — new bullets use `createdAt.substring(0, 10)` as their `dayId` value directly, removing the async `day_logs` lookup from the capture critical path.

---

## Person Detail Screen (modified)

**File**: `app/lib/screens/people/person_detail_screen.dart`

**Changes**: Replace the flat `ListView` of bullets with a `CustomScrollView` using the same sticky-header sliver pattern as `TimelineScreen`.

**Data source**: Provider watches all bullets linked to the person (via `bullet_person_links`) plus all completion events where `sourceId` references a bullet linked to this person. Merged and grouped by date.

**Last-seen date**: Displayed prominently in the person header — derived from `MAX(createdAt)` across all linked bullets.

**Empty state**: "No interactions yet with [Name]." message when no linked entries exist.

---

## RootTabScreen (modified)

**File**: `app/lib/screens/root_tab_screen.dart`

**Changes**:
- `_screens`: `[TimelineScreen(), PeopleScreen()]`
- `_tabs`: Timeline (icon: `Icons.timeline_outlined`) + People (icon: `Icons.people_outline_rounded`)
- Remove: `weeklyReviewTasksProvider` watch, `_kReviewTabIndex` constant, `reviewBadgeCount` param on `_FloatingTabBar`
- Remove imports: `DayViewScreen`, `CollectionsScreen`, `SearchScreen`, `ReviewScreen`
- `_FloatingTabBar.reviewBadgeCount` parameter removed; `Badge` widget removed from tab buttons
