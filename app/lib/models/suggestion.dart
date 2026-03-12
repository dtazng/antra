/// Suggestion type — determines which signal triggered the suggestion
/// and which action buttons appear in the expanded card.
enum SuggestionType { reconnect, birthday, followUp, memory }

/// Actions available on an expanded [SuggestionCard].
/// Not all actions apply to all card types — see ui-contracts.md Component 3.
enum SuggestionAction {
  message,
  call,
  logMeeting,
  sendGreeting,
  logCall,
  followUp,
  scheduleLater,
  markDone,
  logNote,
}

/// An in-memory relationship suggestion computed by [SuggestionEngine].
/// Not persisted to the database.
class Suggestion {
  const Suggestion({
    required this.type,
    required this.personId,
    required this.personName,
    required this.signalText,
    required this.score,
    this.personNotes,
    this.metadata = const {},
  });

  final SuggestionType type;
  final String personId;
  final String personName;

  /// Optional context notes from people.notes. Shown in expanded card.
  final String? personNotes;

  /// Human-readable signal, e.g. "Last contact: 32 days ago".
  final String signalText;

  /// Priority score — higher = shown first.
  final int score;

  /// Type-specific extra data, e.g. {daysAgo: 32} or {birthdayDate: '03-15'}.
  final Map<String, dynamic> metadata;
}
