import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:intl/intl.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/providers/bullets_provider.dart';
import 'package:antra/providers/reviews_provider.dart';
import 'package:antra/providers/task_lifecycle_provider.dart';
import 'package:antra/screens/daily_log/daily_log_screen.dart';

/// Builds a [Bullet] stub with the minimum fields needed for tests.
Bullet _stubBullet({
  String id = 'b1',
  String content = 'Finish report',
  String? createdAt,
}) {
  final ts =
      createdAt ?? DateTime.now().toUtc().subtract(const Duration(days: 3)).toIso8601String();
  return Bullet(
    id: id,
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

List<Override> _baseOverrides(List<Bullet> carryOverTasks) {
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  return [
    bulletsForDayProvider(today).overrideWith((ref) => Stream.value([])),
    allReviewsProvider.overrideWith((ref) => Stream.value([])),
    carryOverTasksProvider.overrideWith((ref) => Stream.value(carryOverTasks)),
  ];
}

void main() {
  group('DailyLogScreen — CARRIED OVER section', () {
    testWidgets('shows "CARRIED OVER" header when carryOverTasksProvider returns tasks',
        (tester) async {
      final bullet = _stubBullet();

      await tester.pumpWidget(
        ProviderScope(
          overrides: _baseOverrides([bullet]),
          child: const MaterialApp(home: DailyLogScreen()),
        ),
      );

      // Let the async providers settle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('CARRIED OVER'), findsOneWidget);
    });

    testWidgets('does NOT show "CARRIED OVER" header when provider returns empty list',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _baseOverrides([]),
          child: const MaterialApp(home: DailyLogScreen()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('CARRIED OVER'), findsNothing);
    });

    testWidgets('shows count badge next to "CARRIED OVER" header', (tester) async {
      final bullets = [_stubBullet(id: 'b1'), _stubBullet(id: 'b2', content: 'Other task')];

      await tester.pumpWidget(
        ProviderScope(
          overrides: _baseOverrides(bullets),
          child: const MaterialApp(home: DailyLogScreen()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Count badge shows '2' for two tasks.
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('shows task content for each carry-over task', (tester) async {
      final bullet = _stubBullet(content: 'Buy groceries');

      await tester.pumpWidget(
        ProviderScope(
          overrides: _baseOverrides([bullet]),
          child: const MaterialApp(home: DailyLogScreen()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Buy groceries'), findsOneWidget);
    });
  });
}
