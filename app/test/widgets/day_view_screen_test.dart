import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

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
  List<TodayInteraction> interactions = const [],
}) {
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  return [
    suggestionsFilteredProvider
        .overrideWith((ref) => Stream.value(suggestions)),
    todayInteractionsProvider(today)
        .overrideWith((ref) => Stream.value(interactions)),
  ];
}

Widget _wrap(List<Override> overrides) => ProviderScope(
      overrides: overrides,
      child: const MaterialApp(home: DayViewScreen()),
    );

void main() {
  group('DayViewScreen', () {
    testWidgets('renders suggestion cards and journal composer', (tester) async {
      await tester.pumpWidget(_wrap(_overrides()));
      await tester.pump();

      // Suggestion cards
      expect(find.text('Lisa'), findsOneWidget);
      expect(find.text('Anna'), findsOneWidget);
      // Journal composer hint
      expect(find.text('What happened today\u2026'), findsOneWidget);
      // No gamification elements
      expect(find.textContaining('0 / 3'), findsNothing);
      expect(find.textContaining('Reach out'), findsNothing);
      expect(find.text('Coffee'), findsNothing);
    });

    testWidgets('shows calm empty state when no suggestions', (tester) async {
      await tester.pumpWidget(_wrap(_overrides(suggestions: [])));
      await tester.pump();

      expect(
        find.text("Nothing to do \u2014 you're all caught up."),
        findsOneWidget,
      );
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
          type: 'note',
          loggedAt: now,
        ),
      ];
      await tester.pumpWidget(_wrap(_overrides(interactions: interactions)));
      await tester.pump();
      expect(find.textContaining('Coffee'), findsWidgets);
    });

    testWidgets('forward nav arrow hidden when today is selected',
        (tester) async {
      await tester.pumpWidget(_wrap(_overrides()));
      await tester.pump();

      // Right chevron should not be present when displaying today
      expect(
        find.byWidgetPredicate((w) =>
            w is Icon && w.icon == Icons.chevron_right_rounded),
        findsNothing,
      );
    });
  });
}
