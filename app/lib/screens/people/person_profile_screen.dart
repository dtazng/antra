import 'dart:async' show unawaited;

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
import 'package:antra/screens/people/person_full_timeline_screen.dart';
import 'package:antra/widgets/log_interaction_sheet.dart';

class PersonProfileScreen extends ConsumerWidget {
  final PeopleData person;
  const PersonProfileScreen({super.key, required this.person});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personAsync = ref.watch(singlePersonProvider(person.id));

    return Scaffold(
      appBar: AppBar(
        title: personAsync.maybeWhen(
          data: (p) => Text(p?.name ?? person.name),
          orElse: () => Text(person.name),
        ),
      ),
      body: personAsync.when(
        data: (current) {
          if (current == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) Navigator.of(context).pop();
            });
            return const Center(child: CircularProgressIndicator());
          }
          return _ProfileBody(person: current);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ProfileBody extends ConsumerStatefulWidget {
  final PeopleData person;
  const _ProfileBody({required this.person});

  @override
  ConsumerState<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends ConsumerState<_ProfileBody> {
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
        // 1. Identity header
        SliverToBoxAdapter(child: _HeaderSection(person: p)),
        // 2. Quick actions
        SliverToBoxAdapter(child: _QuickActionsBar(person: p)),
        // 3. Relationship summary stats
        SliverToBoxAdapter(child: _RelationshipSummaryCard(person: p)),
        // 4. Recent activity preview
        SliverToBoxAdapter(child: _RecentActivitySection(person: p)),
        // 5. Pinned notes
        SliverToBoxAdapter(child: _PinnedNotesSection(person: p)),
        // 6. Relationship insights
        SliverToBoxAdapter(child: _InsightsSection(person: p)),
        // 7. Delete
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Section 1: Identity header (T018)
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderSection extends StatelessWidget {
  final PeopleData person;
  const _HeaderSection({required this.person});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = person;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: cs.primaryContainer,
                child: Text(
                  p.name[0].toUpperCase(),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        style: Theme.of(context).textTheme.titleLarge),
                    if (p.role != null || p.company != null)
                      Text(
                        [p.role, p.company].whereType<String>().join(' · '),
                        style: TextStyle(
                            fontSize: 13, color: cs.onSurfaceVariant),
                      ),
                    const SizedBox(height: 4),
                    _LastInteractionLabel(person: p),
                  ],
                ),
              ),
            ],
          ),
          if (p.email != null || p.phone != null || p.location != null) ...[
            const SizedBox(height: 10),
            _ContactRow(person: p),
          ],
          if (p.relationshipType != null || p.tags != null) ...[
            const SizedBox(height: 8),
            _MetaChipsRow(person: p),
          ],
          if (p.notes?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              p.notes!,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section 2: Quick actions bar (T022 — wired here, full sheet wired in T022)
// ─────────────────────────────────────────────────────────────────────────────

class _QuickActionsBar extends ConsumerWidget {
  final PeopleData person;
  const _QuickActionsBar({required this.person});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    Widget actionButton(
            IconData icon, String label, VoidCallback onTap) =>
        Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 22, color: cs.primary),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            actionButton(Icons.add_circle_outline, 'Log', () {
              unawaited(showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => LogInteractionSheet(
                  personId: person.id,
                  personName: person.name,
                ),
              ));
            }),
            actionButton(Icons.sticky_note_2_outlined, 'Note', () {
              unawaited(showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => LogInteractionSheet(
                  personId: person.id,
                  personName: person.name,
                  initialType: 'note',
                ),
              ));
            }),
            actionButton(Icons.flag_outlined, 'Follow-up', () {
              unawaited(showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => SafeArea(
                  child: _FollowUpSection(person: person),
                ),
              ));
            }),
            actionButton(Icons.edit_outlined, 'Edit', () {
              unawaited(showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => EditPersonSheet(person: person),
              ));
            }),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section 3: Relationship summary card (T019)
// ─────────────────────────────────────────────────────────────────────────────

