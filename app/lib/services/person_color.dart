import 'dart:convert';

import 'package:flutter/material.dart';

/// The gradient identity assigned to a person.
class PersonIdentity {
  final Color gradientStart;
  final Color gradientEnd;
  final int paletteIndex;

  const PersonIdentity({
    required this.gradientStart,
    required this.gradientEnd,
    required this.paletteIndex,
  });

  LinearGradient get gradient => LinearGradient(
        colors: [gradientStart, gradientEnd],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}

/// Deterministically derives a [PersonIdentity] from a person's UUID string.
///
/// Uses a DJB2 hash of the UTF-8 encoded [personId] modulo 12 to select one
/// of 12 curated gradient pairs. Same input always produces the same output.
class PersonColorService {
  PersonColorService._();

  static const List<(Color, Color)> _palette = [
    (Color(0xFF7C3AED), Color(0xFF3B82F6)), // 0  Violet → Blue
    (Color(0xFFF97316), Color(0xFFEC4899)), // 1  Coral → Magenta
    (Color(0xFF14B8A6), Color(0xFF06B6D4)), // 2  Teal → Cyan
    (Color(0xFF8B5CF6), Color(0xFFD946EF)), // 3  Purple → Fuchsia
    (Color(0xFF6366F1), Color(0xFF7C3AED)), // 4  Indigo → Violet
    (Color(0xFF3B82F6), Color(0xFF6366F1)), // 5  Blue → Indigo
    (Color(0xFFF43F5E), Color(0xFFEC4899)), // 6  Rose → Pink
    (Color(0xFF06B6D4), Color(0xFF14B8A6)), // 7  Cyan → Teal
    (Color(0xFF10B981), Color(0xFF14B8A6)), // 8  Emerald → Teal
    (Color(0xFFD946EF), Color(0xFF8B5CF6)), // 9  Magenta → Purple
    (Color(0xFF2563EB), Color(0xFF06B6D4)), // 10 Electric Blue → Cyan
    (Color(0xFFF59E0B), Color(0xFFF97316)), // 11 Amber → Coral
  ];

  /// Returns the [PersonIdentity] for the given [personId].
  ///
  /// The result is deterministic: identical inputs always return identical
  /// outputs, regardless of session, device, or call order.
  static PersonIdentity fromId(String personId) {
    final bytes = utf8.encode(personId);
    int hash = 5381;
    for (final byte in bytes) {
      hash = ((hash << 5) + hash) ^ byte;
      // Keep within 32-bit signed range to match DJB2 behaviour on all platforms.
      hash = hash & 0x7FFFFFFF;
    }
    final index = hash % _palette.length;
    final (start, end) = _palette[index];
    return PersonIdentity(
      gradientStart: start,
      gradientEnd: end,
      paletteIndex: index,
    );
  }
}
