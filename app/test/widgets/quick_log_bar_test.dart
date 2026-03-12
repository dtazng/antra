import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:antra/widgets/quick_log_bar.dart';

// QuickLogBar uses showModalBottomSheet internally for person picking.
// We test only the idle state here (provider-free); the full flow is covered
// by the DayViewScreen integration test.

void main() {
  Widget wrap(Widget child) => ProviderScope(
        child: MaterialApp(home: Scaffold(body: child)),
      );

  group('QuickLogBar', () {
    testWidgets('idle: 4 type icons visible', (tester) async {
      await tester.pumpWidget(wrap(
        QuickLogBar(date: '2026-03-12', onInteractionLogged: (_) {}),
      ));
      expect(find.text('Coffee'), findsOneWidget);
      expect(find.text('Call'), findsOneWidget);
      expect(find.text('Message'), findsOneWidget);
      expect(find.text('Note'), findsOneWidget);
    });

    testWidgets('idle: emoji icons visible', (tester) async {
      await tester.pumpWidget(wrap(
        QuickLogBar(date: '2026-03-12', onInteractionLogged: (_) {}),
      ));
      expect(find.text('☕'), findsOneWidget);
      expect(find.text('📞'), findsOneWidget);
      expect(find.text('✉️'), findsOneWidget);
      expect(find.text('✍️'), findsOneWidget);
    });

    testWidgets('idle: no Save button visible', (tester) async {
      await tester.pumpWidget(wrap(
        QuickLogBar(date: '2026-03-12', onInteractionLogged: (_) {}),
      ));
      expect(find.text('Save'), findsNothing);
    });
  });
}
