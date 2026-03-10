import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:antra/database/daos/sync_dao.dart';
import 'package:antra/providers/database_provider.dart';
import 'package:antra/services/api_client.dart';
import 'package:antra/services/sync_engine.dart';

part 'sync_status_provider.g.dart';

enum SyncState { idle, syncing, error }

class SyncStatus {
  final SyncState state;
  final int conflictCount;
  final String? lastError;

  const SyncStatus({
    this.state = SyncState.idle,
    this.conflictCount = 0,
    this.lastError,
  });

  SyncStatus copyWith({
    SyncState? state,
    int? conflictCount,
    String? lastError,
  }) =>
      SyncStatus(
        state: state ?? this.state,
        conflictCount: conflictCount ?? this.conflictCount,
        lastError: lastError ?? this.lastError,
      );
}

@Riverpod(keepAlive: true)
class SyncStatusNotifier extends _$SyncStatusNotifier {
  @override
  SyncStatus build() => const SyncStatus();

  /// Triggers a full sync cycle and updates state accordingly.
  Future<void> triggerSync() async {
    if (state.state == SyncState.syncing) return;

    state = state.copyWith(state: SyncState.syncing, lastError: null);
    try {
      final db = await ref.read(appDatabaseProvider.future);
      final engine = SyncEngine(
        db: db,
        apiClient: ApiClient(),
      );
      await engine.sync();

      // Count unresolved conflicts.
      final conflictRows =
          await (db.select(db.conflictRecords)
                ..where((t) => t.resolvedAt.isNull()))
              .get();

      state = state.copyWith(
        state: SyncState.idle,
        conflictCount: conflictRows.length,
        lastError: null,
      );
    } catch (e) {
      state = state.copyWith(
        state: SyncState.error,
        lastError: e.toString(),
      );
    }
  }
}
