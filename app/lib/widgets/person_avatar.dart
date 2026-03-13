import 'package:flutter/material.dart';

import 'package:antra/services/person_color.dart';
import 'package:antra/theme/app_theme.dart';

/// Renders a person's avatar using their deterministic identity gradient.
///
/// Replaces `CircleAvatar` wherever a person's avatar is shown. The gradient
/// is derived synchronously via [PersonColorService.fromId] and is always
/// consistent for the same [personId].
///
/// Set [showRing] to true in profile headers to display a 2px annular
/// gradient border around the avatar.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({
    super.key,
    required this.personId,
    required this.displayName,
    this.radius = AntraRadius.avatar,
    this.showRing = false,
  });

  final String personId;
  final String displayName;
  final double radius;
  final bool showRing;

  @override
  Widget build(BuildContext context) {
    final identity = PersonColorService.fromId(personId);
    final initials = _initials(displayName);

    Widget avatar = Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: identity.gradient,
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: radius * 0.72,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );

    if (showRing) {
      avatar = Container(
        width: radius * 2 + 6,
        height: radius * 2 + 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              identity.gradientStart.withValues(alpha: 0.8),
              identity.gradientEnd.withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: avatar,
        ),
      );
    }

    return avatar;
  }

  /// Extracts up to two initials from [name]:
  /// first letter of first word + first letter of last word (if distinct).
  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    final first = parts.first[0].toUpperCase();
    if (parts.length == 1) return first;
    final last = parts.last[0].toUpperCase();
    return first == last ? first : '$first$last';
  }
}
