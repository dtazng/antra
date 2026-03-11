# Developer Quickstart: Carried-Over Tasks and Quick-Action Cards

**Feature**: `005-task-carryover`
**Branch**: `005-task-carryover`
**Date**: 2026-03-11

---

## What This Feature Changes

This feature closes the gap between the existing skeleton implementation and the full spec. No schema migration is required. All changes are to existing files.

---

## Files to Change

### 1. `app/lib/database/daos/task_lifecycle_dao.dart`

**Change**: Update `watchCarryOverTasks` and `getCarryOverTasks` to use a date range instead of a fixed yesterday date.

**Before** (both methods):
```sql
WHERE dl.date = ?  -- yesterday only
AND b.created_at > ?  -- sevenDaysAgo
```

**After**:
```sql
WHERE dl.date >= ? AND dl.date < ?  -- sevenDaysAgo to today (exclusive)
AND b.type = 'task' AND b.status = 'open'
AND b.is_deleted = 0
AND (b.scheduled_date IS NULL OR b.scheduled_date <= ?)  -- today
ORDER BY b.created_at ASC
```

**Signature change**: Remove `yesterday` parameter; parameters become `(String sevenDaysAgo, String today)`.

---

### 2. `app/lib/providers/task_lifecycle_provider.dart`

**Change**: Update `carryOverTasksProvider` to pass `sevenDaysAgo` and `today` (remove `yesterday`):

```dart
yield* dao.watchCarryOverTasks(sevenDaysAgo, today);
```

---

### 3. `app/lib/widgets/carry_over_task_item.dart`

**Changes**:
1. Remove `onQuickAction` constructor parameter.
2. Add `ConsumerWidget` (needs `WidgetRef` for lifecycle service).
3. Add age badge ("Nd") in the card header row.
4. Add scrollable horizontal action chip row below content:
   - Complete (primary style)
   - Keep for Today (primary style)
   - Schedule (opens date picker)
   - Backlog
   - → Note (with confirmation dialog)
   - Cancel (destructive; shows undo snackbar)

Action implementations mirror those in `WeeklyReviewTaskItem` / `TaskQuickActionsSheet`. The `_today` getter uses `DateFormat('yyyy-MM-dd').format(DateTime.now().toLocal())`.

---

### 4. `app/lib/screens/daily_log/daily_log_screen.dart`

**Changes**:
1. Remove `onQuickAction` callback from `CarryOverTaskItem` usage (parameter no longer exists).
2. Rename section header from `_FromYesterdayHeader` → update its displayed text to `'Carried Over'`.

---

### 5. `app/lib/widgets/weekly_review_task_item.dart`

**Changes**:
1. Add `Complete` chip as first action (before "This Week").
2. Change age display from `"$days days old"` text to the compact `"${days}d"` badge format — matching `CarryOverTaskItem`.

---

### 6. `app/lib/screens/review/weekly_review_screen.dart`

**Changes**:
1. Move `_UnresolvedTasksSection()` to the top of the `SingleChildScrollView` column (above "Open Tasks" and "Events").
2. Replace `BulletsDao(db).migrateBullet(bullet.id, today)` in `_migrateTask` with `TaskLifecycleService.keepForToday(bullet.id, today)` to use the canonical lifecycle service.

---

### 7. `app/lib/screens/root_tab_screen.dart`

**Change**: Watch `weeklyReviewTasksProvider` and overlay a `Badge` on the Review tab's `NavigationDestination` icon when count > 0:

```dart
// Wrap the Review tab icon:
Badge(
  isLabelVisible: weeklyCount > 0,
  label: Text('$weeklyCount'),
  child: const Icon(Icons.auto_stories_outlined),
)
```

---

## Running the App

```bash
# From repo root
cd app
flutter pub get
dart run build_runner build --delete-conflicting-outputs  # if any generated files changed
flutter run -d "iPhone 16"
```

No `build_runner` run is needed unless Riverpod provider signatures change (they don't — only the internal stream changes).

---

## Testing

```bash
cd app && flutter test
```

**New tests to write** (see `tasks.md` for detailed task breakdown):
- `test/database/daos/task_lifecycle_dao_test.dart` — verify date-range carry-over query
- `test/widgets/carry_over_task_item_test.dart` — verify age badge, inline actions, onTap navigation
- `test/widgets/weekly_review_task_item_test.dart` — verify Complete action present

---

## Key Behaviour to Verify Manually

1. Create a task 3 days ago (set device clock back, create task, reset clock). Open today's log — task appears in "Carried Over" section with "3d" badge.
2. Tap "Complete" on a carried-over task card — card disappears immediately, no navigation.
3. Tap "Keep for Today" — card disappears from Carried Over, task appears in today's main log.
4. Create a task 8 days ago. Open today's log — task does NOT appear in Carried Over. Open Review tab — badge shows count ≥ 1. Open Weekly Review screen — task appears in "Needs Attention" section.
5. Tap "Complete" on a Weekly Review task — task removed from list.
6. Tap the non-button area of a carried-over task card — navigates to `TaskDetailScreen`.
