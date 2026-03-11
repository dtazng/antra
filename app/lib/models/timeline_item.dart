import 'package:antra/database/app_database.dart';

/// Sealed class representing a single row in the full activity timeline.
/// Used by [PersonTimelineNotifier] to mix month headers and activity rows
/// in a single [SliverList].
sealed class TimelineItem {}

/// A month-year section header, e.g. "March 2026".
final class TimelineMonthHeader extends TimelineItem {
  final String label;
  TimelineMonthHeader(this.label);
}

/// An activity row wrapping a linked [Bullet].
final class TimelineActivityRow extends TimelineItem {
  final Bullet bullet;
  TimelineActivityRow(this.bullet);
}
