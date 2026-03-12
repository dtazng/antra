import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:antra/models/suggestion.dart';
import 'package:antra/widgets/suggestion_card.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  const reconnect = Suggestion(
    type: SuggestionType.reconnect,
    personId: 'p1',
    personName: 'Lisa',
    signalText: 'Last contact: 32 days ago',
    score: 1,
  );

  const birthday = Suggestion(
    type: SuggestionType.birthday,
    personId: 'p2',
    personName: 'Anna',
    signalText: 'Birthday tomorrow 🎉',
    score: 3,
  );

  const withNotes = Suggestion(
    type: SuggestionType.reconnect,
    personId: 'p3',
    personName: 'Bob',
    signalText: 'Last contact: 45 days ago',
    score: 1,
    personNotes: 'Met at conference',
  );

  const noNotes = Suggestion(
    type: SuggestionType.reconnect,
    personId: 'p4',
    personName: 'Carol',
    signalText: 'Last contact: 50 days ago',
    score: 1,
  );

  group('SuggestionCard', () {
    testWidgets('collapsed: action buttons NOT in widget tree', (tester) async {
      await tester.pumpWidget(wrap(SuggestionCard(
        suggestion: reconnect,
        expanded: false,
        onTap: () {},
        onAction: (_) {},
        onDismiss: () {},
      )));
      expect(find.textContaining('Message'), findsNothing);
      expect(find.textContaining('Log meeting'), findsNothing);
    });

    testWidgets('expanded: action buttons ARE in widget tree', (tester) async {
      await tester.pumpWidget(wrap(SuggestionCard(
        suggestion: reconnect,
        expanded: true,
        onTap: () {},
        onAction: (_) {},
        onDismiss: () {},
      )));
      await tester.pumpAndSettle();
      expect(find.textContaining('Message'), findsOneWidget);
      expect(find.textContaining('Log meeting'), findsOneWidget);
    });

    testWidgets('collapsed tap calls onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(SuggestionCard(
        suggestion: reconnect,
        expanded: false,
        onTap: () => tapped = true,
        onAction: (_) {},
        onDismiss: () {},
      )));
      await tester.tap(find.text('Lisa'));
      expect(tapped, isTrue);
    });

    testWidgets('reconnect expanded shows Message, Call, Log meeting', (tester) async {
      await tester.pumpWidget(wrap(SuggestionCard(
        suggestion: reconnect,
        expanded: true,
        onTap: () {},
        onAction: (_) {},
        onDismiss: () {},
      )));
      await tester.pumpAndSettle();
      expect(find.textContaining('Message'), findsOneWidget);
      expect(find.textContaining('Call'), findsOneWidget);
      expect(find.textContaining('Log meeting'), findsOneWidget);
    });

    testWidgets('birthday expanded shows Send greeting, Log call', (tester) async {
      await tester.pumpWidget(wrap(SuggestionCard(
        suggestion: birthday,
        expanded: true,
        onTap: () {},
        onAction: (_) {},
        onDismiss: () {},
      )));
      await tester.pumpAndSettle();
      expect(find.textContaining('Send greeting'), findsOneWidget);
      expect(find.textContaining('Log call'), findsOneWidget);
    });

    testWidgets('expanded Log meeting tap calls onAction with logMeeting', (tester) async {
      SuggestionAction? received;
      await tester.pumpWidget(wrap(SuggestionCard(
        suggestion: reconnect,
        expanded: true,
        onTap: () {},
        onAction: (a) => received = a,
        onDismiss: () {},
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Log meeting'));
      expect(received, SuggestionAction.logMeeting);
    });

    testWidgets('null personNotes: notes section absent in expanded view', (tester) async {
      await tester.pumpWidget(wrap(SuggestionCard(
        suggestion: noNotes,
        expanded: true,
        onTap: () {},
        onAction: (_) {},
        onDismiss: () {},
      )));
      await tester.pumpAndSettle();
      expect(find.text('Notes'), findsNothing);
    });

    testWidgets('non-null personNotes: notes section present in expanded view', (tester) async {
      await tester.pumpWidget(wrap(SuggestionCard(
        suggestion: withNotes,
        expanded: true,
        onTap: () {},
        onAction: (_) {},
        onDismiss: () {},
      )));
      await tester.pumpAndSettle();
      expect(find.textContaining('Met at conference'), findsOneWidget);
    });
  });
}
