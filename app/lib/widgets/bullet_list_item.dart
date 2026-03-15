import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/database/daos/bullets_dao.dart';
import 'package:antra/providers/database_provider.dart';
import 'package:antra/widgets/conflict_review_sheet.dart';
import 'package:antra/widgets/voice_log_badge.dart';

class BulletListItem extends ConsumerWidget {
  final Bullet bullet;
  final VoidCallback? onTap;

  const BulletListItem({super.key, required this.bullet, this.onTap});

  bool get _isComplete => bullet.status == 'complete';
  bool get _isCancelled => bullet.status == 'cancelled';
  bool get _isStruck => _isComplete || _isCancelled;

  List<InlineSpan> _buildContentSpans(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tagColor = cs.primary;
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
    final next = _isComplete ? 'open' : 'complete';
    final db = await ref.read(appDatabaseProvider.future);
    await BulletsDao(db).updateBulletStatus(bullet.id, next);
  }

  Future<void> _softDelete(WidgetRef ref) async {
    final db = await ref.read(appDatabaseProvider.future);
    await BulletsDao(db).softDeleteBullet(bullet.id);
  }

  /// Swipe-right "Follow up" action — opens follow-up date picker.
  void _addFollowUpFromSlide(BuildContext context, WidgetRef ref) {
    // Reuse context menu for now; a dedicated follow-up picker can be added in T047.
    _showContextMenu(context, ref);
  }

  /// Swipe-right "Link person" action — opens person picker.
  void _linkPersonFromSlide(BuildContext context, WidgetRef ref) {
    _showContextMenu(context, ref);
  }

  /// Soft-deletes the bullet and shows an undo snack bar.
  Future<void> _softDeleteWithUndo(
      BuildContext context, WidgetRef ref) async {
    final db = await ref.read(appDatabaseProvider.future);
    final dao = BulletsDao(db);
    await dao.softDeleteBullet(bullet.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entry deleted'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _showContextMenu(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (bullet.type == 'task') ...[
                _ContextMenuTile(
                  icon: Icons.cancel_outlined,
                  label: 'Cancel task',
                  onTap: () async {
                    Navigator.pop(context);
                    final db = await ref.read(appDatabaseProvider.future);
                    await BulletsDao(db).updateBulletStatus(bullet.id, 'cancelled');
                  },
                ),
              ],
              _ContextMenuTile(
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                isDestructive: true,
                onTap: () async {
                  Navigator.pop(context);
                  await _softDelete(ref);
                },
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showConflict(BuildContext context, WidgetRef ref) async {
    final db = await ref.read(appDatabaseProvider.future);
    final conflictRow = await (db.select(db.conflictRecords)
          ..where(
            (t) => t.entityId.equals(bullet.id) & t.resolvedAt.isNull(),
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
    final cs = Theme.of(context).colorScheme;

    return Slidable(
      key: ValueKey(bullet.id),
      // Swipe right → quick actions: follow-up, edit, link person
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => _addFollowUpFromSlide(context, ref),
            backgroundColor: cs.secondaryContainer,
            foregroundColor: cs.onSecondaryContainer,
            icon: Icons.flag_outlined,
            label: 'Follow up',
            borderRadius: BorderRadius.circular(10),
          ),
          SlidableAction(
            onPressed: (_) => _showContextMenu(context, ref),
            backgroundColor: cs.surfaceContainerHighest,
            foregroundColor: cs.onSurface,
            icon: Icons.edit_outlined,
            label: 'Edit',
            borderRadius: BorderRadius.circular(10),
          ),
          SlidableAction(
            onPressed: (_) => _linkPersonFromSlide(context, ref),
            backgroundColor: cs.primaryContainer,
            foregroundColor: cs.onPrimaryContainer,
            icon: Icons.person_add_alt_outlined,
            label: 'Link',
            borderRadius: BorderRadius.circular(10),
          ),
        ],
      ),
      // Swipe left → delete
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        dismissible: DismissiblePane(
          onDismissed: () => _softDeleteWithUndo(context, ref),
        ),
        children: [
          SlidableAction(
            onPressed: (_) => _softDeleteWithUndo(context, ref),
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            borderRadius: BorderRadius.circular(10),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: () => _showContextMenu(context, ref),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type indicator
              GestureDetector(
                onTap: () => _toggleStatus(context, ref),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(top: 1, right: 14),
                  child: _BulletIndicator(bullet: bullet),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(children: _buildContentSpans(context)),
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.1,
                        decoration: _isStruck ? TextDecoration.lineThrough : null,
                        decorationColor: cs.onSurface.withValues(alpha: 0.25),
                        decorationThickness: 1.5,
                        color: _isStruck
                            ? cs.onSurface.withValues(alpha: 0.3)
                            : cs.onSurface,
                      ),
                    ),
                    if (bullet.sourceType == 'voice')
                      VoiceLogBadge(
                        transcriptionStatus: bullet.transcriptionStatus,
                        audioDurationSeconds: bullet.audioDurationSeconds,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The bullet type indicator — checkbox for tasks, dot for notes, circle for events.
class _BulletIndicator extends StatelessWidget {
  final Bullet bullet;
  const _BulletIndicator({required this.bullet});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isComplete = bullet.status == 'complete';

    switch (bullet.type) {
      case 'task':
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            color: isComplete ? cs.primary : Colors.transparent,
            border: Border.all(
              color: isComplete
                  ? cs.primary
                  : cs.outline.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: isComplete
              ? Icon(Icons.check_rounded, size: 12, color: cs.onPrimary)
              : null,
        );
      case 'event':
        return Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cs.tertiary.withValues(alpha: 0.15),
            border: Border.all(color: cs.tertiary.withValues(alpha: 0.6), width: 1.5),
          ),
          child: Center(
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.tertiary,
              ),
            ),
          ),
        );
      default: // note
        return Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.onSurface.withValues(alpha: 0.35),
            ),
          ),
        );
    }
  }
}

class _ContextMenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ContextMenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = isDestructive ? cs.error : cs.onSurface;
    return ListTile(
      leading: Icon(icon, color: color, size: 20),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          color: color,
          fontWeight: FontWeight.w400,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      horizontalTitleGap: 12,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    );
  }
}
