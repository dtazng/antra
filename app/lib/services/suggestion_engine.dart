import 'package:antra/database/app_database.dart';
import 'package:antra/models/suggestion.dart';

/// Pure Dart service — no Flutter imports.
/// Computes a ranked list of up to 4 [Suggestion] objects from [PeopleData].
///
/// Scoring:
///   +3  birthday within 7 days
///   +2  needsFollowUp == 1
///   +2  contact gap ≥ 90 days
///   +1  contact gap 30–89 days
///   +1  first-contact anniversary (±3 days, any year)
///
/// Contacts in [todayPersonIds] are excluded entirely.
/// Results sorted score desc → name asc, capped at 4.
class SuggestionEngine {
  static const _cap = 4;
  static const _birthdayWindowDays = 7;
  static const _gap90Days = 90;
  static const _gap30Days = 30;
  static const _anniversaryWindowDays = 3;

  List<Suggestion> compute(
    List<PeopleData> people,
    String today, // 'YYYY-MM-DD'
    Set<String> todayPersonIds,
  ) {
    final todayDate = DateTime.tryParse(today);
    if (todayDate == null) return const [];

    final scored = <_ScoredPerson>[];

    for (final person in people) {
      if (person.isDeleted == 1) continue;
      if (todayPersonIds.contains(person.id)) continue;

      int score = 0;
      SuggestionType? primaryType;
      String signalText = '';
      final metadata = <String, dynamic>{};

      // --- Birthday within 7 days ---
      final birthday = _parseBirthday(person.birthday, todayDate.year);
      int? birthdayDaysAway;
      if (birthday != null) {
        birthdayDaysAway = _daysUntil(todayDate, birthday);
        if (birthdayDaysAway != null &&
            birthdayDaysAway >= 0 &&
            birthdayDaysAway <= _birthdayWindowDays) {
          score += 3;
          primaryType = SuggestionType.birthday;
          signalText = birthdayDaysAway == 0
              ? 'Birthday today 🎉'
              : birthdayDaysAway == 1
                  ? 'Birthday tomorrow 🎉'
                  : 'Birthday in $birthdayDaysAway days 🎉';
          metadata['birthdayDaysAway'] = birthdayDaysAway;
        }
      }

      // --- Follow-up flag ---
      if (person.needsFollowUp == 1) {
        score += 2;
        primaryType ??= SuggestionType.followUp;
        if (signalText.isEmpty) signalText = 'Follow up needed';
      }

      // --- Contact gap ---
      int? daysAgo;
      if (person.lastInteractionAt != null) {
        final last = DateTime.tryParse(person.lastInteractionAt!);
        if (last != null) {
          daysAgo = todayDate.difference(last.toUtc().toLocal()).inDays;
          if (daysAgo >= _gap90Days) {
            score += 2;
            primaryType ??= SuggestionType.reconnect;
          } else if (daysAgo >= _gap30Days) {
            score += 1;
            primaryType ??= SuggestionType.reconnect;
          }
          if (signalText.isEmpty && daysAgo >= _gap30Days) {
            signalText = 'Last contact: $daysAgo days ago';
            metadata['daysAgo'] = daysAgo;
          }
        }
      }

      // --- Anniversary (first-contact ±3 days, any year) ---
      final createdAt = DateTime.tryParse(person.createdAt);
      if (createdAt != null) {
        final yearsAgo = todayDate.year - createdAt.year;
        if (yearsAgo > 0) {
          final anniversary = DateTime(
            todayDate.year,
            createdAt.month,
            createdAt.day,
          );
          final diff = todayDate.difference(anniversary).inDays.abs();
          if (diff <= _anniversaryWindowDays) {
            score += 1;
            primaryType ??= SuggestionType.memory;
            if (signalText.isEmpty) {
              signalText =
                  'You met ${person.name} $yearsAgo year${yearsAgo == 1 ? '' : 's'} ago today';
              metadata['yearsAgo'] = yearsAgo;
            }
          }
        }
      }

      if (score == 0) continue; // no signal → skip

      final type = primaryType ?? SuggestionType.reconnect;
      if (signalText.isEmpty) {
        signalText = daysAgo != null
            ? 'Last contact: $daysAgo days ago'
            : 'Reconnect with ${person.name}';
      }

      scored.add(_ScoredPerson(
        score: score,
        suggestion: Suggestion(
          type: type,
          personId: person.id,
          personName: person.name,
          personNotes: person.notes,
          signalText: signalText,
          score: score,
          metadata: metadata,
        ),
      ));
    }

    scored.sort((a, b) {
      final scoreCmp = b.score.compareTo(a.score);
      if (scoreCmp != 0) return scoreCmp;
      return a.suggestion.personName
          .toLowerCase()
          .compareTo(b.suggestion.personName.toLowerCase());
    });

    return scored.take(_cap).map((s) => s.suggestion).toList();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Parses a stored birthday string (YYYY-MM-DD) and returns a [DateTime]
  /// for the birthday this year. Returns null if unparseable.
  DateTime? _parseBirthday(String? birthday, int year) {
    if (birthday == null) return null;
    final parts = birthday.split('-');
    if (parts.length < 2) return null;
    final month = int.tryParse(parts[1]);
    final day = parts.length >= 3 ? int.tryParse(parts[2]) : null;
    if (month == null) return null;
    // Handle YYYY-MM-DD and MM-DD formats.
    final d = day ?? int.tryParse(parts.last);
    if (d == null) return null;
    return DateTime(year, month, d);
  }

  /// Days from [from] until [to]. Returns null if [to] is before [from].
  int? _daysUntil(DateTime from, DateTime to) {
    final diff = to.difference(from).inDays;
    return diff;
  }
}

class _ScoredPerson {
  const _ScoredPerson({required this.score, required this.suggestion});
  final int score;
  final Suggestion suggestion;
}
