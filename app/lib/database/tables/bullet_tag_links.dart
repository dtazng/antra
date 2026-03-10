import 'package:drift/drift.dart';

/// Table: bullet_tag_links
/// Many-to-many junction: bullets ↔ tags.
class BulletTagLinks extends Table {
  /// FK → bullets.id
  TextColumn get bulletId => text()();

  /// FK → tags.id
  TextColumn get tagId => text()();

  TextColumn get createdAt => text()();
  TextColumn get syncId => text().nullable().unique()();
  TextColumn get deviceId => text()();
  IntColumn get isDeleted => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {bulletId, tagId};
}
