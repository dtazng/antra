import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:antra/models/daily_goal.dart';
import 'package:antra/models/suggestion.dart';
import 'package:antra/models/today_interaction.dart';
import 'package:antra/providers/day_view_provider.dart';
import 'package:antra/screens/day_view/day_view_screen.dart';

const _s1 = Suggestion(
  type: SuggestionType.reconnect,
  personId: 'p1',
  personName: 'Lisa',
  signalText: 'Last contact: 32 days ago',
  score: 1,
);

const _s2 = Suggestion(
  type: SuggestionType.birthday,
  personId: 'p2',
  personName: 'Anna',
  signalText: 'Birthday tomorrow 🎉',
  score: 3,
);

List<Override> _overrides({
  List<Suggestion> suggestions = const [_s1, _s2],
  DailyGoal goal = const DailyGoal(reached: 0),
  List<TodayInteraction> interactions = const [],
}) {
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  return [
    suggestionsFilteredProvider
        .overrideWith((ref) => Stream.value(suggestions)),
    dailyGoalProvider(today).overrideWith((ref) => Stream.value(goal)),
    todayInteractionsProvider(today).overrideWith((ref) => Stream.value(interactions)),
  ];
}

Widget _wrap(List<Override> overrides) => ProviderScope(
      overrides: overrides,
      child: const MaterialApp(home: DayViewScreen()),
    );

void main() {
  group('DayViewScreen', () {
    testWidgets('renders all 5 sections on load', (tester) async {
      await tester.pumpWidget(_wrap(_overrides()));
      await tester.pump();

      // Briefing section
      expect(find.textContaining('Good'), findsOneWidget);
      // Goal section
      expect(find.textContaining('0 / 3'), findsOneWidget);
      // Suggestion cards
      expect(find.text('Lisa'), findsOneWidget);
      expect(find.text('Anna'), findsOneWidget);
      // Timeline empty state
      expect(find.textContaining('No interactions logged'), findsOneWidget);
      // Quick log bar
      expect(find.text('Coffee'), findsOneWidget);
    });

    testWidgets('tapping a suggestion card expands it to show actions',
        (tester) async {
      await tester.pumpWidget(_wrap(_overrides()));
      await tester.pump();

      // Collapsed — action buttons not visible
      expect(find.text('Log meeting'), findsNothing);

      // Tap first card (Lisa = reconnect); pump through spring expand (280ms).
      await tester.tap(find.text('Lisa'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Log meeting'), findsOneWidget);

      // Tapping the same card again collapses it.
      await tester.tap(find.text('Lisa'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Log meeting'), findsNothing);
    });

    testWidgets('timeline shows interaction when provided', (tester) async {
      final now = DateTime.now();
      final interactions = [
        TodayInteraction(
          bulletId: 'b1',
          personId: 'p1',
          personName: 'Alex',
          content: '☕ Coffee with Alex',
          type: 'event',
          interactionLabel: 'Coffee',
          loggedAt: now,
        ),
      ];
      await tester.pumpWidget(_wrap(_overrides(interactions: interactions)));
      await tester.pump();
      expect(find.textContaining('Coffee'), findsWidgets);
    });

    testWidgets('goal completion state shown when reached >= target', (tester) async {
      await tester.pumpWidget(_wrap(_overrides(
        goal: const DailyGoal(reached: 3),
      )));
      await tester.pump();
      expect(find.textContaining('complete'), findsWidgets);
    });
  });
}
