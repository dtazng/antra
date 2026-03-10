# Contract: UI Screens

**Type**: UI interaction contracts for the three screens in this feature

---

## Screen 1: Today Screen (modified DailyLogScreen)

**File**: `app/lib/screens/daily_log/daily_log_screen.dart`

### Layout
```
DailyLogScreen
├── AppBar (date navigator)
├── Body: Column
│   ├── [optional] WeeklyReviewBanner (if weekly review tasks exist)
│   ├── Expanded: ListView
│   │   ├── Section: Today's entries (existing)
│   │   └── Section: "From Yesterday" (new, only shown when carry-over tasks exist)
│   │       ├── SectionHeader: "From Yesterday" with count badge
│   │       └── CarryOverTaskItem × N
│   └── BulletCaptureBar (existing)
```

### CarryOverTaskItem interaction contract
- **Tap**: Opens TaskDetailScreen
- **Long press** OR **swipe right**: Opens TaskQuickActionsSheet
- **Shows**: carry-over count indicator if `carry_over_count > 0`
- **Shows**: task content, carry-over badge ("↻" or migration bullet symbol)

### TaskQuickActionsSheet (bottom sheet)
Actions displayed in order:
1. ✓ Mark Complete → `TaskLifecycleService.completeTask()`
2. → Keep for Today → `TaskLifecycleService.keepForToday()`
3. 📅 Schedule → date picker → `TaskLifecycleService.scheduleTask()`
4. 📦 Move to Backlog → `TaskLifecycleService.moveToBacklog()`
5. 🗒️ Convert to Note → `TaskLifecycleService.convertToNote()` (with confirmation)
6. ✕ Cancel Task → `TaskLifecycleService.cancelTask()` + Undo snackbar (3 second window)

**No forms**: All actions except "Schedule" execute immediately. Schedule shows a `showDatePicker`.

---

## Screen 2: TaskDetailScreen (new)

**File**: `app/lib/screens/daily_log/task_detail_screen.dart`

### Layout
```
TaskDetailScreen
├── AppBar: task type icon + "Task Detail" + close button
├── Body: SingleChildScrollView
│   ├── ContentSection: task content text (editable on tap)
│   ├── StatusChip: current state + carry-over count (if > 0, highlighted if >= 3)
│   ├── ScheduledDateRow: (if scheduled_date set) date + clear button
│   ├── LifecycleHistorySection: ordered list of events
│   │   └── EventRow × N: icon + label + date
│   └── ActionsSection: action buttons (same set as quick actions sheet)
```

### Data contract (input)
```dart
TaskDetailScreen({required String bulletId})
```
Loads task + events reactively via Riverpod provider.

### Carry-over count display
- `carry_over_count == 0`: not shown
- `carry_over_count 1–2`: shown in gray ("Carried over 2×")
- `carry_over_count >= 3`: shown in amber/warning color ("Carried over 3× — consider resolving")

### Event icons
| Event Type | Icon |
|------------|------|
| `created` | ✦ (spark) |
| `carried_over` | ↻ |
| `kept_for_today` | → |
| `scheduled` | 📅 |
| `moved_to_backlog` | 📦 |
| `reactivated` | ↺ |
| `entered_weekly_review` | 🔍 |
| `completed` | ✓ |
| `canceled` | ✕ |
| `converted_to_note` | 🗒️ |

---

## Screen 3: WeeklyReviewScreen (modified)

**File**: `app/lib/screens/review/weekly_review_screen.dart`

The existing screen handles structured reviews. This feature adds a new "Unresolved Tasks" section to it.

### Layout addition
```
WeeklyReviewScreen
├── [existing weekly review prompts]
└── UnresolvedTasksSection (new)
    ├── Header: "Needs Attention" + count
    ├── Subtitle: "Tasks older than 7 days"
    └── WeeklyReviewTaskItem × N
        ├── task content
        ├── age indicator ("12 days old")
        ├── carry-over count (if > 0)
        └── action buttons row: [This Week] [Schedule] [Backlog] [Cancel] [→ Note]
```

### WeeklyReviewTaskItem action contract
| Button | Action |
|--------|--------|
| This Week | `TaskLifecycleService.moveToThisWeek()` → item removed from list |
| Schedule | date picker → `TaskLifecycleService.scheduleTask()` → removed |
| Backlog | `TaskLifecycleService.moveToBacklog()` → removed |
| Cancel | `TaskLifecycleService.cancelTask()` + undo snackbar → removed |
| → Note | `TaskLifecycleService.convertToNote()` → removed |

### Empty state
When no tasks are eligible: "Nothing to review — you're all caught up." with a checkmark icon.
