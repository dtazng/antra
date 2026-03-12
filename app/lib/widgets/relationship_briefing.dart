import 'package:flutter/material.dart';

import 'package:antra/models/suggestion.dart';

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
      return const Padding(
        padding: EdgeInsets.all(16),
        child: _LoadingSkeleton(),
      );
    }

    if (suggestions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          'Your relationships are looking good today.',
          style: TextStyle(fontSize: 15, color: Colors.black87),
        ),
      );
    }

    final theme = Theme.of(context);
    final count = suggestions.length.clamp(0, 4);
    final visible = suggestions.take(count).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Good ${_greeting()}.',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Here are $count relationship thing${count == 1 ? '' : 's'} worth doing today:',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
          ),
          const SizedBox(height: 8),
          for (final s in visible)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: 14)),
                  Expanded(
                    child: Text(
                      '${s.personName} — ${s.signalText}',
                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
        ],
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
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
