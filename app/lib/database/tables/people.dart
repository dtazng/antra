import 'package:drift/drift.dart';

/// Table: people
/// A person profile entry representing a relationship.
class People extends Table {
  TextColumn get id => text()();

  /// Display name. Shown in @mention suggestions.
  TextColumn get name => text()();

  /// Optional context notes about this person.
  TextColumn get notes => text().nullable()();

  /// Days between check-in reminders. Null = no reminder set.
  IntColumn get reminderCadenceDays => integer().nullable()();

  /// ISO 8601 UTC timestamp of last logged interaction.
  /// Denormalized cache updated on every bullet_person_link insert.
  TextColumn get lastInteractionAt => text().nullable()();

  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  TextColumn get syncId => text().nullable().unique()();
  TextColumn get deviceId => text()();
  IntColumn get isDeleted => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
