import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:antra/providers/sync_status_provider.dart';

/// A compact sync-status indicator intended for app bar actions or subtitles.
///
/// Shows:
/// - A spinning indicator while syncing
/// - A conflict badge (!) with count when unresolved conflicts exist
/// - Nothing when idle with no conflicts (stays out of the way)
class SyncStatusBar extends ConsumerWidget {
  const SyncStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusNotifierProvider);

    if (status.state == SyncState.syncing) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (status.state == SyncState.error) {
      return Tooltip(
        message: status.lastError ?? 'Sync error',
        child: const Icon(Icons.sync_problem, color: Colors.red, size: 20),
      );
    }

    if (status.conflictCount > 0) {
      return Badge(
        label: Text('${status.conflictCount}'),
        child: const Icon(Icons.sync_problem, color: Colors.orange, size: 20),
      );
    }

    return const SizedBox.shrink();
  }
}
