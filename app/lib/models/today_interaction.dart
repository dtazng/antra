/// An in-memory record of a bullet logged today.
/// Computed from bullets, optionally joined to bullet_person_links.
/// Not persisted separately — derived on read.
class TodayInteraction {
  const TodayInteraction({
    required this.bulletId,
    this.personId,
    this.personName,
    required this.content,
    required this.type,
    required this.loggedAt,
  });

  final String bulletId;

  /// Null when the entry has no linked person.
  final String? personId;

  /// Null when the entry has no linked person.
  final String? personName;

  /// Raw bullet content (the user's journal text).
  final String content;

  /// Bullet type: 'note' or 'task'.
  final String type;

  final DateTime loggedAt;
}
