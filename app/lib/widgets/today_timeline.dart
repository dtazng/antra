import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:antra/models/today_interaction.dart';

/// Reverse-chronological list of today's person-linked interactions.
/// Callers provide [interactions] pre-sorted newest-first.
class TodayInteractionTimeline extends StatelessWidget {
  const TodayInteractionTimeline({
    super.key,
    required this.interactions,
    required this.onTap,
  });

  final List<TodayInteraction> interactions;
  final void Function(String bulletId) onTap;

  static final _timeFmt = DateFormat('HH:mm');

  @override
  Widget build(BuildContext context) {
    if (interactions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          'No interactions logged yet today.',
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            'Today',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
              letterSpacing: 0.5,
            ),
          ),
        ),
        for (final interaction in interactions)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap(interaction.bulletId),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(
                      _timeFmt.format(interaction.loggedAt),
                      style: const TextStyle(fontSize: 12, color: Colors.black38),
                    ),
                  ),
                  const Text(
                    '— ',
                    style: TextStyle(fontSize: 14, color: Colors.black38),
                  ),
                  Expanded(
                    child: Text(
                      '${interaction.interactionLabel} with ${interaction.personName}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
