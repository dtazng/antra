import 'dart:convert';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/providers/database_provider.dart';

/// Bottom sheet for reviewing and resolving a sync conflict.
///
/// Shows local snapshot vs remote snapshot and lets the user choose:
/// - Keep Remote (server LWW winner already applied)
/// - Restore Local (reapply local snapshot)
/// - Dismiss (acknowledge without change)
class ConflictReviewSheet extends ConsumerWidget {
  final ConflictRecord conflict;

  const ConflictReviewSheet({super.key, required this.conflict});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localData = _parseSnapshot(conflict.localSnapshot);
    final remoteData = _parseSnapshot(conflict.remoteSnapshot);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                'Sync Conflict',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Entity: ${conflict.entityType} · ${conflict.entityId.substring(0, 8)}…',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SnapshotCard(
                  label: 'Your Version',
                  color: Colors.blue.shade50,
                  data: localData,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SnapshotCard(
                  label: 'Server Version',
                  color: Colors.green.shade50,
                  data: remoteData,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => _resolve(context, ref, 'dismissed'),
                child: const Text('Dismiss'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _resolve(context, ref, 'restored_local'),
                child: const Text('Restore Mine'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => _resolve(context, ref, 'kept_remote'),
                child: const Text('Keep Remote'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _resolve(
    BuildContext context,
    WidgetRef ref,
    String resolution,
  ) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final db = await ref.read(appDatabaseProvider.future);
    await (db.update(db.conflictRecords)
          ..where((t) => t.id.equals(conflict.id)))
        .write(
      ConflictRecordsCompanion(
        resolution: Value(resolution),
        resolvedAt: Value(now),
      ),
    );

    if (resolution == 'restored_local') {
      // Re-apply local snapshot to the relevant table.
      await _restoreLocal(db);
    }

    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _restoreLocal(AppDatabase db) async {
    final local = _parseSnapshot(conflict.localSnapshot);
    if (conflict.entityType == 'bullet' && local['id'] != null) {
      await db.into(db.bullets).insertOnConflictUpdate(
        BulletsCompanion.insert(
          id: local['id'] as String,
          dayId: local['dayId'] as String? ?? '',
          content: local['content'] as String? ?? '',
          type: Value(local['type'] as String? ?? 'note'),
          status: Value(local['status'] as String? ?? 'open'),
          position: local['position'] as int? ?? 0,
          createdAt: local['createdAt'] as String? ??
              DateTime.now().toUtc().toIso8601String(),
          updatedAt: local['updatedAt'] as String? ??
              DateTime.now().toUtc().toIso8601String(),
          deviceId: local['deviceId'] as String? ?? 'local',
        ),
      );
    }
  }

  Map<String, dynamic> _parseSnapshot(String json) {
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return {'raw': json};
    }
  }
}

class _SnapshotCard extends StatelessWidget {
  final String label;
  final Color color;
  final Map<String, dynamic> data;

  const _SnapshotCard({
    required this.label,
    required this.color,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final content = data['content'] as String? ??
        data['name'] as String? ??
        data.toString();
    final updatedAt = data['updatedAt'] as String?;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(content, style: const TextStyle(fontSize: 13)),
          if (updatedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              updatedAt.substring(0, 10),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }
}
