import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/database/daos/bullets_dao.dart';
import 'package:antra/database/daos/people_dao.dart';
import 'package:antra/models/suggestion.dart';
import 'package:antra/providers/database_provider.dart';
import 'package:antra/providers/day_view_provider.dart';
import 'package:antra/screens/daily_log/bullet_detail_screen.dart';
import 'package:antra/theme/app_theme.dart';
import 'package:antra/widgets/aurora_background.dart';
import 'package:antra/widgets/bullet_capture_bar.dart';
import 'package:antra/widgets/suggestion_card.dart';
import 'package:antra/widgets/today_timeline.dart';
import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Primary Tab 0 screen — a daily relationship command center.
///
/// Assembles [RelationshipBriefing], [DailyGoalWidget], [SuggestionCard] feed,
/// [TodayInteractionTimeline], and a pinned [QuickLogBar] — all rendered over
/// the [AuroraBackground] gradient.
class DayViewScreen extends ConsumerStatefulWidget {
  const DayViewScreen({super.key});

  @override
  ConsumerState<DayViewScreen> createState() => _DayViewScreenState();
}

class _DayViewScreenState extends ConsumerState<DayViewScreen> {
  late DateTime _displayDate;

  @override
  void initState() {
    super.initState();
    _displayDate = DateTime.now();
  }

  String get _dateKey => DateFormat('yyyy-MM-dd').format(_displayDate);

  String get _displayLabel {
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final displayMidnight =
        DateTime(_displayDate.year, _displayDate.month, _displayDate.day);
    final diff = displayMidnight.difference(todayMidnight).inDays;
    if (diff == 0) return 'Today';
    if (diff == -1) return 'Yesterday';
    return DateFormat('MMM d, yyyy').format(_displayDate);
  }

  void _goToPreviousDay() {
    final d = _displayDate;
    setState(() => _displayDate =
        DateTime(d.year, d.month, d.day).subtract(const Duration(days: 1)));
  }

