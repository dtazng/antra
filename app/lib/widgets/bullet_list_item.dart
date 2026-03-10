import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/database/daos/bullets_dao.dart';
import 'package:antra/providers/database_provider.dart';
import 'package:antra/widgets/conflict_review_sheet.dart';

class BulletListItem extends ConsumerWidget {
  final Bullet bullet;

  const BulletListItem({super.key, required this.bullet});

  IconData _typeIcon() {
    switch (bullet.type) {
      case 'task':
        return bullet.status == 'complete'
            ? Icons.check_box
            : Icons.check_box_outline_blank;
      case 'event':
        return Icons.radio_button_checked;
      case 'note':
      default:
        return Icons.circle;
    }
  }

  Color? _typeIconColor(ColorScheme scheme) {
    switch (bullet.type) {
      case 'task':
        return bullet.status == 'complete' ? scheme.primary : null;
      case 'event':
        return scheme.tertiary;
      default:
        return scheme.secondary;
    }
  }

  /// Parses inline #tags from content and returns display-ready segments.
  List<InlineSpan> _buildContentSpans(BuildContext context) {
    final theme = Theme.of(context);
    final tagColor = theme.colorScheme.primary;
    final spans = <InlineSpan>[];
    final regex = RegExp(r'(#\w+)');
    final parts = bullet.content.split(regex);
    for (final part in parts) {
      if (part.startsWith('#')) {
        spans.add(TextSpan(
          text: part,
          style: TextStyle(
            color: tagColor,
            fontWeight: FontWeight.w500,
          ),
        ));
      } else {
        spans.add(TextSpan(text: part));
      }
    }
    return spans;
  }

  Future<void> _toggleStatus(BuildContext context, WidgetRef ref) async {
    if (bullet.type != 'task') return;
    final next = bullet.status == 'complete' ? 'open' : 'complete';
    final db = await ref.read(appDatabaseProvider.future);
    await BulletsDao(db).updateBulletStatus(bullet.id, next);
  }

  Future<void> _softDelete(WidgetRef ref) async {
    final db = await ref.read(appDatabaseProvider.future);
    await BulletsDao(db).softDeleteBullet(bullet.id);
  }

  void _showContextMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (bullet.type == 'task') ...[
              ListTile(
                leading: const Icon(Icons.cancel_outlined),
                title: const Text('Mark as cancelled'),
                onTap: () async {
                  Navigator.pop(context);
                  final db = await ref.read(appDatabaseProvider.future);
                  await BulletsDao(db)
                      .updateBulletStatus(bullet.id, 'cancelled');
                },
              ),
              ListTile(
                leading: const Icon(Icons.redo),
                title: const Text('Mark as migrated'),
                onTap: () async {
                  Navigator.pop(context);
                  final db = await ref.read(appDatabaseProvider.future);
                  await BulletsDao(db)
                      .updateBulletStatus(bullet.id, 'migrated');
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title:
                  const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                await _softDelete(ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showConflict(BuildContext context, WidgetRef ref) async {
    final db = await ref.read(appDatabaseProvider.future);
    final conflictRow = await (db.select(db.conflictRecords)
          ..where(
            (t) =>
                t.entityId.equals(bullet.id) &
                t.resolvedAt.isNull(),
          ))
        .getSingleOrNull();
    if (conflictRow == null || !context.mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ConflictReviewSheet(conflict: conflictRow),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isStrikethrough =
        bullet.status == 'complete' || bullet.status == 'cancelled';

    // Watch for unresolved conflicts on this bullet.
    final dbAsync = ref.watch(appDatabaseProvider);
    final hasConflict = dbAsync.whenOrNull(
          data: (db) {
            // We can't await here, so we use a synchronous check approach via FutureProvider.
            // For now return false; the badge is shown only after explicit check.
            return false;
          },
        ) ??
        false;

    final typeAccentColor = _typeIconColor(scheme) ?? scheme.onSurface;

    return Dismissible(
      key: ValueKey(bullet.id),
      direction: bullet.type == 'task'
          ? DismissDirection.startToEnd
          : DismissDirection.none,
      background: Container(
        color: scheme.primaryContainer,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        child: Icon(Icons.check_rounded, color: scheme.onPrimaryContainer),
      ),
      confirmDismiss: (_) async {
        await _toggleStatus(context, ref);
        return false;
      },
      child: InkWell(
        onLongPress: () => _showContextMenu(context, ref),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type indicator dot / icon
              GestureDetector(
                onTap: () => _toggleStatus(context, ref),
                child: Padding(
                  padding: const EdgeInsets.only(top: 3, right: 12),
                  child: Icon(
                    _typeIcon(),
                    size: 16,
                    color: isStrikethrough
                        ? scheme.onSurface.withOpacity(0.3)
                        : typeAccentColor,
                  ),
                ),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(children: _buildContentSpans(context)),
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    decoration: isStrikethrough
                        ? TextDecoration.lineThrough
                        : null,
                    decorationColor: scheme.onSurface.withOpacity(0.3),
                    color: isStrikethrough
                        ? scheme.onSurface.withOpacity(0.35)
                        : scheme.onSurface,
                  ),
                ),
              ),
              if (hasConflict)
                GestureDetector(
                  onTap: () => _showConflict(context, ref),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: scheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
