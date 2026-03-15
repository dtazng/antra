import 'package:drift/drift.dart';

/// Table: smart_prompt_dismissals
/// Tracks dismissed smart prompts to suppress re-surfacing before the
/// snooze/suppress window expires. Client-only — NOT synced to backend.
class SmartPromptDismissals extends Table {
  /// Auto-increment primary key.
  IntColumn get id => integer().autoIncrement()();

  /// FK → people.id. Null for global prompts.
  TextColumn get personId => text().nullable()();

  /// Prompt type: 'inactivity' | 'follow_up' | 'important_date'.
  TextColumn get promptType => text()();

  /// FK → person_important_dates.id. Set only for important_date type.
  TextColumn get importantDateId => text().nullable()();

  /// ISO date string (YYYY-MM-DD) after which the prompt may resurface.
  TextColumn get dismissedUntil => text()();

  /// ISO 8601 UTC creation timestamp.
  TextColumn get createdAt => text()();
}
