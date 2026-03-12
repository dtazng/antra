import 'package:flutter_test/flutter_test.dart';

import 'package:antra/models/suggestion.dart';
import 'package:antra/services/suggestion_engine.dart';

// ---------------------------------------------------------------------------
// Stub helpers — creates minimal PeopleData-like maps for testing.
// SuggestionEngine accepts List<PeopleData> but the test stubs use the
// constructor exposed by the generated drift code. For unit tests we use a
// simple data class defined below to avoid a database dependency.
// ---------------------------------------------------------------------------

import 'package:antra/database/app_database.dart';

PeopleData _person({
  required String id,
  required String name,
  String? birthday,
  String? lastInteractionAt,
  int needsFollowUp = 0,
  String? notes,
  String? createdAt,
}) {
  final now = DateTime.now().toUtc().toIso8601String();
  return PeopleData(
    id: id,
    name: name,
    notes: notes,
    reminderCadenceDays: null,
    lastInteractionAt: lastInteractionAt,
    createdAt: createdAt ?? now,
    updatedAt: now,
    syncId: null,
    deviceId: 'test',
    isDeleted: 0,
    company: null,
    role: null,
    email: null,
    phone: null,
    birthday: birthday,
    location: null,
    tags: null,
    relationshipType: null,
    needsFollowUp: needsFollowUp,
    followUpDate: null,
  );
}

String _daysAgo(int days) =>
    DateTime.now().toUtc().subtract(Duration(days: days)).toIso8601String();

String _dateFromNow(int offsetDays) {
  final d = DateTime.now().toUtc().add(Duration(days: offsetDays));
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

String _todayStr() {
  final d = DateTime.now().toUtc();
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

void main() {
  final engine = SuggestionEngine();
  final today = _todayStr();

  group('SuggestionEngine.compute', () {
    test('empty input returns empty list', () {
      final result = engine.compute([], today, {});
      expect(result, isEmpty);
    });

    test('birthday within 7 days scores 3 pts (type=birthday)', () {
      final person = _person(
        id: 'p1',
        name: 'Anna',
        birthday: _dateFromNow(3),
      );
      final result = engine.compute([person], today, {});
      expect(result, hasLength(1));
      expect(result.first.type, SuggestionType.birthday);
      expect(result.first.score, greaterThanOrEqualTo(3));
    });

    test('needsFollowUp=1 scores 2 pts (type=followUp)', () {
      final person = _person(
        id: 'p2',
        name: 'David',
        needsFollowUp: 1,
        lastInteractionAt: _daysAgo(10),
      );
      final result = engine.compute([person], today, {});
      expect(result, hasLength(1));
      expect(result.first.type, SuggestionType.followUp);
      expect(result.first.score, greaterThanOrEqualTo(2));
    });

    test('contact gap 90+ days scores 2 pts (type=reconnect)', () {
      final person = _person(
        id: 'p3',
        name: 'Lisa',
        lastInteractionAt: _daysAgo(95),
      );
      final result = engine.compute([person], today, {});
      expect(result, hasLength(1));
      expect(result.first.type, SuggestionType.reconnect);
      expect(result.first.score, greaterThanOrEqualTo(2));
    });

    test('contact gap 30-89 days scores 1 pt', () {
      final person = _person(
        id: 'p4',
        name: 'Mark',
        lastInteractionAt: _daysAgo(45),
      );
      final result = engine.compute([person], today, {});
      expect(result, hasLength(1));
      expect(result.first.score, greaterThanOrEqualTo(1));
    });

    test('results capped at 4', () {
      final people = List.generate(
        10,
        (i) => _person(
          id: 'p$i',
          name: 'Person $i',
          lastInteractionAt: _daysAgo(50 + i),
        ),
      );
      final result = engine.compute(people, today, {});
      expect(result.length, lessThanOrEqualTo(4));
    });

    test('contacts interacted with today are excluded', () {
      final person = _person(
        id: 'p5',
        name: 'Alex',
        lastInteractionAt: _daysAgo(60),
      );
      final result = engine.compute([person], today, {'p5'});
      expect(result, isEmpty);
    });

    test('contacts with no signal (recent contact, no flags) score 0', () {
      final person = _person(
        id: 'p6',
        name: 'Recent',
        lastInteractionAt: _daysAgo(5),
      );
      final result = engine.compute([person], today, {});
      // Score 0 means likely not suggested (or last in list)
      if (result.isNotEmpty) {
        expect(result.first.score, equals(0));
      }
    });

    test('birthday takes priority over reconnect when both apply', () {
      final birthdayPerson = _person(
        id: 'p7',
        name: 'Anna',
        birthday: _dateFromNow(1),
        lastInteractionAt: _daysAgo(95),
      );
      final reconnectPerson = _person(
        id: 'p8',
        name: 'Bob',
        lastInteractionAt: _daysAgo(100),
      );
      final result = engine.compute([birthdayPerson, reconnectPerson], today, {});
      expect(result.first.personId, equals('p7'));
    });

    test('results are sorted by score desc then name asc', () {
      final p1 = _person(id: 'pa', name: 'Zara', lastInteractionAt: _daysAgo(95));
      final p2 = _person(id: 'pb', name: 'Alice', lastInteractionAt: _daysAgo(95));
      final result = engine.compute([p1, p2], today, {});
      expect(result.length, equals(2));
      // Same score → alphabetical
      expect(result.first.personName, equals('Alice'));
    });

    test('signal text is non-empty for each suggestion type', () {
      final people = [
        _person(id: 'q1', name: 'A', birthday: _dateFromNow(2)),
        _person(id: 'q2', name: 'B', needsFollowUp: 1),
        _person(id: 'q3', name: 'C', lastInteractionAt: _daysAgo(100)),
      ];
      final result = engine.compute(people, today, {});
      for (final s in result) {
        expect(s.signalText, isNotEmpty);
      }
    });
  });
}
