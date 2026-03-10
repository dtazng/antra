import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:antra/database/app_database.dart';

/// A timeline row showing a single lifecycle event in the TaskDetailScreen history.
class LifecycleEventTile extends StatelessWidget {
  final TaskLifecycleEvent event;
  final bool isLast;

  const LifecycleEventTile({
    super.key,
    required this.event,
    this.isLast = false,
  });

  static (IconData, Color Function(ColorScheme)) _iconAndColor(
      String eventType) {
    switch (eventType) {
      case 'created':
        return (Icons.star_rounded, (cs) => cs.primary);
      case 'completed':
        return (Icons.check_circle_rounded, (cs) => cs.primary);
      case 'canceled':
        return (Icons.cancel_rounded, (cs) => cs.error);
      case 'carried_over':
        return (Icons.redo_rounded, (cs) => cs.tertiary);
      case 'kept_for_today':
        return (Icons.arrow_forward_rounded, (cs) => cs.secondary);
      case 'scheduled':
        return (Icons.calendar_today_rounded, (cs) => cs.secondary);
      case 'moved_to_backlog':
        return (Icons.inbox_rounded, (cs) => cs.secondary);
      case 'reactivated':
        return (Icons.refresh_rounded, (cs) => cs.primary);
      case 'entered_weekly_review':
        return (Icons.search_rounded, (cs) => cs.tertiary);
      case 'converted_to_note':
        return (Icons.note_rounded, (cs) => cs.secondary);
      default:
        return (Icons.circle_outlined, (cs) => cs.onSurfaceVariant);
    }
  }

  static String _labelForType(String eventType) {
    switch (eventType) {
      case 'created':
        return 'Created';
      case 'carried_over':
        return 'Carried Over';
      case 'kept_for_today':
        return 'Kept for Today';
      case 'scheduled':
        return 'Scheduled';
      case 'moved_to_backlog':
        return 'Moved to Backlog';
      case 'reactivated':
        return 'Reactivated';
      case 'entered_weekly_review':
        return 'Entered Weekly Review';
      case 'completed':
        return 'Completed';
      case 'canceled':
        return 'Canceled';
      case 'converted_to_note':
        return 'Converted to Note';
      default:
        return eventType.replaceAll('_', ' ');
    }
  }

  String _formatDate(String isoUtc) {
    try {
      final dt = DateTime.parse(isoUtc).toLocal();
      return DateFormat('MMM d · h:mm a').format(dt);
    } catch (_) {
      return isoUtc;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (icon, colorFn) = _iconAndColor(event.eventType);
    final color = colorFn(cs);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline column: icon + vertical connector
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 13, color: color),
                ),
                if (!isLast)
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 1.5,
                        color: cs.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      _labelForType(event.eventType),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatDate(event.occurredAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
