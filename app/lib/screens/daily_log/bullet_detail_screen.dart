import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/database/daos/bullets_dao.dart';
import 'package:antra/database/daos/people_dao.dart';
import 'package:antra/models/linked_person.dart';
import 'package:antra/providers/database_provider.dart';
import 'package:antra/providers/people_provider.dart';
import 'package:antra/providers/task_lifecycle_provider.dart';
import 'package:antra/screens/daily_log/task_detail_screen.dart';
import 'package:antra/screens/people/person_picker_sheet.dart';
import 'package:antra/screens/people/person_profile_screen.dart';
import 'package:antra/services/transcription_service.dart';
import 'package:antra/widgets/audio_player_widget.dart';
import 'package:antra/widgets/person_chip.dart';

/// Detail screen for notes and events.
///
/// Usage:
/// ```dart
/// Navigator.of(context).push(
///   MaterialPageRoute(builder: (_) => BulletDetailScreen(bulletId: id)),
/// );
/// ```
class BulletDetailScreen extends ConsumerStatefulWidget {
  final String bulletId;

  const BulletDetailScreen({super.key, required this.bulletId});

  @override
  ConsumerState<BulletDetailScreen> createState() => _BulletDetailScreenState();
}

class _BulletDetailScreenState extends ConsumerState<BulletDetailScreen> {
  bool _editingContent = false;
  late TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveContent(Bullet bullet) async {
    final newContent = _contentController.text.trim();
    if (newContent.isEmpty || newContent == bullet.content) {
      setState(() => _editingContent = false);
      return;
    }
    final db = await ref.read(appDatabaseProvider.future);
    await (db.update(db.bullets)..where((t) => t.id.equals(bullet.id))).write(
      BulletsCompanion(
        content: Value(newContent),
        updatedAt: Value(DateTime.now().toUtc().toIso8601String()),
      ),
    );
    if (mounted) setState(() => _editingContent = false);
  }

  Future<void> _setScheduledDate(Bullet bullet, String? dateStr) async {
    final db = await ref.read(appDatabaseProvider.future);
    await (db.update(db.bullets)..where((t) => t.id.equals(bullet.id))).write(
      BulletsCompanion(
        scheduledDate: Value(dateStr),
        updatedAt: Value(DateTime.now().toUtc().toIso8601String()),
      ),
    );
  }

