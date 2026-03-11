import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/providers/task_lifecycle_provider.dart';
import 'package:antra/screens/root_tab_screen.dart';

Bullet _stubBullet({String id = 'b1'}) {
  final ts = DateTime.now().toUtc().subtract(const Duration(days: 10)).toIso8601String();
  return Bullet(
    id: id,
    dayId: 'dl1',
    type: 'task',
    content: 'Old task',
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

void main() {
  group('RootTabScreen — Review tab badge', () {
    testWidgets('shows Badge on Review tab when weeklyReviewTasksProvider returns tasks',
        (tester) async {
      final bullet = _stubBullet();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            weeklyReviewTasksProvider.overrideWith(
              (ref) => Stream.value([bullet]),
            ),
          ],
          child: const MaterialApp(home: RootTabScreen()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // One of the Badge widgets should be visible (isLabelVisible = true)
      // with label '1'. All 5 tab buttons have Badge wrappers.
      final badges = tester.widgetList<Badge>(find.byType(Badge)).toList();
      final visibleBadges = badges.where((b) => b.isLabelVisible ?? true).toList();
      expect(visibleBadges, hasLength(1));
      // The count label should appear.
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('does NOT show Badge when weeklyReviewTasksProvider returns empty list',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            weeklyReviewTasksProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
          ],
          child: const MaterialApp(home: RootTabScreen()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Badge widget should either not exist or have isLabelVisible = false.
      final badges = tester.widgetList<Badge>(find.byType(Badge));
      final visibleBadges = badges.where((b) => b.isLabelVisible ?? true).toList();
      expect(visibleBadges, isEmpty);
    });
  });
}
