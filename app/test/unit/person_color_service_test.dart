import 'package:flutter_test/flutter_test.dart';

import 'package:antra/services/person_color.dart';

void main() {
  group('PersonColorService.fromId', () {
    test('returns same identity for same UUID across 100 calls', () {
      const id = '123e4567-e89b-12d3-a456-426614174000';
      final first = PersonColorService.fromId(id);
      for (var i = 0; i < 99; i++) {
        final result = PersonColorService.fromId(id);
        expect(result.paletteIndex, first.paletteIndex);
        expect(result.gradientStart.toARGB32(), first.gradientStart.toARGB32());
        expect(result.gradientEnd.toARGB32(), first.gradientEnd.toARGB32());
      }
    });

    test('different UUIDs can produce different palette indices', () {
      final indices = <int>{};
      final uuids = [
        'aaa00000-0000-0000-0000-000000000000',
        'bbb00000-0000-0000-0000-000000000000',
        'ccc00000-0000-0000-0000-000000000000',
        'ddd00000-0000-0000-0000-000000000000',
        'eee00000-0000-0000-0000-000000000000',
        'fff00000-0000-0000-0000-000000000000',
      ];
      for (final id in uuids) {
        indices.add(PersonColorService.fromId(id).paletteIndex);
      }
      // At least 2 distinct indices among 6 different UUIDs.
      expect(indices.length, greaterThan(1));
    });

    test('paletteIndex is always in 0..11', () {
      final ids = List.generate(50, (i) => 'person-$i-id-value');
      for (final id in ids) {
        final identity = PersonColorService.fromId(id);
        expect(identity.paletteIndex, inInclusiveRange(0, 11));
      }
    });

    test('does not throw on empty string', () {
      expect(() => PersonColorService.fromId(''), returnsNormally);
      final identity = PersonColorService.fromId('');
      expect(identity.paletteIndex, inInclusiveRange(0, 11));
    });

    test('gradient covers all 12 palette entries across varied inputs', () {
      // Generate enough inputs to hit all 12 entries with high probability.
      final indices = <int>{};
      for (var i = 0; i < 500; i++) {
        final id = 'test-person-identifier-$i';
        indices.add(PersonColorService.fromId(id).paletteIndex);
      }
      expect(indices.length, 12,
          reason: 'All 12 palette entries should be reachable');
    });

    test('PersonIdentity.gradient returns a LinearGradient', () {
      final identity = PersonColorService.fromId('any-id');
      final gradient = identity.gradient;
      expect(gradient.colors.length, 2);
      expect(gradient.colors[0].toARGB32(), identity.gradientStart.toARGB32());
      expect(gradient.colors[1].toARGB32(), identity.gradientEnd.toARGB32());
    });
  });
}
