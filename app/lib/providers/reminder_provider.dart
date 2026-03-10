import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:antra/services/reminder_service.dart';

part 'reminder_provider.g.dart';

@Riverpod(keepAlive: true)
ReminderService reminderService(ReminderServiceRef ref) {
  return ReminderService(FlutterLocalNotificationsPlugin());
}
