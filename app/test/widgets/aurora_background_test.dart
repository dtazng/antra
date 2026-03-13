import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:antra/widgets/aurora_background.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('AuroraBackground', () {
    testWidgets('renders CustomPaint in the widget tree', (tester) async {
      await tester.pumpWidget(_wrap(
        AuroraBackground(
          variant: AuroraVariant.dayView,
          child: const Text('content'),
        ),
      ));
      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.text('content'), findsOneWidget);
    });

    testWidgets('renders static when disableAnimations is true', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: _wrap(
            AuroraBackground(
              variant: AuroraVariant.dayView,
              child: const Text('static'),
            ),
          ),
        ),
      );
      await tester.pump();
      // Should still render without errors.
      expect(find.text('static'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    for (final variant in AuroraVariant.values) {
      testWidgets('renders without error for variant $variant', (tester) async {
        await tester.pumpWidget(_wrap(
          AuroraBackground(
            variant: variant,
            child: const SizedBox.expand(),
          ),
        ));
        await tester.pump(const Duration(seconds: 1));
        // Expect no exceptions and that CustomPaint is present.
        expect(find.byType(CustomPaint), findsWidgets);
      });
    }
  });
}
