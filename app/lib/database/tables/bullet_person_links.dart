import 'package:drift/drift.dart';

/// Table: bullet_person_links
/// Many-to-many junction: bullets ↔ people.
class BulletPersonLinks extends Table {
  /// FK → bullets.id
  TextColumn get bulletId => text()();

  /// FK → people.id
  TextColumn get personId => text()();

  TextColumn get createdAt => text()();

  /// How the link was created: 'mention' (from @capture bar) or 'manual' (from log detail).
  TextColumn get linkType => text().withDefault(const Constant('mention'))();

  TextColumn get syncId => text().nullable().unique()();
  TextColumn get deviceId => text()();
  IntColumn get isDeleted => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {bulletId, personId};
}
