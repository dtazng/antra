import 'package:flutter/material.dart';

import 'package:antra/services/person_color.dart';

/// Rendering style variants for [PersonIdentityAccent].
enum AccentStyle {
  /// Gradient-filled circle. Used in timeline entries, list rows.
  dot,

  /// Annular gradient ring. Used on collapsed suggestion cards.
  ring,

  /// Gradient stroke on the left edge of a card. Used on expanded suggestion cards.
  edgeGlow,

  /// Thin gradient top border on a card. Used in person profile headers.
  topBar,
}

/// Renders a small gradient accent that represents a person's color identity.
///
/// Used in suggestion cards, timeline entries, and anywhere a person is
/// referenced without a full avatar.
class PersonIdentityAccent extends StatelessWidget {
  const PersonIdentityAccent({
    super.key,
    required this.personId,
    this.style = AccentStyle.dot,
    this.size = 8,
  });

  final String personId;
  final AccentStyle style;

  /// For [AccentStyle.dot]: diameter of the circle.
  /// For other styles: used as a width/thickness multiplier.
  final double size;

  @override
  Widget build(BuildContext context) {
    final identity = PersonColorService.fromId(personId);
    switch (style) {
      case AccentStyle.dot:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: identity.gradient,
          ),
        );

      case AccentStyle.ring:
        return Container(
          width: size * 2,
          height: size * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                identity.gradientStart.withValues(alpha: 0.6),
                identity.gradientEnd.withValues(alpha: 0.6),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(size * 0.3),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.4),
              ),
            ),
          ),
        );

      case AccentStyle.edgeGlow:
        return Container(
          width: size * 0.5,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                identity.gradientStart.withValues(alpha: 0.8),
                identity.gradientEnd.withValues(alpha: 0.8),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(size * 0.25),
          ),
        );

      case AccentStyle.topBar:
        return Container(
          height: size * 0.4,
          decoration: BoxDecoration(
            gradient: identity.gradient,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(4),
            ),
          ),
        );
    }
  }
}
