import 'package:drift/drift.dart';

/// Table: collections
/// Named, saved filter views. Dynamically populate from filter_rules.
class Collections extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();

  /// JSON array of filter rule objects:
  /// [{"type":"tag","value":"work"}, {"type":"person","personId":"uuid"}, ...]
  TextColumn get filterRules => text()();

  /// Display order in the collections tab.
  IntColumn get position => integer()();

  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  TextColumn get syncId => text().nullable().unique()();
  TextColumn get deviceId => text()();
  IntColumn get isDeleted => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
