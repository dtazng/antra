import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:antra/models/today_interaction.dart';
import 'package:antra/widgets/today_timeline.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  final now = DateTime.now();

  TodayInteraction _interaction({
    required String bulletId,
    required String personName,
    required String label,
    required DateTime loggedAt,
    String content = '',
  }) {
    return TodayInteraction(
      bulletId: bulletId,
      personId: 'p-$bulletId',
      personName: personName,
      content: content,
      type: 'event',
      interactionLabel: label,
      loggedAt: loggedAt,
    );
  }

  group('TodayInteractionTimeline', () {
    testWidgets('empty list shows empty-state message', (tester) async {
      await tester.pumpWidget(wrap(
        TodayInteractionTimeline(interactions: const [], onTap: (_) {}),
      ));
      expect(find.textContaining('No interactions logged yet today'), findsOneWidget);
    });

    testWidgets('3 interactions renders 3 entries', (tester) async {
      final interactions = [
        _interaction(
          bulletId: 'b1',
          personName: 'Alex',
          label: 'Coffee',
          loggedAt: now.subtract(const Duration(hours: 1)),
        ),
        _interaction(
          bulletId: 'b2',
          personName: 'Sarah',
          label: 'Call',
          loggedAt: now.subtract(const Duration(hours: 2)),
        ),
        _interaction(
          bulletId: 'b3',
          personName: 'Mark',
          label: 'Message',
          loggedAt: now.subtract(const Duration(hours: 3)),
        ),
      ];
      await tester.pumpWidget(wrap(
        TodayInteractionTimeline(interactions: interactions, onTap: (_) {}),
      ));
      expect(find.textContaining('Alex'), findsOneWidget);
      expect(find.textContaining('Sarah'), findsOneWidget);
      expect(find.textContaining('Mark'), findsOneWidget);
    });

    testWidgets('tapping an entry calls onTap with correct bulletId', (tester) async {
      String? tappedId;
      final interactions = [
        _interaction(
          bulletId: 'bullet-42',
          personName: 'Alex',
          label: 'Coffee',
          loggedAt: now,
        ),
      ];
      await tester.pumpWidget(wrap(
        TodayInteractionTimeline(
          interactions: interactions,
          onTap: (id) => tappedId = id,
        ),
      ));
      await tester.tap(find.textContaining('Alex'));
      expect(tappedId, 'bullet-42');
    });

    testWidgets('Coffee interaction shows Coffee label', (tester) async {
      final interactions = [
        _interaction(
          bulletId: 'b1',
          personName: 'Alex',
          label: 'Coffee',
          loggedAt: now,
        ),
      ];
      await tester.pumpWidget(wrap(
        TodayInteractionTimeline(interactions: interactions, onTap: (_) {}),
      ));
      expect(find.textContaining('Coffee'), findsOneWidget);
    });
  });
}
