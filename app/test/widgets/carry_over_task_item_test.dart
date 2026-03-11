import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/widgets/carry_over_task_item.dart';

/// Returns a [Bullet] stub created exactly [daysAgo] days before now (UTC).
Bullet _stubBullet({required int daysAgo, String content = 'Write tests'}) {
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
      child: MaterialApp(
        home: Scaffold(body: child),
      ),
    );

void main() {
  group('CarryOverTaskItem — age badge', () {
    testWidgets('shows "3d" badge for a task created 3 days ago', (tester) async {
      final bullet = _stubBullet(daysAgo: 3);

      await tester.pumpWidget(_wrap(
        CarryOverTaskItem(bullet: bullet, onTap: () {}),
      ));

      await tester.pump();

      expect(find.text('3d'), findsOneWidget);
    });

    testWidgets('shows "7d" badge for a task created 7 days ago', (tester) async {
      final bullet = _stubBullet(daysAgo: 7);

      await tester.pumpWidget(_wrap(
        CarryOverTaskItem(bullet: bullet, onTap: () {}),
      ));

      await tester.pump();

      expect(find.text('7d'), findsOneWidget);
    });

    testWidgets('shows "1d" badge for a task created 1 day ago', (tester) async {
      final bullet = _stubBullet(daysAgo: 1);

      await tester.pumpWidget(_wrap(
        CarryOverTaskItem(bullet: bullet, onTap: () {}),
      ));

      await tester.pump();

      expect(find.text('1d'), findsOneWidget);
    });

    testWidgets('renders task content text', (tester) async {
      final bullet = _stubBullet(daysAgo: 2, content: 'Review pull request');

      await tester.pumpWidget(_wrap(
        CarryOverTaskItem(bullet: bullet, onTap: () {}),
      ));

      await tester.pump();

      expect(find.text('Review pull request'), findsOneWidget);
    });

    testWidgets('calls onTap when tapping the non-button area', (tester) async {
      var tapped = false;
      final bullet = _stubBullet(daysAgo: 2);

      await tester.pumpWidget(_wrap(
        CarryOverTaskItem(bullet: bullet, onTap: () => tapped = true),
      ));

      await tester.pump();
      await tester.tap(find.byType(InkWell).first);

      expect(tapped, isTrue);
    });
  });

  group('CarryOverTaskItem — action chips', () {
    testWidgets('shows Complete chip', (tester) async {
      final bullet = _stubBullet(daysAgo: 2);

      await tester.pumpWidget(_wrap(
        CarryOverTaskItem(bullet: bullet, onTap: () {}),
      ));

      await tester.pump();

      expect(find.text('Complete'), findsOneWidget);
    });

    testWidgets('shows Keep for Today chip', (tester) async {
      final bullet = _stubBullet(daysAgo: 2);

      await tester.pumpWidget(_wrap(
        CarryOverTaskItem(bullet: bullet, onTap: () {}),
      ));

      await tester.pump();

      expect(find.text('Keep for Today'), findsOneWidget);
    });

    testWidgets('shows Cancel chip', (tester) async {
      final bullet = _stubBullet(daysAgo: 2);

      await tester.pumpWidget(_wrap(
        CarryOverTaskItem(bullet: bullet, onTap: () {}),
      ));

      await tester.pump();

      expect(find.text('Cancel'), findsOneWidget);
    });
  });
}
