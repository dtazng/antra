import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/providers/bullets_provider.dart';
import 'package:antra/providers/reviews_provider.dart';
import 'package:antra/providers/task_lifecycle_provider.dart';
import 'package:antra/screens/daily_log/bullet_detail_screen.dart';
import 'package:antra/screens/daily_log/task_detail_screen.dart';
import 'package:antra/screens/review/weekly_review_screen.dart';
import 'package:antra/widgets/bullet_capture_bar.dart';
import 'package:antra/widgets/bullet_list_item.dart';
import 'package:antra/widgets/carry_over_task_item.dart';
import 'package:antra/widgets/sync_status_bar.dart';
import 'package:antra/widgets/task_quick_actions_sheet.dart';

class DailyLogScreen extends ConsumerStatefulWidget {
  /// Optional date string (YYYY-MM-DD) to open instead of today.
  final String? initialDate;

  const DailyLogScreen({super.key, this.initialDate});

  @override
  ConsumerState<DailyLogScreen> createState() => _DailyLogScreenState();
}

class _DailyLogScreenState extends ConsumerState<DailyLogScreen> {
  late DateTime _displayDate;
  bool _weeklyBannerDismissed = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialDate != null) {
      _displayDate = DateTime.tryParse(widget.initialDate!) ?? DateTime.now();
    } else {
      _displayDate = DateTime.now();
    }
  }

  String get _weeklyFrom {
    final monday =
        _displayDate.subtract(Duration(days: _displayDate.weekday - 1));
    return DateFormat('yyyy-MM-dd').format(monday);
  }

  String get _weeklyTo {
    final monday =
        _displayDate.subtract(Duration(days: _displayDate.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    return DateFormat('yyyy-MM-dd').format(sunday);
  }

  String get _dateKey => DateFormat('yyyy-MM-dd').format(_displayDate);

  String get _displayLabel {
    final today = DateTime.now();
    final diff = _displayDate
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    if (diff == 0) return 'Today';
    if (diff == -1) return 'Yesterday';
    return DateFormat('MMM d, yyyy').format(_displayDate);
  }

  void _goToPreviousDay() =>
      setState(() => _displayDate = _displayDate.subtract(const Duration(days: 1)));

  void _goToNextDay() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    if (_displayDate.isBefore(tomorrow)) {
      setState(() => _displayDate = _displayDate.add(const Duration(days: 1)));
    }
  }

  bool _hasWeeklyReview(List<Review> reviews) {
    return reviews.any(
      (r) =>
          r.periodType == 'week' &&
          r.startDate == _weeklyFrom &&
          r.completedAt != null,
    );
  }

  bool get _isToday {
    final today = DateTime.now();
    return _displayDate.year == today.year &&
        _displayDate.month == today.month &&
        _displayDate.day == today.day;
  }

  void _openTaskDetail(BuildContext context, String bulletId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TaskDetailScreen(bulletId: bulletId),
      ),
    );
  }

  void _openBulletDetail(BuildContext context, String bulletId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BulletDetailScreen(bulletId: bulletId),
      ),
    );
  }

  void _showQuickActions(BuildContext context, Bullet bullet) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => TaskQuickActionsSheet(bullet: bullet),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bulletsAsync = ref.watch(bulletsForDayProvider(_dateKey));
    final reviewsAsync = ref.watch(allReviewsProvider);
    final carryOverAsync =
        _isToday ? ref.watch(carryOverTasksProvider) : null;

    final showBanner = !_weeklyBannerDismissed &&
        reviewsAsync.whenOrNull(data: (r) => !_hasWeeklyReview(r)) == true;

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity == null) return;
        if (details.primaryVelocity! < -200) _goToNextDay();
        if (details.primaryVelocity! > 200) _goToPreviousDay();
      },
      child: Scaffold(
        appBar: AppBar(
          title: _DateNavigator(
            label: _displayLabel,
            onPrev: _goToPreviousDay,
            onNext: _goToNextDay,
          ),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 12),
              child: SyncStatusBar(),
            ),
          ],
        ),
        body: Column(
          children: [
            if (showBanner)
              _WeeklyReviewBanner(
                onDismiss: () =>
                    setState(() => _weeklyBannerDismissed = true),
                onStart: () {
                  setState(() => _weeklyBannerDismissed = true);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const WeeklyReviewScreen(),
                    ),
                  );
                },
              ),
            Expanded(
              child: bulletsAsync.when(
                data: (bulletList) {
                  final carryOverTasks =
                      carryOverAsync?.valueOrNull ?? const [];
                  final hasContent =
                      bulletList.isNotEmpty || carryOverTasks.isNotEmpty;

                  if (!hasContent) {
                    return const _EmptyDayState();
                  }

                  return ListView(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    children: [
                      // Today's entries
                      for (final bullet in bulletList)
                        BulletListItem(
                          bullet: bullet,
                          onTap: bullet.type == 'task'
                              ? () => _openTaskDetail(context, bullet.id)
                              : () => _openBulletDetail(context, bullet.id),
                        ),

                      // "From Yesterday" section — only shown when not empty
                      if (carryOverTasks.isNotEmpty) ...[
                        _FromYesterdayHeader(count: carryOverTasks.length),
                        for (final task in carryOverTasks)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 3),
                            child: CarryOverTaskItem(
                              bullet: task,
                              onTap: () =>
                                  _openTaskDetail(context, task.id),
                              onQuickAction: () =>
                                  _showQuickActions(context, task),
                            ),
                          ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
            BulletCaptureBar(date: _dateKey),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _DateNavigator extends StatelessWidget {
  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _DateNavigator({
    required this.label,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _NavArrow(icon: Icons.chevron_left_rounded, onTap: onPrev),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha:0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
              letterSpacing: -0.2,
            ),
          ),
        ),
        _NavArrow(icon: Icons.chevron_right_rounded, onTap: onNext),
      ],
    );
  }
}

class _NavArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Icon(
          icon,
          size: 22,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _FromYesterdayHeader extends StatelessWidget {
  final int count;
  const _FromYesterdayHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Text(
            'From Yesterday',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyReviewBanner extends StatelessWidget {
  final VoidCallback onDismiss;
  final VoidCallback onStart;
  const _WeeklyReviewBanner({required this.onDismiss, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha:0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.secondary.withValues(alpha:0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_stories_outlined, size: 20, color: cs.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weekly review ready',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSecondaryContainer,
                  ),
                ),
                Text(
                  'Take a moment to reflect on this week.',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSecondaryContainer.withValues(alpha:0.75),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: cs.secondary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: onStart,
            child: const Text('Review', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(Icons.close_rounded, size: 18, color: cs.onSecondaryContainer.withValues(alpha:0.5)),
          ),
        ],
      ),
    );
  }
}

class _EmptyDayState extends StatelessWidget {
  const _EmptyDayState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha:0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.edit_note_rounded,
              size: 36,
              color: cs.onSurfaceVariant.withValues(alpha:0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Nothing here yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha:0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Start capturing a thought below',
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurfaceVariant.withValues(alpha:0.6),
            ),
          ),
        ],
      ),
    );
  }
}
