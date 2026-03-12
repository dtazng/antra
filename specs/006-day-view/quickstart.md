# Developer Quickstart: AI-style Day View

**Feature**: `006-day-view`
**Branch**: `006-day-view`
**Date**: 2026-03-11

---

## What This Feature Does

Replaces Tab 0 (`DailyLogScreen`) with a new `DayViewScreen` that acts as a relationship command center. It shows a daily briefing, goal progress, expandable suggestion cards, a quick interaction logger, and today's timeline — all on one screen, all without navigating away.

No schema migration required (existing v3 schema is sufficient).

---

## Files to Create

### 1. `app/lib/services/suggestion_engine.dart` (new)

Pure Dart class. No Flutter imports. Converts a `List<PeopleData>` into a ranked `List<Suggestion>`.

```dart
class SuggestionEngine {
  // Returns up to 4 suggestions, scored and ranked.
  // Excludes people interacted with today (personId in todayPersonIds).
  List<Suggestion> compute(
    List<PeopleData> people,
    String today,               // 'YYYY-MM-DD'
    Set<String> todayPersonIds, // exclude these
  ) { ... }
}
```

Scoring:
- Birthday within 7 days: 3 points
- `needsFollowUp == 1`: 2 points
- Last contact 90+ days ago: 2 points
- Last contact 30–89 days ago: 1 point
- First interaction N years ago ±3 days: 1 point (memory)
- Sort by score desc, then name; cap at 4.

### 2. `app/lib/models/suggestion.dart` (new)

```dart
enum SuggestionType { reconnect, birthday, followUp, memory }

class Suggestion {
  final SuggestionType type;
  final String personId;
  final String personName;
  final String? personNotes;
  final String signalText;    // e.g. "Last contact: 32 days ago"
  final int score;
}
```

### 3. `app/lib/models/today_interaction.dart` (new)

```dart
class TodayInteraction {
  final String bulletId;
  final String personId;
  final String personName;
  final String interactionLabel; // "Coffee", "Call", "Message", "Note"
  final DateTime loggedAt;
}
```

### 4. `app/lib/models/daily_goal.dart` (new)

```dart
class DailyGoal {
  final int target;    // Always 3 for MVP
  final int reached;   // Distinct people interacted with today
  bool get completed => reached >= target;
}
```

### 5. `app/lib/providers/day_view_provider.dart` (new)

```dart
// Emits ranked Suggestion list (0–4 items). Re-emits when People data changes.
@riverpod
Stream<List<Suggestion>> suggestions(SuggestionsRef ref) async* { ... }

// Emits DailyGoal recomputed on every new bullet_person_link for today.
@riverpod
Stream<DailyGoal> dailyGoal(DailyGoalRef ref) async* { ... }

// Emits today's person-linked bullets as TodayInteraction list, newest first.
@riverpod
Stream<List<TodayInteraction>> todayInteractions(TodayInteractionsRef ref) async* { ... }

// Notifier: tracks expanded card ID + dismissed suggestion person IDs.
@riverpod
class SuggestionNotifier extends _$SuggestionNotifier {
  void expand(String personId) { ... }    // collapses others
  void collapse() { ... }
  void dismiss(String personId) { ... }   // removes from feed
}
```

### 6. `app/lib/screens/day_view/day_view_screen.dart` (new)

```dart
class DayViewScreen extends ConsumerStatefulWidget { ... }
```

Layout (scrollable body, `QuickLogBar` pinned at bottom):
1. `RelationshipBriefing(suggestions: ..., loading: ...)`
2. `DailyGoalWidget(goal: ...)`
3. List of `SuggestionCard(suggestion: ..., expanded: ..., onTap: ..., onAction: ..., onDismiss: ...)`
4. `TodayInteractionTimeline(interactions: ..., onTap: ...)`
5. `QuickLogBar(onInteractionLogged: ...)` — pinned, sits above floating tab bar

### 7. `app/lib/widgets/relationship_briefing.dart` (new)

Stateless widget. Takes `List<Suggestion>` + `bool loading`. Renders the top briefing section.

### 8. `app/lib/widgets/daily_goal_widget.dart` (new)

Stateless widget. Takes `DailyGoal`. Shows progress bar or completion message.

### 9. `app/lib/widgets/suggestion_card.dart` (new)

ConsumerWidget. Uses `AnimatedSize` for smooth expand/collapse. Card header always visible; expanded content appears below with `AnimatedCrossFade`.

### 10. `app/lib/widgets/quick_log_bar.dart` (new)

ConsumerStatefulWidget. The 4-icon bar pinned to bottom. Tapping a type opens `PersonPickerSheet` (already exists at `app/lib/screens/people/person_picker_sheet.dart`).

### 11. `app/lib/widgets/today_timeline.dart` (new)

Stateless widget. Takes `List<TodayInteraction>`. Renders reverse-chronological list.

---

## Files to Modify

### `app/lib/screens/root_tab_screen.dart`

Replace `DailyLogScreen()` at index 0 with `DayViewScreen()`:

```dart
static const _screens = <Widget>[
  DayViewScreen(),   // was DailyLogScreen()
  PeopleScreen(),
  CollectionsScreen(),
  SearchScreen(),
  ReviewScreen(),
];
```

Update tab icon/label for index 0 if needed (e.g., change from "Log" to "Today" or keep "Log").

---

## Running After Implementation

```bash
# Generate Riverpod providers for new providers
cd app && dart run build_runner build --delete-conflicting-outputs

# Run all tests
cd app && flutter test

# Launch on simulator
flutter run -d "iPhone 16"
```

---

## Key Behaviors to Verify Manually

1. **Briefing generation**: Add a contact with a birthday tomorrow. Open Day View → briefing shows "{name} has a birthday tomorrow."
2. **Reconnect card**: Add a contact with `lastInteractionAt` = 35 days ago. Open Day View → a "Reconnect" card appears for that contact with signal "Last contact: 35 days ago."
3. **Card expand/collapse**: Tap a suggestion card → expands with animation showing notes and actions. Tap another → first collapses, second expands. Only one open at a time.
4. **Quick Log (3 taps)**: Tap ☕ → tap a contact → tap Save. Interaction should appear in today timeline immediately. Goal progress should increment.
5. **Goal completion**: Log 3 interactions with 3 different people → completion message "Daily relationships complete ✓" appears.
6. **Card dismissal after action**: Tap "Log meeting" on a suggestion card → brief success indicator, then card disappears from feed.
7. **Daily goal count from interaction card**: Taking "Log meeting" action on a suggestion card increments the goal (same as Quick Log).
8. **Empty states**: Create a fresh app install with no contacts → briefing shows neutral message, suggestion feed shows empty state, timeline shows "No interactions logged yet today."

---

## Testing Strategy

Unit tests (no Flutter, no DB):
- `SuggestionEngine`: test scoring algorithm (birthday wins over reconnect, cap at 4, exclusion of today's contacts, empty input).

Widget tests (Flutter, Riverpod overrides):
- `RelationshipBriefing`: empty state, 4 suggestions, loading state.
- `DailyGoalWidget`: 0/3, 1/3, 3/3 (completed).
- `SuggestionCard`: collapsed/expanded toggle, action tap callback, birthday actions, reconnect actions.
- `QuickLogBar`: 4 types visible, type selection, person selection calls save.
- `TodayInteractionTimeline`: empty state, 3 entries in reverse order, tap callback.
- `DayViewScreen` (integration): log via QuickLogBar → timeline updates + goal increments.