  void _goToNextDay() {
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final displayMidnight =
        DateTime(_displayDate.year, _displayDate.month, _displayDate.day);
    if (displayMidnight.isBefore(todayMidnight)) {
      setState(() => _displayDate =
          DateTime(_displayDate.year, _displayDate.month, _displayDate.day)
              .add(const Duration(days: 1)));
    }
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _displayDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(
        () => _displayDate = DateTime(picked.year, picked.month, picked.day));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isBeforeToday = DateTime(_displayDate.year, _displayDate.month,
            _displayDate.day)
        .isBefore(DateTime(now.year, now.month, now.day));

    final suggestionsAsync = ref.watch(suggestionsFilteredProvider);
    final interactionsAsync = ref.watch(todayInteractionsProvider(_dateKey));
    final notifier = ref.read(suggestionNotifierProvider.notifier);
    final suggestionState = ref.watch(suggestionNotifierProvider);

    // BulletCaptureBar estimated height so ListView content clears it.
    const captureBarEstimatedHeight = 80.0;

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity == null) return;
        if (details.primaryVelocity! < -200) _goToNextDay();
        if (details.primaryVelocity! > 200) _goToPreviousDay();
      },
      child: Scaffold(
        backgroundColor: AntraColors.auroraDeepNavy,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          title: _DateNavigator(
            label: _displayLabel,
            onPrev: _goToPreviousDay,
            onNext: _goToNextDay,
            onTapLabel: () => _pickDate(context),
            showNext: isBeforeToday,
          ),
          centerTitle: false,
        ),
        body: AuroraBackground(
          variant: AuroraVariant.dayView,
          child: Stack(
            children: [
              RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(suggestionsFilteredProvider);
                  ref.invalidate(todayInteractionsProvider(_dateKey));
                },
                child: ListView(
                  padding: EdgeInsets.only(
                    bottom: captureBarEstimatedHeight + 16,
                    top: 8,
                  ),
                  children: [
                    // --- Follow-Up Cards ---
                    suggestionsAsync.when(
                      data: (suggestions) {
                        final visible = suggestions
                            .where((s) => !suggestionState.dismissedPersonIds
                                .contains(s.personId))
                            .toList();
                        if (visible.isEmpty) {
                          return const _EmptyState(
                            icon: Icons.favorite_border_rounded,
                            message: 'Nothing to do — you\'re all caught up.',
                          );
                        }
                        return Column(
                          children: [
                            for (final s in visible)
                              SuggestionCard(
                                suggestion: s,
                                expanded:
                                    suggestionState.expandedPersonId ==
                                        s.personId,
                                onTap: () {
                                  if (suggestionState.expandedPersonId ==
                                      s.personId) {
                                    notifier.collapse();
                                  } else {
                                    notifier.expand(s.personId);
                                  }
                                },
                                onAction: (action) =>
                                    _handleAction(context, ref, s, action),
                                onDismiss: () =>
                                    notifier.dismiss(s.personId),
                              ),
                          ],
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 8),

                    // --- Timeline for selected date ---
                    interactionsAsync.when(
                      data: (interactions) => TodayInteractionTimeline(
                        interactions: interactions,
                        onTap: (bulletId) => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                BulletDetailScreen(bulletId: bulletId),
                          ),
                        ),
                        onDelete: (bulletId) =>
                            _onDeleteEntry(context, bulletId),
                        onComplete: (bulletId, complete) =>
                            _onToggleComplete(context, bulletId, complete),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const TodayInteractionTimeline(
                        interactions: [],
                        onTap: _noop,
                        onDelete: _noop,
                        onComplete: _noopComplete,
                      ),
                    ),
                  ],
                ),
              ),

              // Pinned glass journal composer at the bottom of the aurora canvas.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: BulletCaptureBar(date: _dateKey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Task completion toggle
  // ---------------------------------------------------------------------------

  Future<void> _onToggleComplete(
    BuildContext context,
    String bulletId,
    bool complete,
  ) async {
    try {
      final db = await ref.read(appDatabaseProvider.future);
      final bulletsDao = BulletsDao(db);
      if (complete) {
        await bulletsDao.completeTask(bulletId);
      } else {
        await bulletsDao.uncompleteTask(bulletId);
      }
    } catch (_) {
      // Silent — completion toggle failures are non-critical.
    }
  }

  // ---------------------------------------------------------------------------
  // Delete entry with undo snackbar
  // ---------------------------------------------------------------------------

  Future<void> _onDeleteEntry(BuildContext context, String bulletId) async {
    try {
      final db = await ref.read(appDatabaseProvider.future);
      final bulletsDao = BulletsDao(db);
      await bulletsDao.softDeleteBullet(bulletId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Entry deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              final db2 = await ref.read(appDatabaseProvider.future);
              await BulletsDao(db2).undoSoftDeleteBullet(bulletId);
            },
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete entry: $e')),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Card action handler
  // ---------------------------------------------------------------------------

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    Suggestion suggestion,
    SuggestionAction action,
  ) async {
    final notifier = ref.read(suggestionNotifierProvider.notifier);

    if (action == SuggestionAction.markDone) {
      notifier.dismiss(suggestion.personId);
      return;
    }

    try {
      final db = await ref.read(appDatabaseProvider.future);
      final bulletsDao = BulletsDao(db);
      final peopleDao = PeopleDao(db);

      final now = DateTime.now().toUtc().toIso8601String();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final dayLog = await bulletsDao.getOrCreateDayLog(today);
      final bulletId = _uuid.v4();

      final content = _actionContent(action, suggestion.personName);
      final bulletType =
          action == SuggestionAction.logNote ? 'note' : 'event';

      await bulletsDao.insertBullet(
        BulletsCompanion.insert(
          id: bulletId,
          dayId: dayLog.id,
          type: Value(bulletType),
          content: content,
          position: 0,
          createdAt: now,
          updatedAt: now,
          deviceId: 'local',
        ),
      );
      await peopleDao.insertLink(bulletId, suggestion.personId);

      notifier.dismiss(suggestion.personId);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not log action: $e')),
      );
    }
  }

  String _actionContent(SuggestionAction action, String name) {
    return switch (action) {
      SuggestionAction.message => '✉️ Message with $name',
      SuggestionAction.call => '📞 Call with $name',
      SuggestionAction.logMeeting => '🤝 Meeting with $name',
      SuggestionAction.sendGreeting => '🎉 Sent birthday greeting to $name',
      SuggestionAction.logCall => '📞 Call with $name',
      SuggestionAction.followUp => '✅ Followed up with $name',
      SuggestionAction.scheduleLater => '📅 Scheduled follow-up with $name',
      SuggestionAction.markDone => '',
      SuggestionAction.logNote => '✍️ Note about $name',
    };
  }
}

void _noop(String _) {}
void _noopComplete(String _, bool __) {}

// ---------------------------------------------------------------------------
// Empty state widget (glass-friendly dark palette)
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white38),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 14, color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Date navigator widget
// ---------------------------------------------------------------------------

class _DateNavigator extends StatelessWidget {
  const _DateNavigator({
    required this.label,
    required this.onPrev,
    required this.onNext,
    required this.onTapLabel,
    required this.showNext,
  });

  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onTapLabel;
  final bool showNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _NavArrow(icon: Icons.chevron_left_rounded, onTap: onPrev),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTapLabel,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 0.5,
              ),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
        showNext
            ? _NavArrow(icon: Icons.chevron_right_rounded, onTap: onNext)
            : const SizedBox(width: 30),
      ],
    );
  }
}

class _NavArrow extends StatelessWidget {
  const _NavArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Icon(icon, size: 22, color: Colors.white70),
      ),
    );
  }
}
