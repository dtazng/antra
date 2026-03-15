/// A computed prompt surfaced in the Needs Attention section.
///
/// Prompt types:
/// - `important_date` — upcoming birthday or anniversary reminder
/// - `inactivity`     — haven't talked to this person in a while (US5)
/// - `follow_up`      — post-interaction follow-up suggestion (US5)
class SmartPrompt {
  const SmartPrompt({
    required this.id,
    required this.promptType,
    required this.personId,
    required this.personName,
    required this.title,
    required this.body,
    this.importantDateId,
    this.daysUntil,
  });

  /// Unique identifier used for dismissal lookups.
  final String id;

  /// One of: `important_date`, `inactivity`, `follow_up`.
  final String promptType;

  final String personId;
  final String personName;

  /// Short headline shown on the card (e.g. "Anna's birthday in 2 weeks 🎂").
  final String title;

  /// Supportive body copy (e.g. "Maybe send her a message.").
  final String body;

  /// Set for `important_date` prompts to scope dismissals to this date.
  final String? importantDateId;

  /// Calendar days until the event (used for display).
  final int? daysUntil;
}
