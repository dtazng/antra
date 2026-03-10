import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/database/daos/people_dao.dart';
import 'package:antra/providers/database_provider.dart';
import 'package:antra/providers/people_provider.dart';
import 'package:antra/screens/daily_log/bullet_detail_screen.dart';
import 'package:antra/screens/daily_log/task_detail_screen.dart';
import 'package:antra/screens/people/edit_person_sheet.dart';

class PersonProfileScreen extends ConsumerWidget {
  final PeopleData person;

  const PersonProfileScreen({super.key, required this.person});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Reactive: stays current as the person is edited elsewhere.
    final personAsync = ref.watch(singlePersonProvider(person.id));
    final bulletsAsync = ref.watch(bulletsForPersonProvider(person.id));

    return Scaffold(
      appBar: AppBar(
        title: personAsync.maybeWhen(
          data: (p) => Text(p?.name ?? person.name),
          orElse: () => Text(person.name),
        ),
        actions: [
          personAsync.maybeWhen(
            data: (p) => p != null
                ? IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _openEditSheet(context, ref, p),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: personAsync.when(
        data: (current) {
          // Person was deleted — pop back.
          if (current == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) Navigator.of(context).pop();
            });
            return const Center(child: CircularProgressIndicator());
          }
          return _ProfileBody(
            person: current,
            bulletsAsync: bulletsAsync,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _openEditSheet(BuildContext context, WidgetRef ref, PeopleData p) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => EditPersonSheet(person: p),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ProfileBody extends ConsumerStatefulWidget {
  final PeopleData person;
  final AsyncValue<List<Bullet>> bulletsAsync;

  const _ProfileBody({required this.person, required this.bulletsAsync});

  @override
  ConsumerState<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends ConsumerState<_ProfileBody> {
  bool _editingNotes = false;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _notesController =
        TextEditingController(text: widget.person.notes ?? '');
  }

  @override
  void didUpdateWidget(_ProfileBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.person.notes != widget.person.notes && !_editingNotes) {
      _notesController.text = widget.person.notes ?? '';
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveNotes() async {
    final db = await ref.read(appDatabaseProvider.future);
    final text = _notesController.text.trim();
    await PeopleDao(db).updatePerson(
      PeopleCompanion(
        id: Value(widget.person.id),
        notes: Value(text.isEmpty ? null : text),
      ),
    );
    if (mounted) setState(() => _editingNotes = false);
  }

  Future<void> _deletePerson() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Delete ${widget.person.name}?',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'All linked log entries will be unlinked. This cannot be undone.',
                style: TextStyle(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(ctx).colorScheme.error),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    final db = await ref.read(appDatabaseProvider.future);
    await PeopleDao(db).softDeletePerson(widget.person.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = widget.person;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar + name header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: cs.primaryContainer,
                      child: Text(
                        p.name[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name,
                              style: Theme.of(context).textTheme.titleLarge),
                          if (p.company != null || p.role != null)
                            Text(
                              [p.role, p.company]
                                  .whereType<String>()
                                  .join(' · '),
                              style: TextStyle(
                                  fontSize: 13, color: cs.onSurfaceVariant),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Last interaction
                _LastInteractionLabel(person: p),
                const SizedBox(height: 16),

                // Contact info chips
                if (p.email != null || p.phone != null || p.location != null) ...[
                  _ContactRow(person: p),
                  const SizedBox(height: 10),
                ],

                // Relationship type + tags
                if (p.relationshipType != null || p.tags != null) ...[
                  _MetaChipsRow(person: p),
                  const SizedBox(height: 16),
                ],

                // Context notes
                Row(
                  children: [
                    Text('Notes',
                        style: Theme.of(context).textTheme.titleSmall),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                          _editingNotes ? Icons.check : Icons.edit_outlined),
                      iconSize: 18,
                      onPressed: _editingNotes
                          ? _saveNotes
                          : () {
                              _notesController.text = p.notes ?? '';
                              setState(() => _editingNotes = true);
                            },
                    ),
                  ],
                ),
                if (_editingNotes)
                  TextField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      hintText: 'Add context about this person…',
                    ),
                    minLines: 2,
                    maxLines: 6,
                    autofocus: true,
                  )
                else
                  Text(
                    p.notes?.isNotEmpty == true
                        ? p.notes!
                        : 'No notes yet.',
                    style: TextStyle(
                      color: p.notes?.isNotEmpty == true
                          ? null
                          : cs.onSurface.withValues(alpha: 0.4),
                    ),
                  ),

                const SizedBox(height: 16),

                // Follow-up section
                _FollowUpSection(person: p),

                const Divider(height: 1),
                const SizedBox(height: 12),
                Text('Interactions',
                    style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
          ),
        ),

        // Interaction timeline
        widget.bulletsAsync.when(
          data: (bullets) {
            if (bullets.isEmpty) {
              return const SliverToBoxAdapter(child: _EmptyTimeline());
            }
            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _TimelineRow(
                  bullet: bullets[index],
                  onTap: () => _openBulletDetail(context, bullets[index]),
                ),
                childCount: bullets.length,
              ),
            );
          },
          loading: () => const SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) =>
              SliverToBoxAdapter(child: Center(child: Text('Error: $e'))),
        ),

        // Delete person button
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.error,
                side: BorderSide(color: cs.error.withValues(alpha: 0.4)),
              ),
              onPressed: _deletePerson,
              child: Text('Delete ${p.name}'),
            ),
          ),
        ),
      ],
    );
  }

  void _openBulletDetail(BuildContext context, Bullet bullet) {
    if (bullet.type == 'task') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
            builder: (_) => TaskDetailScreen(bulletId: bullet.id)),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
            builder: (_) => BulletDetailScreen(bulletId: bullet.id)),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _FollowUpSection extends ConsumerWidget {
  final PeopleData person;
  const _FollowUpSection({required this.person});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final needsFollowUp = person.needsFollowUp == 1;

    Future<void> setFollowUp({
      required bool needs,
      String? followUpDate,
    }) async {
      final db = await ref.read(appDatabaseProvider.future);
      await PeopleDao(db).setFollowUp(
        person.id,
        needs: needs,
        followUpDate: followUpDate,
      );
    }

    Future<void> pickDate() async {
      final initial = person.followUpDate != null
          ? DateTime.tryParse(person.followUpDate!) ?? DateTime.now()
          : DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
        helpText: 'Set follow-up date',
      );
      if (picked == null) return;
      final dateStr =
          '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
      await setFollowUp(needs: true, followUpDate: dateStr);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Follow-up',
                  style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              if (needsFollowUp)
                TextButton(
                  onPressed: () => setFollowUp(needs: false),
                  child: Text('Clear',
                      style: TextStyle(color: cs.onSurfaceVariant)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (!needsFollowUp)
            OutlinedButton.icon(
              onPressed: () => setFollowUp(needs: true),
              icon: const Icon(Icons.flag_outlined, size: 16),
              label: const Text('Mark as needs follow-up'),
            )
          else
            Row(
              children: [
                Chip(
                  avatar: Icon(Icons.flag,
                      size: 14, color: cs.onSecondaryContainer),
                  label: Text(
                    person.followUpDate != null
                        ? 'Due ${person.followUpDate}'
                        : 'Needs follow-up',
                    style: TextStyle(
                        fontSize: 12, color: cs.onSecondaryContainer),
                  ),
                  backgroundColor: cs.secondaryContainer,
                  side: BorderSide.none,
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: pickDate,
                  icon: const Icon(Icons.calendar_today_outlined, size: 14),
                  label: Text(
                      person.followUpDate != null ? 'Change date' : 'Set date',
                      style: const TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _LastInteractionLabel extends StatelessWidget {
  final PeopleData person;
  const _LastInteractionLabel({required this.person});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = person.lastInteractionAt;
    final label = ts == null
        ? 'No interactions recorded'
        : () {
            final dt = DateTime.tryParse(ts)?.toLocal();
            return dt == null
                ? 'Unknown'
                : 'Last interaction: ${DateFormat('MMM d, y').format(dt)}';
          }();
    return Text(label, style: TextStyle(fontSize: 13, color: cs.secondary));
  }
}

class _ContactRow extends StatelessWidget {
  final PeopleData person;
  const _ContactRow({required this.person});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget chip(IconData icon, String label) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: cs.onSurfaceVariant),
              const SizedBox(width: 5),
              Text(label,
                  style:
                      TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ],
          ),
        );

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        if (person.email != null)
          chip(Icons.email_outlined, person.email!),
        if (person.phone != null)
          chip(Icons.phone_outlined, person.phone!),
        if (person.location != null)
          chip(Icons.location_on_outlined, person.location!),
      ],
    );
  }
}

