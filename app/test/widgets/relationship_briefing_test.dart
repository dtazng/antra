import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:antra/models/suggestion.dart';
import 'package:antra/widgets/relationship_briefing.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  const s1 = Suggestion(
    type: SuggestionType.birthday,
    personId: 'p1',
    personName: 'Anna',
    signalText: 'Birthday tomorrow 🎉',
    score: 3,
  );
  const s2 = Suggestion(
    type: SuggestionType.reconnect,
    personId: 'p2',
    personName: 'David',
    signalText: 'Last contact: 28 days ago',
    score: 1,
  );
  const s3 = Suggestion(
    type: SuggestionType.followUp,
    personId: 'p3',
    personName: 'Lisa',
    signalText: 'Follow up needed',
    score: 2,
  );

  group('RelationshipBriefing', () {
    testWidgets('loading=true shows no suggestion text', (tester) async {
      await tester.pumpWidget(wrap(
        const RelationshipBriefing(suggestions: [], loading: true),
      ));
      expect(find.text('Birthday tomorrow 🎉'), findsNothing);
      expect(find.text('Last contact: 28 days ago'), findsNothing);
    });

    testWidgets('empty suggestions shows neutral message', (tester) async {
      await tester.pumpWidget(wrap(
        const RelationshipBriefing(suggestions: [], loading: false),
      ));
      expect(find.textContaining('looking good'), findsOneWidget);
    });

    testWidgets('3 suggestions renders 3 rows with signal text', (tester) async {
      await tester.pumpWidget(wrap(
        const RelationshipBriefing(
          suggestions: [s1, s2, s3],
          loading: false,
        ),
      ));
      expect(find.textContaining(s1.signalText), findsOneWidget);
      expect(find.textContaining(s2.signalText), findsOneWidget);
      expect(find.textContaining(s3.signalText), findsOneWidget);
    });

    testWidgets('4 suggestions renders 4 rows', (tester) async {
      const s4 = Suggestion(
        type: SuggestionType.memory,
        personId: 'p4',
        personName: 'Alex',
        signalText: 'You met Alex 1 year ago today',
        score: 1,
      );
      await tester.pumpWidget(wrap(
        const RelationshipBriefing(
          suggestions: [s1, s2, s3, s4],
          loading: false,
        ),
      ));
      expect(find.textContaining(s4.signalText), findsOneWidget);
    });

    testWidgets('birthday suggestion row contains person name', (tester) async {
      await tester.pumpWidget(wrap(
        const RelationshipBriefing(suggestions: [s1], loading: false),
      ));
      expect(find.textContaining('Anna'), findsWidgets);
    });

    testWidgets('non-empty suggestions shows header text', (tester) async {
      await tester.pumpWidget(wrap(
        const RelationshipBriefing(suggestions: [s1], loading: false),
      ));
      // Should show a greeting header
      expect(find.textContaining('Good'), findsOneWidget);
    });
  });
}
