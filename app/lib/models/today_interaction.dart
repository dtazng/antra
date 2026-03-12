/// An in-memory record of a person-linked interaction logged today.
/// Computed from bullets + bullet_person_links joined to today's day_log.
/// Not persisted separately — derived on read.
class TodayInteraction {
  const TodayInteraction({
    required this.bulletId,
    required this.personId,
    required this.personName,
    required this.content,
    required this.type,
    required this.interactionLabel,
    required this.loggedAt,
  });

  final String bulletId;
  final String personId;
  final String personName;

  /// Raw bullet content, e.g. "☕ Coffee with Alex".
  final String content;

  /// Bullet type: 'event' or 'note'.
  final String type;

  /// Derived human-readable label: "Coffee", "Call", "Message", or "Note".
  final String interactionLabel;

  final DateTime loggedAt;

  /// Derives [interactionLabel] from bullet [content] and [type].
  static String labelFromContent(String content, String type) {
    if (content.startsWith('☕')) return 'Coffee';
    if (content.startsWith('📞')) return 'Call';
    if (content.startsWith('✉️')) return 'Message';
    if (type == 'note') return 'Note';
    return 'Interaction';
  }
}
