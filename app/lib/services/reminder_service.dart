import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:antra/database/app_database.dart';

/// Schedules and cancels per-person check-in reminder notifications.
class ReminderService {
  ReminderService(this._notifications);

  final FlutterLocalNotificationsPlugin _notifications;

  static const _channelId = 'antra_reminders';
  static const _channelName = 'Check-in Reminders';

  /// Schedules (or reschedules) a reminder for [person] based on their
  /// [reminderCadenceDays] and [lastInteractionAt].
  ///
  /// No-op if either value is null.
  Future<void> scheduleReminder(PeopleData person) async {
    final cadence = person.reminderCadenceDays;
    final lastInteraction = person.lastInteractionAt;
    if (cadence == null || lastInteraction == null) return;

    // Cancel any existing notification first.
    await cancelReminder(person.id);

    final lastAt = DateTime.tryParse(lastInteraction);
    if (lastAt == null) return;

    final scheduledAt = lastAt.add(Duration(days: cadence));
    if (scheduledAt.isBefore(DateTime.now())) return;

    final notifId = _notifId(person.id);

    await _notifications.zonedSchedule(
      notifId,
      'Check in with ${person.name}',
      "It's been $cadence days since you last connected.",
      _toTZDateTime(scheduledAt),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancels any existing reminder notification for [personId].
  Future<void> cancelReminder(String personId) async {
    await _notifications.cancel(_notifId(personId));
  }

  /// Converts a person UUID to a stable integer notification ID.
  int _notifId(String personId) => personId.hashCode.abs() % 100000;

  /// Converts a [DateTime] to a `TZDateTime` (UTC) for scheduling.
  /// In production, use timezone package; here we use UTC as a safe default.
  dynamic _toTZDateTime(DateTime dt) {
    // flutter_local_notifications expects a TZDateTime from the timezone package.
    // Return UTC DateTime here — replace with tz.TZDateTime.from(dt, tz.local)
    // after adding the timezone dependency (T041-follow-up).
    return dt.toUtc();
  }
}
