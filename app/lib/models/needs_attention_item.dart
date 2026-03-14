/// Surface model for a follow-up suggestion that has become due.
///
/// Appears in the "Needs Attention" horizontal strip above the timeline.
/// Sourced from bullets where [followUpStatus] is 'pending' and
/// [followUpDate] <= today, or [followUpStatus] is 'snoozed' and
/// [followUpSnoozedUntil] <= today.
class NeedsAttentionItem {
  const NeedsAttentionItem({
    required this.bulletId,
    required this.content,
    required this.followUpDate,
    required this.followUpStatus,
    this.personId,
    this.personName,
  });

  /// ID of the source bullet (log entry with an attached follow-up).
  final String bulletId;

  /// Original log entry text — shown as context in the suggestion card.
  final String content;

  /// ISO date string (YYYY-MM-DD) of the scheduled follow-up.
  final String followUpDate;

  /// Always 'pending' in the Needs Attention view (snoozed items that
  /// have resurfaced are treated as pending for display purposes).
  final String followUpStatus;

  final String? personId;
  final String? personName;
}
