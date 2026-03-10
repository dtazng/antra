import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:antra/database/app_database.dart';

/// Passive badge showing follow-up or stale status for a person.
/// Returns an empty widget when no badge applies.
class PersonStatusBadge extends StatelessWidget {
  final PeopleData person;

  const PersonStatusBadge({super.key, required this.person});

  static const _staleDays = 30;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Follow-up overdue (date set and in the past)
    if (person.needsFollowUp == 1 && person.followUpDate != null) {
      final due = DateTime.tryParse(person.followUpDate!);
      if (due != null && due.isBefore(DateTime.now())) {
        return _Badge(
          label: 'Overdue · ${DateFormat('MMM d').format(due)}',
          color: cs.error,
        );
      }
    }

    // Follow-up needed with a future date
    if (person.needsFollowUp == 1 && person.followUpDate != null) {
      final due = DateTime.tryParse(person.followUpDate!);
      if (due != null) {
        return _Badge(
          label: 'Follow up ${DateFormat('MMM d').format(due)}',
          color: cs.tertiary,
        );
      }
    }

    // Follow-up needed without a date
    if (person.needsFollowUp == 1) {
      return _Badge(label: 'Follow up', color: cs.tertiary);
    }

    // Stale relationship
    if (person.lastInteractionAt != null) {
      final last = DateTime.tryParse(person.lastInteractionAt!);
      if (last != null) {
        final days = DateTime.now().difference(last).inDays;
        if (days > _staleDays) {
          return _Badge(
            label: 'Last contact $days days ago',
            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
          );
        }
      }
    }

    return const SizedBox.shrink();
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}
