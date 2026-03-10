import 'package:drift/drift.dart';

/// Table: task_lifecycle_events
/// Append-only log of every state transition for a task (bullet of type 'task').
/// Events are local-only in v1 — sync integration is deferred.
class TaskLifecycleEvents extends Table {
  /// Client-generated UUID primary key.
  TextColumn get id => text()();

  /// FK → bullets.id. The task this event belongs to.
  TextColumn get bulletId => text()();

  /// Event type string. One of:
  /// 'created' | 'carried_over' | 'kept_for_today' | 'scheduled' |
  /// 'moved_to_backlog' | 'reactivated' | 'entered_weekly_review' |
  /// 'completed' | 'canceled' | 'converted_to_note'
  TextColumn get eventType => text()();

  /// Optional JSON metadata for the event (e.g. '{"scheduledDate":"2025-03-15"}').
  TextColumn get metadata => text().nullable()();

  /// ISO 8601 UTC timestamp when this event occurred.
  TextColumn get occurredAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}
