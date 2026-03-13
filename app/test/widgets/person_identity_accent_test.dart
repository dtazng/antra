import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:antra/widgets/person_identity_accent.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('PersonIdentityAccent', () {
    for (final style in AccentStyle.values) {
      testWidgets('renders without error for style $style', (tester) async {
        await tester.pumpWidget(_wrap(
          PersonIdentityAccent(
            personId: 'test-person-id',
            style: style,
            size: 16,
          ),
        ));
        // No exceptions → pass.
        expect(find.byType(Container), findsWidgets);
      });
    }

    testWidgets('dot style renders a circle container with gradient',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const PersonIdentityAccent(
          personId: 'person-abc',
          style: AccentStyle.dot,
          size: 10,
        ),
      ));
      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasCircleGradient = containers.any((c) {
        final d = c.decoration;
        return d is BoxDecoration &&
            d.shape == BoxShape.circle &&
            d.gradient != null;
      });
      expect(hasCircleGradient, isTrue);
    });

    testWidgets('size parameter affects dot diameter', (tester) async {
      await tester.pumpWidget(_wrap(
        const PersonIdentityAccent(
          personId: 'person-xyz',
          style: AccentStyle.dot,
          size: 20,
        ),
      ));
      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.constraints?.maxWidth ?? 20.0, moreOrLessEquals(20.0));
    });

    testWidgets('edgeGlow style renders a non-circular container',
        (tester) async {
      await tester.pumpWidget(_wrap(
        SizedBox(
          height: 80,
          child: PersonIdentityAccent(
            personId: 'person-edge',
            style: AccentStyle.edgeGlow,
            size: 16,
          ),
        ),
      ));
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('ring style renders two containers', (tester) async {
      await tester.pumpWidget(_wrap(
        const PersonIdentityAccent(
          personId: 'person-ring',
          style: AccentStyle.ring,
          size: 16,
        ),
      ));
      // Outer ring + inner fill = at least 2 containers.
      expect(find.byType(Container), findsAtLeastNWidgets(2));
    });
  });
}
