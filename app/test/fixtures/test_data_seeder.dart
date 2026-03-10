import 'package:antra/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Seeds the database with realistic test data for performance benchmarking
/// and integration testing.
///
/// Usage:
/// ```dart
/// await TestDataSeeder(db).seed(bulletCount: 10000, peopleCount: 100);
/// ```
class TestDataSeeder {
  final AppDatabase db;

  TestDataSeeder(this.db);

  /// Seeds [bulletCount] bullets spread across the past 365 days,
  /// with [peopleCount] people profiles, tags, and links.
  Future<void> seed({
    int bulletCount = 10000,
    int peopleCount = 100,
  }) async {
    final now = DateTime.now();
    final tagNames = _generateTagNames();
    final personNames = _generatePersonNames(peopleCount);

    // 1. Insert people.
    final personIds = <String>[];
    for (final name in personNames) {
      final id = _uuid.v4();
      personIds.add(id);
      final ts = now.toUtc().toIso8601String();
      await db.into(db.people).insert(
            PeopleCompanion.insert(
              id: id,
              name: name,
              createdAt: ts,
              updatedAt: ts,
              deviceId: 'seed',
            ),
          );
    }

    // 2. Upsert tags.
    final tagIds = <String, String>{}; // name → id
    for (final tag in tagNames) {
      final id = _uuid.v4();
      tagIds[tag] = id;
      final ts = now.toUtc().toIso8601String();
      await db.into(db.tags).insertOnConflictUpdate(
            TagsCompanion.insert(
              id: id,
              name: tag,
              createdAt: ts,
              deviceId: 'seed',
            ),
          );
    }

    // 3. Generate day_logs and bullets across the past 365 days.
    final dayLogIds = <String, String>{}; // date → id
    final types = ['task', 'note', 'event'];
    final statuses = ['open', 'complete', 'cancelled'];
    final sampleContents = [
      'Follow up with team about project status',
      'Buy groceries and prepare dinner',
      'Read chapter 3 of current book',
      'Team standup at 10am',
      'Dentist appointment',
      'Review pull request from colleague',
      'Write blog post draft',
      'Call mom and catch up',
      'Exercise: 30 min run',
      'Study Dart advanced patterns',
      'Deploy new feature to staging #work',
      'Coffee with #friends',
      'Budget review for the month #finance',
      'Meditate for 15 minutes',
      'Prepare slides for presentation #work',
    ];

    for (var i = 0; i < bulletCount; i++) {
      // Spread bullets across the past year.
      final dayOffset = i % 365;
      final date = now.subtract(Duration(days: dayOffset));
      final dateKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      // Ensure day_log exists.
      if (!dayLogIds.containsKey(dateKey)) {
        final id = _uuid.v4();
        dayLogIds[dateKey] = id;
        final ts = date.toUtc().toIso8601String();
        await db.into(db.dayLogs).insertOnConflictUpdate(
              DayLogsCompanion.insert(
                id: id,
                date: dateKey,
                createdAt: ts,
                updatedAt: ts,
                deviceId: 'seed',
              ),
            );
      }

      final dayId = dayLogIds[dateKey]!;
      final bulletId = _uuid.v4();
      final type = types[i % types.length];
      final status = type == 'task' ? statuses[i % statuses.length] : 'open';
      final content = sampleContents[i % sampleContents.length];
      final ts = date.toUtc().toIso8601String();

      await db.into(db.bullets).insert(
            BulletsCompanion.insert(
              id: bulletId,
              dayId: dayId,
              type: Value(type),
              content: content,
              status: Value(status),
              position: i % 20,
              createdAt: ts,
              updatedAt: ts,
              deviceId: 'seed',
            ),
          );

      // Link ~20% of bullets to a random person.
      if (i % 5 == 0 && personIds.isNotEmpty) {
        final personId = personIds[i % personIds.length];
        await db.into(db.bulletPersonLinks).insertOnConflictUpdate(
              BulletPersonLinksCompanion.insert(
                bulletId: bulletId,
                personId: personId,
                createdAt: ts,
                deviceId: 'seed',
              ),
            );
        // Update last interaction.
        await (db.update(db.people)..where((t) => t.id.equals(personId))).write(
          PeopleCompanion(
            lastInteractionAt: Value(ts),
            updatedAt: Value(ts),
          ),
        );
      }

      // Link ~30% of bullets to a random tag.
      if (i % 3 == 0 && tagIds.isNotEmpty) {
        final tagName = tagNames[i % tagNames.length];
        final tagId = tagIds[tagName]!;
        await db.into(db.bulletTagLinks).insertOnConflictUpdate(
              BulletTagLinksCompanion.insert(
                bulletId: bulletId,
                tagId: tagId,
                createdAt: ts,
                deviceId: 'seed',
              ),
            );
      }
    }
  }

  List<String> _generateTagNames() => [
        'work',
        'personal',
        'finance',
        'health',
        'learning',
        'friends',
        'family',
        'project',
        'ideas',
        'urgent',
      ];

  List<String> _generatePersonNames(int count) {
    final base = [
      'Alice', 'Bob', 'Carol', 'Dave', 'Eve',
      'Frank', 'Grace', 'Henry', 'Iris', 'Jack',
      'Kate', 'Leo', 'Mia', 'Noah', 'Olivia',
      'Paul', 'Quinn', 'Rose', 'Sam', 'Tara',
    ];
    final result = <String>[];
    for (var i = 0; i < count; i++) {
      result.add('${base[i % base.length]} ${i ~/ base.length + 1}');
    }
    return result;
  }
}
