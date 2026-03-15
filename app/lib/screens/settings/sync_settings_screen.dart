import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:antra/providers/sync_status_provider.dart';

class SyncSettingsScreen extends ConsumerWidget {
  const SyncSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(syncStatusNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sync & Data')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      _stateIcon(syncStatus.state),
                      color: _stateColor(context, syncStatus.state),
                    ),
                    title: Text(_stateLabel(syncStatus.state)),
                    subtitle: syncStatus.lastError != null
                        ? Text(
                            syncStatus.lastError!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          )
                        : null,
                  ),
                  if (syncStatus.conflictCount > 0) ...[
                    const Divider(indent: 16, height: 0),
                    ListTile(
                      leading: Icon(
                        Icons.warning_amber_rounded,
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                      title: Text(
                          '${syncStatus.conflictCount} unresolved conflict${syncStatus.conflictCount == 1 ? '' : 's'}'),
                      subtitle: const Text(
                        'Changes from another device were not merged',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.sync_rounded),
                title: const Text('Sync now'),
                trailing: syncStatus.state == SyncState.syncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: syncStatus.state == SyncState.syncing
                    ? null
                    : () async {
                        await ref
                            .read(syncStatusNotifierProvider.notifier)
                            .triggerSync();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ref.read(syncStatusNotifierProvider).state ==
                                        SyncState.error
                                    ? 'Sync failed'
                                    : 'Sync complete',
                              ),
                            ),
                          );
                        }
                      },
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _stateIcon(SyncState state) => switch (state) {
        SyncState.idle => Icons.check_circle_outline_rounded,
        SyncState.syncing => Icons.sync_rounded,
        SyncState.error => Icons.error_outline_rounded,
      };

  Color _stateColor(BuildContext context, SyncState state) {
    final cs = Theme.of(context).colorScheme;
    return switch (state) {
      SyncState.idle => cs.primary,
      SyncState.syncing => cs.secondary,
      SyncState.error => cs.error,
    };
  }

  String _stateLabel(SyncState state) => switch (state) {
        SyncState.idle => 'Up to date',
        SyncState.syncing => 'Syncing…',
        SyncState.error => 'Sync error',
      };
}
