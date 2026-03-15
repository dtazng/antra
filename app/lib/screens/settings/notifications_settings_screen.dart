import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:antra/models/user_settings.dart';
import 'package:antra/providers/user_settings_provider.dart';

class NotificationsSettingsScreen extends ConsumerWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(userSettingsNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (settings) => _NotificationsBody(settings: settings),
      ),
    );
  }
}

class _NotificationsBody extends ConsumerWidget {
  final UserSettings settings;
  const _NotificationsBody({required this.settings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(userSettingsNotifierProvider.notifier);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Push notifications'),
                  subtitle: const Text(
                    'Receive updates and alerts',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: settings.notificationsEnabled,
                  onChanged: (v) => notifier.applyPatch(
                    UserSettingsPatch(notificationsEnabled: v),
                  ),
                ),
                const Divider(indent: 16, height: 0),
                SwitchListTile(
                  title: const Text('Follow-up reminders'),
                  subtitle: const Text(
                    'Get reminded about scheduled follow-ups',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: settings.followUpRemindersEnabled,
                  onChanged: settings.notificationsEnabled
                      ? (v) => notifier.applyPatch(
                            UserSettingsPatch(followUpRemindersEnabled: v),
                          )
                      : null,
                ),
              ],
            ),
          ),
        ),
        if (settings.followUpRemindersEnabled && settings.notificationsEnabled)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                title: const Text('Default follow-up days'),
                subtitle: const Text(
                  'Days after log creation to send reminder',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: _DaysPicker(
                  value: settings.defaultFollowUpDays ?? 3,
                  onChanged: (v) => notifier.applyPatch(
                    UserSettingsPatch(defaultFollowUpDays: v),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DaysPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _DaysPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButton<int>(
      value: value,
      underline: const SizedBox.shrink(),
      items: [1, 2, 3, 5, 7, 14, 30]
          .map((d) => DropdownMenuItem(value: d, child: Text('$d days')))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
