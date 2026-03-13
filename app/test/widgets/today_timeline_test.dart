import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:antra/models/today_interaction.dart';
import 'package:antra/widgets/today_timeline.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  final now = DateTime.now();

  TodayInteraction _interaction({
    required String bulletId,
    String? personId,
    String? personName,
    required String content,
    String type = 'note',
    required DateTime loggedAt,
  }) {
    return TodayInteraction(
      bulletId: bulletId,
      personId: personId,
      personName: personName,
      content: content,
      type: type,
      loggedAt: loggedAt,
    );
  }

  group('TodayInteractionTimeline', () {
    testWidgets('empty list shows empty-state message', (tester) async {
      await tester.pumpWidget(wrap(
        TodayInteractionTimeline(interactions: const [], onTap: (_) {}, onDelete: (_) {}),
      ));
      expect(find.textContaining('Nothing logged yet today'), findsOneWidget);
    });

    testWidgets('3 entries renders 3 entries', (tester) async {
      final interactions = [
        _interaction(
          bulletId: 'b1',
          personId: 'p1',
          personName: 'Alex',
          content: 'Coffee with Alex',
          loggedAt: now.subtract(const Duration(hours: 1)),
        ),
        _interaction(
          bulletId: 'b2',
          content: 'Picked up groceries',
          loggedAt: now.subtract(const Duration(hours: 2)),
        ),
        _interaction(
          bulletId: 'b3',
          content: 'Review PR',
          type: 'task',
          loggedAt: now.subtract(const Duration(hours: 3)),
        ),
      ];
      await tester.pumpWidget(wrap(
        TodayInteractionTimeline(interactions: interactions, onTap: (_) {}, onDelete: (_) {}),
      ));
      expect(find.textContaining('Coffee with Alex'), findsOneWidget);
      expect(find.textContaining('Picked up groceries'), findsOneWidget);
      expect(find.textContaining('Review PR'), findsOneWidget);
    });

    testWidgets('tapping an entry calls onTap with correct bulletId',
        (tester) async {
      String? tappedId;
      final interactions = [
        _interaction(
          bulletId: 'bullet-42',
          personId: 'p1',
          personName: 'Alex',
          content: 'Coffee with Alex',
          loggedAt: now,
        ),
      ];
      await tester.pumpWidget(wrap(
        TodayInteractionTimeline(
          interactions: interactions,
          onTap: (id) => tappedId = id,
          onDelete: (_) {},
        ),
      ));
      await tester.tap(find.textContaining('Coffee with Alex'));
      expect(tappedId, 'bullet-42');
    });

    testWidgets('entry content is shown directly', (tester) async {
      final interactions = [
        _interaction(
          bulletId: 'b1',
          content: 'Met Alice for coffee',
          loggedAt: now,
        ),
      ];
      await tester.pumpWidget(wrap(
        TodayInteractionTimeline(interactions: interactions, onTap: (_) {}, onDelete: (_) {}),
      ));
      expect(find.textContaining('Met Alice for coffee'), findsOneWidget);
    });
  });
}
