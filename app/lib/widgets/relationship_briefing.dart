import 'package:flutter/material.dart';

import 'package:antra/models/suggestion.dart';
import 'package:antra/widgets/glass_surface.dart';
import 'package:antra/widgets/person_avatar.dart';

/// Top briefing section of [DayViewScreen].
/// Stateless — receives pre-computed suggestions from the parent.
class RelationshipBriefing extends StatelessWidget {
  const RelationshipBriefing({
    super.key,
    required this.suggestions,
    required this.loading,
  });

  final List<Suggestion> suggestions;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: GlassSurface(
          style: GlassStyle.hero,
          child: const _LoadingSkeleton(),
        ),
      );
    }

    if (suggestions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: GlassSurface(
          style: GlassStyle.hero,
          child: const Text(
            'Your relationships are looking good today.',
            style: TextStyle(fontSize: 15, color: Colors.white70),
          ),
        ),
      );
    }

    final count = suggestions.length.clamp(0, 4);
    final visible = suggestions.take(count).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GlassSurface(
        style: GlassStyle.hero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Good ${_greeting()}.',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Here are $count relationship thing${count == 1 ? '' : 's'} worth doing today:',
              style: const TextStyle(fontSize: 14, color: Colors.white60),
            ),
            const SizedBox(height: 12),
            for (final s in visible)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    PersonAvatar(
                      personId: s.personId,
                      displayName: s.personName,
                      radius: 16,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${s.personName} — ${s.signalText}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _bar(0.4),
        const SizedBox(height: 8),
        _bar(0.7),
        const SizedBox(height: 6),
        _bar(0.6),
        const SizedBox(height: 6),
        _bar(0.5),
      ],
    );
  }

  Widget _bar(double widthFactor) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 14,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