  Future<void> _addFollowUp(Bullet bullet) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: bullet.followUpDate != null
          ? DateTime.tryParse(bullet.followUpDate!) ?? now
          : now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    final db = await ref.read(appDatabaseProvider.future);
    await BulletsDao(db).addFollowUpToEntry(
      bullet.id,
      DateFormat('yyyy-MM-dd').format(picked),
    );
  }

  Future<void> _convertToTask(Bullet bullet) async {
    final db = await ref.read(appDatabaseProvider.future);
    await (db.update(db.bullets)..where((t) => t.id.equals(bullet.id))).write(
      BulletsCompanion(
        type: const Value('task'),
        status: const Value('open'),
        updatedAt: Value(DateTime.now().toUtc().toIso8601String()),
      ),
    );
    if (!mounted) return;
    // Replace this screen with the task detail screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => TaskDetailScreen(bulletId: bullet.id),
      ),
    );
  }

  Future<void> _deleteBullet(Bullet bullet) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete?'),
        content: Text(
          'Delete this ${bullet.type}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final db = await ref.read(appDatabaseProvider.future);
    await BulletsDao(db).softDeleteBullet(bullet.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bulletAsync = ref.watch(singleBulletProvider(widget.bulletId));
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: const CloseButton(),
        title: bulletAsync.whenOrNull(
              data: (b) => Text(b?.type == 'event' ? 'Event' : 'Note'),
            ) ??
            const Text('Detail'),
        actions: [
          bulletAsync.whenOrNull(
                data: (b) {
                  if (b == null) return null;
                  return IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () => _deleteBullet(b),
                    color: cs.error,
                  );
                },
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: bulletAsync.when(
        data: (bullet) {
          if (bullet == null) {
            return const Center(child: Text('Not found.'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type badge
                _TypeBadge(type: bullet.type),
                const SizedBox(height: 12),

                // Linked person
                _LinkedPersonSection(bulletId: bullet.id),
                const SizedBox(height: 4),

                // Content (editable)
                _ContentSection(
                  bullet: bullet,
                  editing: _editingContent,
                  controller: _contentController,
                  onTap: () {
                    _contentController.text = bullet.content;
                    setState(() => _editingContent = true);
                  },
                  onSave: () => _saveContent(bullet),
                  onCancel: () => setState(() => _editingContent = false),
                ),
                const SizedBox(height: 16),

                // Voice log: audio player + retry button
                if (bullet.sourceType == 'voice') ...[
                  const SizedBox(height: 12),
                  _VoiceLogSection(bullet: bullet),
                ],

                // Tags extracted from content
                _TagsRow(content: bullet.content),

                // Event date row
                if (bullet.type == 'event') ...[
                  const SizedBox(height: 12),
                  _EventDateRow(
                    bullet: bullet,
                    onSetDate: (dateStr) => _setScheduledDate(bullet, dateStr),
                    onClearDate: () => _setScheduledDate(bullet, null),
                  ),
                ],

                // Follow-up date
                const SizedBox(height: 12),
                _FollowUpRow(
                  bullet: bullet,
                  onSetFollowUp: () => _addFollowUp(bullet),
                ),

                // Created at
                const SizedBox(height: 16),
                _CreatedAtRow(createdAt: bullet.createdAt),
                const SizedBox(height: 28),

                // Actions
                _ActionsSection(
                  bullet: bullet,
                  onConvertToTask: () => _convertToTask(bullet),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Voice log section
// ─────────────────────────────────────────────────────────────────────────────

class _VoiceLogSection extends ConsumerWidget {
  const _VoiceLogSection({required this.bullet});
  final Bullet bullet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAudio = bullet.audioFilePath?.isNotEmpty == true;
    final status = bullet.transcriptionStatus;
    final canRetry = status == 'failed' || status == 'pending';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.mic_rounded, size: 14, color: Colors.grey),
            const SizedBox(width: 6),
            Text(
              status == 'transcribing'
                  ? 'Transcribing audio…'
                  : status == 'failed'
                      ? 'Transcription failed'
                      : status == 'pending'
                          ? 'Transcription pending'
                          : 'Voice note',
              style: const TextStyle(
                  fontSize: 12, color: Colors.grey),
            ),
            if (canRetry) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () async {
                  final db = await ref.read(appDatabaseProvider.future);
                  final svc = TranscriptionService(db: db);
                  await svc.transcribeFromFile(
                      bullet.id, bullet.audioFilePath!);
                },
                child: const Text(
                  'Retry',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                      decoration: TextDecoration.underline),
                ),
              ),
            ],
          ],
        ),
        if (hasAudio) ...[
          const SizedBox(height: 8),
          AudioPlayerWidget(audioPath: bullet.audioFilePath!),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isEvent = type == 'event';
    final color = isEvent ? cs.tertiary : cs.secondary;
    final icon = isEvent ? Icons.radio_button_checked_rounded : Icons.circle;
    final label = isEvent ? 'Event' : 'Note';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _ContentSection extends StatelessWidget {
  final Bullet bullet;
  final bool editing;
  final TextEditingController controller;
  final VoidCallback onTap;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const _ContentSection({
    required this.bullet,
    required this.editing,
    required this.controller,
    required this.onTap,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (editing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            maxLines: null,
            style: const TextStyle(fontSize: 16, height: 1.5),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              hintText: 'Content',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton(onPressed: onSave, child: const Text('Save')),
              const SizedBox(width: 8),
              TextButton(onPressed: onCancel, child: const Text('Cancel')),
            ],
          ),
        ],
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          bullet.content,
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
      ),
    );
  }
}

class _TagsRow extends StatelessWidget {
  final String content;
  const _TagsRow({required this.content});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tags = RegExp(r'#(\w+)')
        .allMatches(content)
        .map((m) => m.group(1)!)
        .toSet()
        .toList();

    if (tags.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: tags
            .map(
              (tag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '#$tag',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: cs.primary,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _EventDateRow extends ConsumerWidget {
  final Bullet bullet;
  final ValueChanged<String> onSetDate;
  final VoidCallback onClearDate;

  const _EventDateRow({
    required this.bullet,
    required this.onSetDate,
    required this.onClearDate,
  });

  String _formatDate(String date) {
    try {
      return DateFormat('EEEE, MMM d, y').format(DateTime.parse(date));
    } catch (_) {
      return date;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final hasDate = bullet.scheduledDate != null;

    return Row(
      children: [
        Icon(
          Icons.calendar_today_outlined,
          size: 16,
          color: hasDate ? cs.tertiary : cs.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 8),
        hasDate
            ? Text(
                _formatDate(bullet.scheduledDate!),
                style: TextStyle(fontSize: 14, color: cs.onSurface),
              )
            : Text(
                'No date set',
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
        const Spacer(),
        GestureDetector(
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: bullet.scheduledDate != null
                  ? DateTime.tryParse(bullet.scheduledDate!) ?? now
                  : now,
              firstDate: now.subtract(const Duration(days: 365)),
              lastDate: now.add(const Duration(days: 365)),
            );
            if (picked == null) return;
            onSetDate(DateFormat('yyyy-MM-dd').format(picked));
          },
          child: Text(
            hasDate ? 'Change' : 'Set date',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: cs.primary,
            ),
          ),
        ),
        if (hasDate) ...[
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onClearDate,
            child: Icon(
              Icons.close_rounded,
              size: 16,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
      ],
    );
  }
}

class _CreatedAtRow extends StatelessWidget {
  final String createdAt;
  const _CreatedAtRow({required this.createdAt});

  String _format(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('MMM d, y · h:mm a').format(dt);
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.access_time_rounded, size: 14, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
        const SizedBox(width: 6),
        Text(
          'Created ${_format(createdAt)}',
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

class _ActionsSection extends StatelessWidget {
  final Bullet bullet;
  final VoidCallback onConvertToTask;

  const _ActionsSection({
    required this.bullet,
    required this.onConvertToTask,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: onConvertToTask,
      icon: Icon(Icons.check_box_outline_blank, size: 16, color: cs.primary),
      label: Text(
        'Convert to Task',
        style: TextStyle(color: cs.primary, fontSize: 13),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: cs.primary.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Follow-up date row
// ─────────────────────────────────────────────────────────────────────────────

class _FollowUpRow extends StatelessWidget {
  final Bullet bullet;
  final VoidCallback onSetFollowUp;

  const _FollowUpRow({required this.bullet, required this.onSetFollowUp});

  String _format(String iso) {
    try {
      return DateFormat('MMM d, y').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasFollowUp = bullet.followUpDate != null;
    final isDone = bullet.followUpStatus == 'done';
    final isDismissed = bullet.followUpStatus == 'dismissed';

    return Row(
      children: [
        Icon(
          Icons.alarm_outlined,
          size: 16,
          color: hasFollowUp && !isDone && !isDismissed
              ? cs.primary
              : cs.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 8),
        hasFollowUp
            ? Text(
                isDone
                    ? 'Followed up ${_format(bullet.followUpDate!)}'
                    : isDismissed
                        ? 'Dismissed'
                        : 'Follow up ${_format(bullet.followUpDate!)}',
                style: TextStyle(
                  fontSize: 14,
                  color: isDone || isDismissed
                      ? cs.onSurfaceVariant.withValues(alpha: 0.5)
                      : cs.onSurface,
                  decoration:
                      isDone ? TextDecoration.lineThrough : null,
                ),
              )
            : Text(
                'No follow-up',
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
        const Spacer(),
        if (!isDone && !isDismissed)
          GestureDetector(
            onTap: onSetFollowUp,
            child: Text(
              hasFollowUp ? 'Change' : 'Add follow-up',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: cs.primary,
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Linked persons section — shows all linked persons as tappable chips
// ─────────────────────────────────────────────────────────────────────────────

class _LinkedPersonSection extends ConsumerWidget {
  final String bulletId;
  const _LinkedPersonSection({required this.bulletId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personsAsync = ref.watch(linkedPeopleForBulletProvider(bulletId));
    final cs = Theme.of(context).colorScheme;

    return personsAsync.when(
      data: (persons) {
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Chips for all linked persons
            for (final person in persons)
              PersonChip(
                person: LinkedPerson(id: person.id, name: person.name),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PersonProfileScreen(person: person),
                  ),
                ),
              ),
            // "Link person" ghost chip
            GestureDetector(
              onTap: () => _addPersonLink(context, ref),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded,
                        size: 12, color: cs.onSurfaceVariant),
                    const SizedBox(width: 3),
                    Text(
                      'Link person',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Future<void> _addPersonLink(BuildContext context, WidgetRef ref) async {
    final picked = await showModalBottomSheet<PeopleData?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const PersonPickerSheet(),
    );
    if (picked != null && context.mounted) {
      final db = await ref.read(appDatabaseProvider.future);
      await PeopleDao(db).insertLink(bulletId, picked.id, linkType: 'manual');
      ref.invalidate(linkedPeopleForBulletProvider(bulletId));
    }
  }

}
