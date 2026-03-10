import 'package:drift/drift.dart';

/// Table: bullet_person_links
/// Many-to-many junction: bullets ↔ people.
class BulletPersonLinks extends Table {
  /// FK → bullets.id
  TextColumn get bulletId => text()();

  /// FK → people.id
  TextColumn get personId => text()();

  TextColumn get createdAt => text()();
  TextColumn get syncId => text().nullable().unique()();
  TextColumn get deviceId => text()();
  IntColumn get isDeleted => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {bulletId, personId};
}
