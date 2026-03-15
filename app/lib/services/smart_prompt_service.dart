import 'dart:async';

import 'package:antra/database/app_database.dart';
import 'package:antra/database/daos/person_important_dates_dao.dart';
import 'package:antra/database/daos/people_dao.dart';
import 'package:antra/database/daos/smart_prompt_dismissals_dao.dart';
import 'package:antra/models/smart_prompt.dart';

/// Computes smart prompts entirely client-side from local SQLite data.
///
/// All heavy lifting is done by [watchImportantDatePrompts] which:
/// 1. Fetches all active non-deleted important dates across all persons.
/// 2. For each date, computes the trigger day (event − reminderOffsetDays).
/// 3. Filters out dates already dismissed via [SmartPromptDismissalsDao].
/// 4. Returns a stream that re-evaluates whenever the underlying tables change.
class SmartPromptService {
  SmartPromptService({
    required AppDatabase db,
  })  : _datesDao = PersonImportantDatesDao(db),
        _dismissalsDao = SmartPromptDismissalsDao(db),
        _peopleDao = PeopleDao(db);

  final PersonImportantDatesDao _datesDao;
  final SmartPromptDismissalsDao _dismissalsDao;
  final PeopleDao _peopleDao;

  /// Streams important-date prompts that are due today (trigger date ≤ today).
  ///
  /// The stream re-emits whenever important dates or dismissals change.
  Stream<List<SmartPrompt>> watchImportantDatePrompts() async* {
    await for (final dates in _datesDao.watchAllActiveDates()) {
      final today = _todayDate();
      final prompts = <SmartPrompt>[];

      for (final date in dates) {
        final triggerDate =
            _triggerDate(date.month, date.day, date.reminderOffsetDays);
        if (triggerDate == null) continue;

        // Check if the trigger day is today or in the past (but same year cycle)
        if (!_isDue(today, triggerDate)) continue;

        // Skip if currently dismissed
        final dismissed = await _dismissalsDao.isDismissed(
          personId: date.personId,
          promptType: 'important_date',
          importantDateId: date.id,
        );
        if (dismissed) continue;

        final person = await _peopleDao.getPersonById(date.personId);
        if (person == null) continue;

        final daysUntilEvent = _daysUntilNextOccurrence(today, date.month, date.day);

        prompts.add(SmartPrompt(
          id: 'important_date_${date.id}',
          promptType: 'important_date',
          personId: date.personId,
          personName: person.name,
          title: _buildTitle(person.name, date.label, date.isBirthday == 1,
              daysUntilEvent),
          body: _buildBody(person.name, date.isBirthday == 1),
          importantDateId: date.id,
          daysUntil: daysUntilEvent,
        ));
      }

      // Sort soonest events first
      prompts.sort((a, b) => (a.daysUntil ?? 0).compareTo(b.daysUntil ?? 0));
      yield prompts;
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static DateTime _todayDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Computes the trigger date for the upcoming occurrence.
  /// Returns null if no reminder is configured (offsetDays == null).
  static DateTime? _triggerDate(int month, int day, int? offsetDays) {
    if (offsetDays == null) return null;
    final today = _todayDate();
    var occurrence = DateTime(today.year, month, day);
    if (occurrence.isBefore(today)) {
      occurrence = DateTime(today.year + 1, month, day);
    }
    return occurrence.subtract(Duration(days: offsetDays));
  }

  /// True if [triggerDate] ≤ [today].
  static bool _isDue(DateTime today, DateTime triggerDate) {
    return !triggerDate.isAfter(today);
  }

  /// Returns the calendar days until next occurrence of [month]/[day].
  static int _daysUntilNextOccurrence(
      DateTime today, int month, int day) {
    var occurrence = DateTime(today.year, month, day);
    if (occurrence.isBefore(today)) {
      occurrence = DateTime(today.year + 1, month, day);
    }
    return occurrence.difference(today).inDays;
  }

  static String _buildTitle(
      String name, String label, bool isBirthday, int daysUntil) {
    final emoji = isBirthday ? ' 🎂' : '';
    if (daysUntil == 0) return "$name's $label is today$emoji";
    if (daysUntil == 1) return "$name's $label is tomorrow$emoji";
    if (daysUntil < 7) return "$name's $label in $daysUntil days$emoji";
    if (daysUntil < 14) return "$name's $label in 1 week$emoji";
    if (daysUntil < 21) return "$name's $label in 2 weeks$emoji";
    return "$name's $label in ${(daysUntil / 7).round()} weeks$emoji";
  }

  static String _buildBody(String name, bool isBirthday) {
    if (isBirthday) return 'Maybe send them a message. 🎉';
    return 'You might want to reach out.';
  }

  // ---------------------------------------------------------------------------
  // T050: Inactivity prompts
  // ---------------------------------------------------------------------------

  /// Streams inactivity prompts for persons not interacted with in 90+ days.
  ///
  /// Re-emits whenever the people table changes.
  Stream<List<SmartPrompt>> watchInactivityPrompts() async* {
    await for (final persons in _peopleDao.watchAllPeople()) {
      final today = _todayDate();
      final cutoff = today.subtract(const Duration(days: 90));
      final prompts = <SmartPrompt>[];

      for (final person in persons) {
        final lastAt = person.lastInteractionAt;
        if (lastAt == null) {
          // Never interacted — skip (no interaction to base the gap on)
          continue;
        }
        final lastDate = DateTime.tryParse(lastAt);
        if (lastDate == null) continue;
        final lastMidnight = DateTime(lastDate.year, lastDate.month, lastDate.day);
        if (!lastMidnight.isBefore(cutoff)) continue;

        final dismissed = await _dismissalsDao.isDismissed(
          personId: person.id,
          promptType: 'inactivity',
          importantDateId: null,
        );
        if (dismissed) continue;

        final days = today.difference(lastMidnight).inDays;
        final months = (days / 30).round();
        prompts.add(SmartPrompt(
          id: 'inactivity_${person.id}',
          promptType: 'inactivity',
          personId: person.id,
          personName: person.name,
          title: "You haven't talked to ${person.name} in $months month${months == 1 ? '' : 's'}.",
          body: 'Reach out to stay connected.',
        ));
      }

      yield prompts;
    }
  }

  // ---------------------------------------------------------------------------
  // T050: Follow-up prompts
  // ---------------------------------------------------------------------------

  /// Streams follow-up prompts for persons last interacted with 6–8 days ago.
  Stream<List<SmartPrompt>> watchFollowUpPrompts() async* {
    await for (final persons in _peopleDao.watchAllPeople()) {
      final today = _todayDate();
      final prompts = <SmartPrompt>[];

      for (final person in persons) {
        final lastAt = person.lastInteractionAt;
        if (lastAt == null) continue;
        final lastDate = DateTime.tryParse(lastAt);
        if (lastDate == null) continue;
        final lastMidnight = DateTime(lastDate.year, lastDate.month, lastDate.day);
        final daysSince = today.difference(lastMidnight).inDays;

        // 6–8 day window ("last week")
        if (daysSince < 6 || daysSince > 8) continue;

        final dismissed = await _dismissalsDao.isDismissed(
          personId: person.id,
          promptType: 'follow_up',
          importantDateId: null,
        );
        if (dismissed) continue;

        prompts.add(SmartPrompt(
          id: 'follow_up_${person.id}',
          promptType: 'follow_up',
          personId: person.id,
          personName: person.name,
          title: 'You met ${person.name} last week — follow up?',
          body: 'A quick message goes a long way.',
        ));
      }

      yield prompts;
    }
  }
}

// ---------------------------------------------------------------------------
// Extension to expose watchAllActiveDates on the DAO
// ---------------------------------------------------------------------------

extension _WatchAll on PersonImportantDatesDao {
  /// Streams all active (non-deleted) important dates across all persons.
  Stream<List<PersonImportantDate>> watchAllActiveDates() {
    return (select(personImportantDates)
          ..where((t) => t.isDeleted.equals(0)))
        .watch();
  }
}