class _MetaChipsRow extends StatelessWidget {
  final PeopleData person;
  const _MetaChipsRow({required this.person});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final chips = <Widget>[];

    if (person.relationshipType != null) {
      chips.add(Chip(
        label: Text(person.relationshipType!,
            style: const TextStyle(fontSize: 12)),
        backgroundColor: cs.secondaryContainer,
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ));
    }
    if (person.tags != null) {
      for (final tag
          in person.tags!.split(',').where((t) => t.trim().isNotEmpty)) {
        chips.add(Chip(
          label:
              Text(tag.trim(), style: const TextStyle(fontSize: 12)),
          backgroundColor:
              cs.surfaceContainerHighest.withValues(alpha: 0.6),
          side: BorderSide.none,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ));
      }
    }
    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }
}

class _TimelineRow extends StatelessWidget {
  final Bullet bullet;
  final VoidCallback onTap;
  const _TimelineRow({required this.bullet, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (icon, color) = switch (bullet.type) {
      'task' => (Icons.check_box_outline_blank, cs.primary),
      'event' => (Icons.radio_button_unchecked, cs.tertiary),
      _ => (Icons.circle_outlined, cs.secondary),
    };

    final ts = DateTime.tryParse(bullet.createdAt)?.toLocal();
    final dateLabel = ts != null ? DateFormat('MMM d').format(ts) : null;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bullet.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                  if (dateLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      dateLabel,
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
                    ),
                  ],
                ],
              ),
            ),
            if (bullet.type == 'task') ...[
              const SizedBox(width: 6),
              _TaskStatusChip(status: bullet.status),
            ],
            Icon(Icons.chevron_right_rounded,
                size: 16,
                color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }
}

class _TaskStatusChip extends StatelessWidget {
  final String status;
  const _TaskStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (label, color) = switch (status) {
      'complete' => ('Done', cs.primary),
      'cancelled' => ('Canceled', cs.error),
      'backlog' => ('Backlog', cs.tertiary),
      _ => ('Open', cs.secondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _EmptyTimeline extends StatelessWidget {
  const _EmptyTimeline();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.link_off_outlined,
              size: 36,
              color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(
            'No interactions yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: cs.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Link a log entry to see it here',
            style: TextStyle(
                fontSize: 13,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}

