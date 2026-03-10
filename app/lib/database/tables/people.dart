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

  // --- v3: CRM profile fields ---
  TextColumn get company => text().nullable()();
  TextColumn get role => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get phone => text().nullable()();

  /// ISO-8601 date string (YYYY-MM-DD). Null if not set.
  TextColumn get birthday => text().nullable()();
  TextColumn get location => text().nullable()();

  /// Comma-separated labels, e.g. "work,mentor". Null if no tags.
  TextColumn get tags => text().nullable()();

  /// One of: Friend | Family | Colleague | Mentor | Acquaintance | Other.
  TextColumn get relationshipType => text().nullable()();

  /// 1 = needs follow-up, 0 = no action needed.
  IntColumn get needsFollowUp => integer().withDefault(const Constant(0))();

  /// ISO-8601 date string for a specific follow-up deadline. Null if not set.
  TextColumn get followUpDate => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
