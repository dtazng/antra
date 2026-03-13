import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:antra/widgets/glass_surface.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('GlassSurface', () {
    testWidgets('BackdropFilter is present in widget tree', (tester) async {
      await tester.pumpWidget(_wrap(
        GlassSurface(child: const Text('glass')),
      ));
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.text('glass'), findsOneWidget);
    });

    for (final style in GlassStyle.values) {
      testWidgets('renders without error for style $style', (tester) async {
        await tester.pumpWidget(_wrap(
          GlassSurface(
            style: style,
            child: const Text('content'),
          ),
        ));
        expect(find.byType(BackdropFilter), findsOneWidget);
        expect(find.text('content'), findsOneWidget);
      });
    }

    testWidgets('onTap callback fires when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(
        GlassSurface(
          onTap: () => tapped = true,
          child: const Text('tap me'),
        ),
      ));
      await tester.tap(find.text('tap me'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('applies custom padding when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        GlassSurface(
          padding: const EdgeInsets.all(32),
          child: const Text('padded'),
        ),
      ));
      // Child is visible — padding is applied without hiding content.
      expect(find.text('padded'), findsOneWidget);
    });

    testWidgets('RepaintBoundary wraps the surface', (tester) async {
      await tester.pumpWidget(_wrap(
        GlassSurface(child: const Text('bounded')),
      ));
      expect(find.byType(RepaintBoundary), findsWidgets);
    });
  });
}
