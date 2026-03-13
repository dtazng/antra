import 'package:flutter/material.dart';

import 'package:antra/models/daily_goal.dart';
import 'package:antra/theme/app_theme.dart';
import 'package:antra/widgets/glass_surface.dart';

/// Progress section of [DayViewScreen].
/// Shows a gradient progress bar toward the daily people-reached goal.
/// Switches to a completion message when [goal.completed] is true.
class DailyGoalWidget extends StatelessWidget {
  const DailyGoalWidget({super.key, required this.goal});

  final DailyGoal goal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GlassSurface(
        style: GlassStyle.card,
        child: goal.completed ? _completedContent() : _progressContent(),
      ),
    );
  }

  Widget _completedContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Daily relationships complete ✓',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'You strengthened ${goal.reached} connection${goal.reached == 1 ? '' : 's'} today.',
          style: const TextStyle(fontSize: 13, color: Colors.white60),
        ),
      ],
    );
  }

  Widget _progressContent() {
    final progress = (goal.reached / goal.target).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reach out to ${goal.target} people today',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: [
              Container(
                height: 6,
                color: Colors.white.withValues(alpha: 0.12),
              ),
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AntraColors.auroraElectricBlue,
                        AntraColors.auroraTeal,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${goal.reached} / ${goal.target} completed',
          style: const TextStyle(fontSize: 12, color: Colors.white54),
        ),
      ],
    );
  }
}
