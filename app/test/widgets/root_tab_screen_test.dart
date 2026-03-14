import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:antra/screens/root_tab_screen.dart';

void main() {
  group('RootTabScreen — 2-tab navigation', () {
    testWidgets('renders Timeline and People tab icons', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: RootTabScreen()),
        ),
      );

      await tester.pump();

      // Both tab icons should be present
      expect(find.byIcon(Icons.timeline_outlined), findsOneWidget);
      expect(find.byIcon(Icons.people_outline_rounded), findsOneWidget);
    });

    testWidgets('does NOT show Badge widget (review badge removed)',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: RootTabScreen()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // No Badge widget — review tab and its badge were removed
      final badges = tester.widgetList<Badge>(find.byType(Badge)).toList();
      final visibleBadges =
          badges.where((b) => b.isLabelVisible ?? true).toList();
      expect(visibleBadges, isEmpty);
    });
  });
}
