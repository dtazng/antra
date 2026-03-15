/// User notification and follow-up preferences, synced with the backend.
class UserSettings {
  final bool notificationsEnabled;
  final bool followUpRemindersEnabled;
  final int? defaultFollowUpDays;

  const UserSettings({
    this.notificationsEnabled = true,
    this.followUpRemindersEnabled = true,
    this.defaultFollowUpDays,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) => UserSettings(
        notificationsEnabled: json['notifications_enabled'] as bool? ?? true,
        followUpRemindersEnabled:
            json['follow_up_reminders_enabled'] as bool? ?? true,
        defaultFollowUpDays: json['default_follow_up_days'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'notifications_enabled': notificationsEnabled,
        'follow_up_reminders_enabled': followUpRemindersEnabled,
        if (defaultFollowUpDays != null)
          'default_follow_up_days': defaultFollowUpDays,
      };

  UserSettings copyWith({
    bool? notificationsEnabled,
    bool? followUpRemindersEnabled,
    int? defaultFollowUpDays,
    bool clearDefaultFollowUpDays = false,
  }) =>
      UserSettings(
        notificationsEnabled:
            notificationsEnabled ?? this.notificationsEnabled,
        followUpRemindersEnabled:
            followUpRemindersEnabled ?? this.followUpRemindersEnabled,
        defaultFollowUpDays: clearDefaultFollowUpDays
            ? null
            : (defaultFollowUpDays ?? this.defaultFollowUpDays),
      );
}

/// Partial update payload for [UserSettings]. All fields are nullable —
/// only non-null fields are sent to the server.
class UserSettingsPatch {
  final bool? notificationsEnabled;
  final bool? followUpRemindersEnabled;
  final int? defaultFollowUpDays;

  const UserSettingsPatch({
    this.notificationsEnabled,
    this.followUpRemindersEnabled,
    this.defaultFollowUpDays,
  });

  Map<String, dynamic> toJson() => {
        if (notificationsEnabled != null)
          'notifications_enabled': notificationsEnabled,
        if (followUpRemindersEnabled != null)
          'follow_up_reminders_enabled': followUpRemindersEnabled,
        if (defaultFollowUpDays != null)
          'default_follow_up_days': defaultFollowUpDays,
      };
}
