import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:antra/models/daily_goal.dart';
import 'package:antra/widgets/daily_goal_widget.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('DailyGoalWidget', () {
    testWidgets('0/3: shows 0 / 3 completed and empty progress bar', (tester) async {
      await tester.pumpWidget(wrap(
        const DailyGoalWidget(goal: DailyGoal(reached: 0)),
      ));
      expect(find.textContaining('0 / 3'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, closeTo(0.0, 0.001));
    });

    testWidgets('1/3: shows 1 / 3 completed', (tester) async {
      await tester.pumpWidget(wrap(
        const DailyGoalWidget(goal: DailyGoal(reached: 1)),
      ));
      expect(find.textContaining('1 / 3'), findsOneWidget);
    });

    testWidgets('2/3: progress bar value equals 2/3', (tester) async {
      await tester.pumpWidget(wrap(
        const DailyGoalWidget(goal: DailyGoal(reached: 2)),
      ));
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, closeTo(2 / 3, 0.001));
    });

    testWidgets('3/3 completed: shows completion message, no X/3 text', (tester) async {
      await tester.pumpWidget(wrap(
        const DailyGoalWidget(goal: DailyGoal(reached: 3)),
      ));
      expect(find.textContaining('complete'), findsWidgets);
      expect(find.textContaining('3 / 3'), findsNothing);
    });
  });
}
