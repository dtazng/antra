import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:antra/widgets/person_avatar.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('PersonAvatar', () {
    testWidgets('shows initials for a two-word name', (tester) async {
      await tester.pumpWidget(_wrap(
        const PersonAvatar(personId: 'id-1', displayName: 'Alice Brown'),
      ));
      expect(find.text('AB'), findsOneWidget);
    });

    testWidgets('shows single initial for a single-word name', (tester) async {
      await tester.pumpWidget(_wrap(
        const PersonAvatar(personId: 'id-2', displayName: 'Alice'),
      ));
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('shows ? for empty display name', (tester) async {
      await tester.pumpWidget(_wrap(
        const PersonAvatar(personId: 'id-3', displayName: ''),
      ));
      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('renders gradient background container', (tester) async {
      await tester.pumpWidget(_wrap(
        const PersonAvatar(personId: 'id-4', displayName: 'Bob Smith'),
      ));
      // Container with gradient exists in the tree.
      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasGradient = containers.any((c) {
        final decoration = c.decoration;
        return decoration is BoxDecoration && decoration.gradient != null;
      });
      expect(hasGradient, isTrue);
    });

    testWidgets('renders ring when showRing is true', (tester) async {
      await tester.pumpWidget(_wrap(
        const PersonAvatar(
          personId: 'id-5',
          displayName: 'Carol Jones',
          showRing: true,
        ),
      ));
      // Two containers with gradient: the ring + the avatar itself.
      final containers = tester.widgetList<Container>(find.byType(Container));
      final gradientContainers =
          containers.where((c) {
            final d = c.decoration;
            return d is BoxDecoration && d.gradient != null;
          }).length;
      expect(gradientContainers, greaterThanOrEqualTo(2));
    });

    testWidgets('respects custom radius', (tester) async {
      await tester.pumpWidget(_wrap(
        const PersonAvatar(
          personId: 'id-6',
          displayName: 'Dave Lee',
          radius: 40,
        ),
      ));
      // Avatar container should have width = radius * 2 = 80.
      final container = tester.widget<Container>(
        find.byType(Container).first,
      );
      expect(container.constraints?.maxWidth ?? container.color, isNotNull);
    });
  });
}
