import 'package:flutter/material.dart';

import 'package:antra/models/daily_goal.dart';

/// Progress section of [DayViewScreen].
/// Shows a linear progress bar toward the daily people-reached goal.
/// Switches to a completion message when [goal.completed] is true.
class DailyGoalWidget extends StatelessWidget {
  const DailyGoalWidget({super.key, required this.goal});

  final DailyGoal goal;

  @override
  Widget build(BuildContext context) {
    if (goal.completed) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily relationships complete ✓',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600, color: Colors.green.shade700),
            ),
            const SizedBox(height: 2),
            Text(
              'You strengthened ${goal.reached} connection${goal.reached == 1 ? '' : 's'} today.',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reach out to ${goal.target} people today',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: goal.reached / goal.target,
            backgroundColor: Colors.grey.shade200,
            minHeight: 6,
          ),
          const SizedBox(height: 4),
          Text(
            '${goal.reached} / ${goal.target} completed',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
