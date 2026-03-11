import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/widgets/weekly_review_task_item.dart';

Bullet _stubBullet({required int daysAgo, String content = 'Old task'}) {
  final ts = DateTime.now().toUtc().subtract(Duration(days: daysAgo)).toIso8601String();
  return Bullet(
    id: 'b1',
    dayId: 'dl1',
    type: 'task',
    content: content,
    status: 'open',
    position: 0,
    migratedToId: null,
    encryptionEnabled: 0,
    createdAt: ts,
    updatedAt: ts,
    syncId: null,
    deviceId: 'local',
    isDeleted: 0,
    scheduledDate: null,
    carryOverCount: 0,
    completedAt: null,
    canceledAt: null,
  );
}

Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  group('WeeklyReviewTaskItem — Complete chip', () {
    testWidgets('renders "Complete" as the first action chip', (tester) async {
      final bullet = _stubBullet(daysAgo: 10);

      await tester.pumpWidget(_wrap(WeeklyReviewTaskItem(bullet: bullet)));
      await tester.pump();

      expect(find.text('Complete'), findsOneWidget);
    });

    testWidgets('renders existing action chips alongside Complete', (tester) async {
      final bullet = _stubBullet(daysAgo: 10);

      await tester.pumpWidget(_wrap(WeeklyReviewTaskItem(bullet: bullet)));
      await tester.pump();

      // All required actions must be present.
      expect(find.text('Complete'), findsOneWidget);
      expect(find.text('This Week'), findsOneWidget);
      expect(find.text('Schedule'), findsOneWidget);
      expect(find.text('Backlog'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });
  });

  group('WeeklyReviewTaskItem — age badge format', () {
    testWidgets('shows compact "Nd" badge instead of verbose "N days old" text',
        (tester) async {
      final bullet = _stubBullet(daysAgo: 10);

      await tester.pumpWidget(_wrap(WeeklyReviewTaskItem(bullet: bullet)));
      await tester.pump();

      // Compact badge should be present.
      expect(find.text('10d'), findsOneWidget);

      // Verbose format must NOT be present.
      expect(find.textContaining('days old'), findsNothing);
    });

    testWidgets('shows "8d" badge for a task created 8 days ago', (tester) async {
      final bullet = _stubBullet(daysAgo: 8);

      await tester.pumpWidget(_wrap(WeeklyReviewTaskItem(bullet: bullet)));
      await tester.pump();

      expect(find.text('8d'), findsOneWidget);
    });
  });
}