class _RelationshipSummaryCard extends ConsumerWidget {
  final PeopleData person;
  const _RelationshipSummaryCard({required this.person});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final summaryAsync = ref.watch(interactionSummaryProvider(person.id));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12),
        child: summaryAsync.when(
          data: (summary) {
            if (summary.total == 0) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'No interactions yet',
                    style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: 0.5)),
                  ),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _StatChip(
                        label: '${summary.total}',
                        sublabel: 'total',
                        cs: cs),
                    const SizedBox(width: 8),
                    _StatChip(
                        label: '${summary.last30Days}',
                        sublabel: '30d',
                        cs: cs),
                    const SizedBox(width: 8),
                    _StatChip(
                        label: '${summary.last90Days}',
                        sublabel: '90d',
                        cs: cs),
                  ],
                ),
                if (summary.byType.values.where((v) => v > 0).length >= 2) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: summary.byType.entries
                        .where((e) => e.value > 0)
                        .map(
                          (e) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: cs.surface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${e.key}: ${e.value}',
                              style: TextStyle(
                                  fontSize: 11, color: cs.onSurfaceVariant),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            );
          },
          loading: () => const Center(
            child: SizedBox(
              height: 32,
              width: 32,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String sublabel;
  final ColorScheme cs;
  const _StatChip(
      {required this.label, required this.sublabel, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: cs.onSurface),
          ),
          Text(
            sublabel,
            style:
                TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section 4: Recent activity (T020)
// ─────────────────────────────────────────────────────────────────────────────

class _RecentActivitySection extends ConsumerStatefulWidget {
  final PeopleData person;
  const _RecentActivitySection({required this.person});

  @override
  ConsumerState<_RecentActivitySection> createState() =>
      _RecentActivitySectionState();
}

class _RecentActivitySectionState
    extends ConsumerState<_RecentActivitySection> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = widget.person;
    final bulletsAsync = ref.watch(recentBulletsForPersonProvider(p.id));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Recent Activity',
                  style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              TextButton(
                onPressed: () {
                  unawaited(Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          PersonFullTimelineScreen(person: widget.person),
                    ),
                  ));
                },
                style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: Text('View All →',
                    style: TextStyle(fontSize: 12, color: cs.primary)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          bulletsAsync.when(
            data: (bullets) {
              if (bullets.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.link_off_outlined,
                          size: 16,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                      const SizedBox(width: 6),
                      Text(
                        'No interactions linked yet',
                        style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                      ),
                    ],
                  ),
                );
              }
              final visibleCount = _showAll
                  ? bullets.length
                  : bullets.length.clamp(0, 5);
              final visible = bullets.take(visibleCount).toList();
              return Column(
                children: [
                  ...visible.map((b) => _ActivityRow(
                        bullet: b,
                        onTap: () => _openBulletDetail(context, b),
                      )),
                  if (!_showAll && bullets.length > 5)
                    TextButton(
                      onPressed: () => setState(() => _showAll = true),
                      child: Text(
                        'Show ${bullets.length - 5} more',
                        style: const TextStyle(fontSize: 12),
                      ),
                    )
                  else if (_showAll && bullets.length > 5)
                    TextButton(
                      onPressed: () => setState(() => _showAll = false),
                      child: const Text('Show less',
                          style: TextStyle(fontSize: 12)),
                    ),
                ],
              );
            },
            loading: () => const Center(
                child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: CircularProgressIndicator(),
            )),
            error: (e, _) =>
                Text('Error: $e', style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _openBulletDetail(BuildContext context, Bullet bullet) {
    if (bullet.type == 'task') {
      unawaited(Navigator.of(context).push(
        MaterialPageRoute<void>(
            builder: (_) => TaskDetailScreen(bulletId: bullet.id)),
      ));
    } else {
      unawaited(Navigator.of(context).push(
        MaterialPageRoute<void>(
            builder: (_) => BulletDetailScreen(bulletId: bullet.id)),
      ));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section 5: Pinned notes (T029 placeholder — implemented in T029)
// ─────────────────────────────────────────────────────────────────────────────

class _PinnedNotesSection extends ConsumerWidget {
  final PeopleData person;
  const _PinnedNotesSection({required this.person});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bulletsAsync = ref.watch(pinnedBulletsForPersonProvider(person.id));
    return bulletsAsync.when(
      data: (bullets) {
        if (bullets.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Pinned',
                      style: Theme.of(context).textTheme.titleSmall),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.push_pin_outlined, size: 18),
                    onPressed: () {
                      unawaited(showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => LogInteractionSheet(
                          personId: person.id,
                          personName: person.name,
                          initialType: 'note',
                          pinOnSave: true,
                        ),
                      ));
                    },
                    tooltip: 'Pin a new note',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              ...bullets.map((b) => _PinnedNoteCard(
                    bullet: b,
                    person: person,
                  )),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _PinnedNoteCard extends ConsumerStatefulWidget {
  final Bullet bullet;
  final PeopleData person;
  const _PinnedNoteCard({required this.bullet, required this.person});

  @override
  ConsumerState<_PinnedNoteCard> createState() => _PinnedNoteCardState();
}

class _PinnedNoteCardState extends ConsumerState<_PinnedNoteCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onLongPress: _showOptions,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.bullet.content,
              maxLines: _expanded ? null : 3,
              overflow:
                  _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _expanded ? 'Show less' : 'Show more',
                style: TextStyle(fontSize: 12, color: cs.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.push_pin_outlined),
              title: const Text('Unpin'),
              onTap: () async {
                Navigator.pop(ctx);
                final db = await ref.read(appDatabaseProvider.future);
                await PeopleDao(db).setPinned(
                  widget.bullet.id,
                  widget.person.id,
                  pinned: false,
                );
                ref.invalidate(
                    pinnedBulletsForPersonProvider(widget.person.id));
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new_outlined),
              title: const Text('Open entry'),
              onTap: () {
                Navigator.pop(ctx);
                unawaited(Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) =>
                      BulletDetailScreen(bulletId: widget.bullet.id),
                )));
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section 6: Relationship insights (T031 placeholder — implemented in T031)
// ─────────────────────────────────────────────────────────────────────────────

class _InsightsSection extends StatelessWidget {
  final PeopleData person;
  const _InsightsSection({required this.person});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = person;
    final now = DateTime.now();

    // Compute days since last interaction
    int? daysSinceLast;
    if (p.lastInteractionAt != null) {
      final last = DateTime.tryParse(p.lastInteractionAt!)?.toLocal();
      if (last != null) {
        daysSinceLast = now.difference(last).inDays;
      }
    }

    // Parse optional follow-up date
    DateTime? followUpDt;
    if (p.followUpDate != null) {
      followUpDt = DateTime.tryParse(p.followUpDate!);
    }

    // Priority order: overdue → upcoming → needs (no date) → stale
    Color? bg;
    IconData? icon;
    String? message;

    if (p.needsFollowUp == 1 && followUpDt != null && followUpDt.isBefore(now)) {
      bg = cs.errorContainer;
      icon = Icons.flag;
      message = 'Follow-up overdue — due ${p.followUpDate}';
    } else if (p.needsFollowUp == 1 && followUpDt != null && followUpDt.isAfter(now)) {
      final days = followUpDt.difference(now).inDays;
      bg = cs.tertiaryContainer;
      icon = Icons.flag_outlined;
      message = 'Follow up due in $days day${days == 1 ? '' : 's'}';
    } else if (p.needsFollowUp == 1) {
      bg = cs.tertiaryContainer;
      icon = Icons.flag_outlined;
      message = 'Marked as needs follow-up';
    } else if (p.reminderCadenceDays != null &&
        daysSinceLast != null &&
        daysSinceLast > p.reminderCadenceDays!) {
      bg = cs.surfaceContainerHighest;
      icon = Icons.schedule_outlined;
      message = 'Last contact $daysSinceLast days ago — consider reaching out';
    }

    if (message == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared activity row widget (used in T020 and reused in T026)
// ─────────────────────────────────────────────────────────────────────────────

class _ActivityRow extends StatelessWidget {
  final Bullet bullet;
  final VoidCallback onTap;
  const _ActivityRow({required this.bullet, required this.onTap});

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
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                bullet.content,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            if (bullet.type == 'task') ...[
              const SizedBox(width: 6),
              _TaskStatusChip(status: bullet.status),
            ],
            if (dateLabel != null) ...[
              const SizedBox(width: 6),
              Text(
                dateLabel,
                style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
              ),
            ],
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                size: 16,
                color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Follow-up section (used inline and in QuickActionsBar sheet)
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
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Utility sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

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
    return Text(label,
        style: TextStyle(fontSize: 12, color: cs.secondary));
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
            border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: cs.onSurfaceVariant),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      fontSize: 12, color: cs.onSurfaceVariant)),
            ],
          ),
        );

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        if (person.email != null) chip(Icons.email_outlined, person.email!),
        if (person.phone != null) chip(Icons.phone_outlined, person.phone!),
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
      for (final tag in person.tags!
          .split(',')
          .where((t) => t.trim().isNotEmpty)) {
        chips.add(Chip(
          label: Text(tag.trim(), style: const TextStyle(fontSize: 12)),
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
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color),
      ),
    );
  }
}
