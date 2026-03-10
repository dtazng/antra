import 'package:drift/drift.dart';

/// Table: reviews
/// Structured reflection records tied to a week or month period.
class Reviews extends Table {
  TextColumn get id => text()();

  /// Period type: 'week' | 'month'
  TextColumn get periodType => text()();

  /// Period start date YYYY-MM-DD (inclusive).
  TextColumn get startDate => text()();

  /// Period end date YYYY-MM-DD (inclusive).
  TextColumn get endDate => text()();

  /// User's free-form summary notes for the period.
  TextColumn get summaryNotes => text().nullable()();

  /// ISO 8601 UTC timestamp when review was completed. Null = in progress.
  TextColumn get completedAt => text().nullable()();

  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  TextColumn get syncId => text().nullable().unique()();
  TextColumn get deviceId => text()();
  IntColumn get isDeleted => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
