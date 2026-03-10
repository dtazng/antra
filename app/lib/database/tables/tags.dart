import 'package:drift/drift.dart';

/// Table: tags
/// Labels for thematic organization. Created implicitly on first use.
class Tags extends Table {
  TextColumn get id => text()();

  /// Lowercase normalized tag name (without #). Globally unique.
  TextColumn get name => text().unique()();

  TextColumn get createdAt => text()();
  TextColumn get syncId => text().nullable().unique()();
  TextColumn get deviceId => text()();
  IntColumn get isDeleted => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
