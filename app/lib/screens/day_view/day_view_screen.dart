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
import 'package:antra/widgets/daily_goal_widget.dart';
import 'package:antra/widgets/quick_log_bar.dart';
import 'package:antra/widgets/relationship_briefing.dart';
import 'package:antra/widgets/suggestion_card.dart';
import 'package:antra/widgets/today_timeline.dart';
import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Primary Tab 0 screen — a daily relationship command center.
///
/// Assembles [RelationshipBriefing], [DailyGoalWidget], [SuggestionCard] feed,
/// [TodayInteractionTimeline], and a pinned [QuickLogBar].
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
    setState(() =>
        _displayDate = DateTime(d.year, d.month, d.day).subtract(const Duration(days: 1)));
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
    setState(() => _displayDate = DateTime(picked.year, picked.month, picked.day));
  }

  @override
  Widget build(BuildContext context) {
    final suggestionsAsync = ref.watch(suggestionsFilteredProvider);
    final goalAsync = ref.watch(dailyGoalProvider(_dateKey));
    final interactionsAsync = ref.watch(todayInteractionsProvider(_dateKey));
    final notifier = ref.read(suggestionNotifierProvider.notifier);
    final suggestionState = ref.watch(suggestionNotifierProvider);

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
            onTapLabel: () => _pickDate(context),
          ),
          centerTitle: false,
        ),
        bottomNavigationBar: QuickLogBar(
          date: _dateKey,
          onInteractionLogged: (_) {},
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(suggestionsFilteredProvider);
            ref.invalidate(dailyGoalProvider(_dateKey));
            ref.invalidate(todayInteractionsProvider(_dateKey));
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              // --- Relationship Briefing (always today) ---
              suggestionsAsync.when(
                data: (suggestions) => RelationshipBriefing(
                  suggestions: suggestions,
                  loading: false,
                ),
                loading: () => const RelationshipBriefing(
                  suggestions: [],
                  loading: true,
                ),
                error: (_, __) => const RelationshipBriefing(
                  suggestions: [],
                  loading: false,
                ),
              ),

              const Divider(height: 1),

              // --- Daily Goal ---
              goalAsync.when(
                data: (goal) => DailyGoalWidget(goal: goal),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              const Divider(height: 1),

              // --- Suggestion Cards (always today) ---
              suggestionsAsync.when(
                data: (suggestions) {
                  final visible = suggestions
                      .where((s) =>
                          !suggestionState.dismissedPersonIds.contains(s.personId))
                      .toList();
                  if (visible.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No suggestions right now — great work!',
                        style: TextStyle(color: Colors.black54),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final s in visible)
                        SuggestionCard(
                          suggestion: s,
                          expanded: suggestionState.expandedPersonId == s.personId,
                          onTap: () {
                            if (suggestionState.expandedPersonId == s.personId) {
                              notifier.collapse();
                            } else {
                              notifier.expand(s.personId);
                            }
                          },
                          onAction: (action) =>
                              _handleAction(context, ref, s, action),
                          onDismiss: () => notifier.dismiss(s.personId),
                        ),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              const Divider(height: 1),

              // --- Timeline for selected date ---
              interactionsAsync.when(
                data: (interactions) => TodayInteractionTimeline(
                  interactions: interactions,
                  onTap: (bulletId) => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BulletDetailScreen(bulletId: bulletId),
                    ),
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const TodayInteractionTimeline(
                  interactions: [],
                  onTap: _noop,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
      final bulletType = action == SuggestionAction.logNote ? 'note' : 'event';

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

// ---------------------------------------------------------------------------
// Date navigator widget
// ---------------------------------------------------------------------------

class _DateNavigator extends StatelessWidget {
  const _DateNavigator({
    required this.label,
    required this.onPrev,
    required this.onNext,
    required this.onTapLabel,
  });

  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onTapLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
              color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
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
        ),
        _NavArrow(icon: Icons.chevron_right_rounded, onTap: onNext),
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
        child: Icon(
          icon,
          size: 22,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
