import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:antra/database/app_database.dart';

part 'person_important_dates_dao.g.dart';

const _uuid = Uuid();

@DriftAccessor(tables: [PersonImportantDates])
class PersonImportantDatesDao extends DatabaseAccessor<AppDatabase>
    with _$PersonImportantDatesDaoMixin {
  PersonImportantDatesDao(super.db);

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  /// Watches all non-deleted important dates for [personId].
  /// Birthday rows (isBirthday = 1) always sort first, then by month/day.
  Stream<List<PersonImportantDate>> watchDatesForPerson(String personId) {
    return (select(personImportantDates)
          ..where(
            (t) => t.personId.equals(personId) & t.isDeleted.equals(0),
          )
          ..orderBy([
            (t) => OrderingTerm.desc(t.isBirthday),
            (t) => OrderingTerm.asc(t.month),
            (t) => OrderingTerm.asc(t.day),
          ]))
        .watch();
  }

  /// Fetches all non-deleted important dates across all persons.
  Future<List<PersonImportantDate>> getAllActiveDates() {
    return (select(personImportantDates)
          ..where((t) => t.isDeleted.equals(0)))
        .get();
  }

  /// Fetches a single date by [id]. Returns null if not found or deleted.
  Future<PersonImportantDate?> getById(String id) {
    return (select(personImportantDates)
          ..where((t) => t.id.equals(id) & t.isDeleted.equals(0)))
        .getSingleOrNull();
  }

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  /// Inserts a new important date. The companion must supply a client-generated [id].
  Future<void> insert(PersonImportantDatesCompanion companion) async {
    await into(personImportantDates).insert(companion);
  }

  /// Creates and inserts an important date from individual fields.
  /// Returns the generated id.
  Future<String> create({
    required String personId,
    required String label,
    required bool isBirthday,
    required int month,
    required int day,
    int? year,
    int? reminderOffsetDays,
    String? reminderRecurrence,
    String? note,
    required String deviceId,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await into(personImportantDates).insert(
      PersonImportantDatesCompanion.insert(
        id: id,
        personId: personId,
        label: label,
        isBirthday: Value(isBirthday ? 1 : 0),
        month: month,
        day: day,
        year: Value(year),
        reminderOffsetDays: Value(reminderOffsetDays),
        reminderRecurrence: Value(reminderRecurrence),
        note: Value(note),
        createdAt: now,
        updatedAt: now,
        deviceId: deviceId,
      ),
    );
    return id;
  }

  /// Updates an existing important date.
  Future<void> updateDate(PersonImportantDatesCompanion companion) async {
    await (update(personImportantDates)
          ..where((t) => t.id.equals(companion.id.value)))
        .write(companion.copyWith(
      updatedAt: Value(DateTime.now().toUtc().toIso8601String()),
    ));
  }

  /// Soft-deletes an important date by setting isDeleted = 1.
  Future<void> softDelete(String id) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(personImportantDates)
          ..where((t) => t.id.equals(id)))
        .write(PersonImportantDatesCompanion(
      isDeleted: const Value(1),
      updatedAt: Value(now),
    ));
  }
}
