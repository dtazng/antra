import 'package:drift/drift.dart' hide Column;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/database/daos/person_important_dates_dao.dart';
import 'package:antra/providers/database_provider.dart';

part 'person_important_dates_providers.g.dart';

/// Watches all non-deleted important dates for [personId], birthday first.
@riverpod
Stream<List<PersonImportantDate>> personImportantDates(
  PersonImportantDatesRef ref,
  String personId,
) async* {
  final db = await ref.watch(appDatabaseProvider.future);
  final dao = PersonImportantDatesDao(db);
  yield* dao.watchDatesForPerson(personId);
}

/// Adds a new important date for [personId].
@riverpod
class AddImportantDate extends _$AddImportantDate {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<String> call({
    required String personId,
    required String label,
    required bool isBirthday,
    required int month,
    required int day,
    int? year,
    int? reminderOffsetDays,
    String? reminderRecurrence,
    String? note,
  }) async {
    state = const AsyncLoading();
    try {
      final db = await ref.read(appDatabaseProvider.future);
      const deviceId = 'local';
      final dao = PersonImportantDatesDao(db);
      final id = await dao.create(
        personId: personId,
        label: label,
        isBirthday: isBirthday,
        month: month,
        day: day,
        year: year,
        reminderOffsetDays: reminderOffsetDays,
        reminderRecurrence: reminderRecurrence,
        note: note,
        deviceId: deviceId,
      );
      state = const AsyncData(null);
      return id;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

/// Updates an existing important date by [id].
@riverpod
class UpdateImportantDate extends _$UpdateImportantDate {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> call({
    required String id,
    required String label,
    required bool isBirthday,
    required int month,
    required int day,
    int? year,
    int? reminderOffsetDays,
    String? reminderRecurrence,
    String? note,
  }) async {
    state = const AsyncLoading();
    try {
      final db = await ref.read(appDatabaseProvider.future);
      final dao = PersonImportantDatesDao(db);
      await dao.updateDate(PersonImportantDatesCompanion(
        id: Value(id),
        label: Value(label),
        isBirthday: Value(isBirthday ? 1 : 0),
        month: Value(month),
        day: Value(day),
        year: Value(year),
        reminderOffsetDays: Value(reminderOffsetDays),
        reminderRecurrence: Value(reminderRecurrence),
        note: Value(note),
      ));
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

/// Soft-deletes an important date by [id].
@riverpod
class DeleteImportantDate extends _$DeleteImportantDate {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> call(String id) async {
    state = const AsyncLoading();
    try {
      final db = await ref.read(appDatabaseProvider.future);
      final dao = PersonImportantDatesDao(db);
      await dao.softDelete(id);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
