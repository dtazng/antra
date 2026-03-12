/// Daily relationship goal — computed from COUNT(DISTINCT personId) in
/// bullet_person_links for today. Not persisted; derived on read.
class DailyGoal {
  const DailyGoal({
    required this.reached,
    this.target = 3,
  });

  /// Number of distinct people reached today.
  final int reached;

  /// Target contact count. Always 3 for MVP.
  final int target;

  bool get completed => reached >= target;
}
