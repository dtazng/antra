import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/models/timeline_item.dart';
import 'package:antra/providers/people_provider.dart';
import 'package:antra/screens/daily_log/bullet_detail_screen.dart';
import 'package:antra/screens/daily_log/task_detail_screen.dart';

/// Full paginated activity timeline for a person.
///
/// Loaded on demand from "View All Activity" in [PersonProfileScreen].
/// Grouped by month-year, supports type filter chips, auto-loads next page
/// when user scrolls within 300px of the bottom.
class PersonFullTimelineScreen extends ConsumerStatefulWidget {
  final PeopleData person;
  const PersonFullTimelineScreen({super.key, required this.person});

  @override
  ConsumerState<PersonFullTimelineScreen> createState() =>
      _PersonFullTimelineScreenState();
}

class _PersonFullTimelineScreenState
    extends ConsumerState<PersonFullTimelineScreen> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      unawaited(
          ref.read(personTimelineProvider(widget.person.id).notifier).loadNextPage());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(personTimelineProvider(widget.person.id));

    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.person.name}'s Activity"),
      ),
      body: state.when(
        data: (timeline) => _TimelineBody(
          person: widget.person,
          timeline: timeline,
          scrollController: _scrollController,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _TimelineBody extends ConsumerWidget {
  final PeopleData person;
  final PersonTimelineState timeline;
  final ScrollController scrollController;

  const _TimelineBody({
    required this.person,
    required this.timeline,
    required this.scrollController,
  });

  static const _filterTypes = ['all', 'note', 'task', 'event'];
  static const _filterLabels = {
    'all': 'All',
    'note': 'Notes',
    'task': 'Tasks',
    'event': 'Events',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final selectedFilter = timeline.typeFilter ?? 'all';
    final notifier = ref.read(personTimelineProvider(person.id).notifier);

    return CustomScrollView(
      controller: scrollController,
      slivers: [
        // Sticky filter chip bar (T025)
        SliverPersistentHeader(
          pinned: true,
          delegate: _FilterBarDelegate(
            child: Container(
              color: cs.surface,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: _filterTypes.map((type) {
                  final selected = selectedFilter == type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: selected,
                      label: Text(_filterLabels[type]!,
                          style: const TextStyle(fontSize: 12)),
                      onSelected: (_) => unawaited(notifier.setTypeFilter(
                        type == 'all' ? null : type,
                      )),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),

        // Timeline items (T026)
        if (timeline.items.isEmpty && !timeline.isLoadingMore)
          SliverFillRemaining(
            child: _EmptyState(
              hasFilter: timeline.typeFilter != null,
              filterLabel:
                  timeline.typeFilter != null
                      ? _filterLabels[timeline.typeFilter!] ?? timeline.typeFilter!
                      : null,
              onClearFilter: () => unawaited(notifier.setTypeFilter(null)),
            ),
          )
        else ...[
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = timeline.items[index];
                if (item is TimelineMonthHeader) {
                  return Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 20, 16, 6),
                    child: Text(
                      item.label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  );
                } else if (item is TimelineActivityRow) {
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    child: _TimelineActivityTile(bullet: item.bullet),
                  );
                }
                return const SizedBox.shrink();
              },
              childCount: timeline.items.length,
            ),
          ),

          // Load-more indicator / end-of-list footer (T027)
          SliverToBoxAdapter(
            child: _TimelineFooter(timeline: timeline),
          ),
        ],

        // Loading spinner while first page is being fetched
        if (timeline.items.isEmpty && timeline.isLoadingMore)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sticky filter bar delegate
// ─────────────────────────────────────────────────────────────────────────────

class _FilterBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  const _FilterBarDelegate({required this.child});

  @override
  double get minExtent => 52;
  @override
  double get maxExtent => 52;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(_FilterBarDelegate old) => old.child != child;
}

// ─────────────────────────────────────────────────────────────────────────────
// Timeline activity tile (T026)
// ─────────────────────────────────────────────────────────────────────────────

class _TimelineActivityTile extends StatelessWidget {
  final Bullet bullet;
  const _TimelineActivityTile({required this.bullet});

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
      onTap: () => _openDetail(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ),
            if (dateLabel != null) ...[
              const SizedBox(width: 8),
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

  void _openDetail(BuildContext context) {
    if (bullet.type == 'task') {
      unawaited(Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => TaskDetailScreen(bulletId: bullet.id))));
    } else {
      unawaited(Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => BulletDetailScreen(bulletId: bullet.id))));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Footer: load-more spinner or end-of-list message (T027)
// ─────────────────────────────────────────────────────────────────────────────

class _TimelineFooter extends StatelessWidget {
  final PersonTimelineState timeline;
  const _TimelineFooter({required this.timeline});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (timeline.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!timeline.hasMore && timeline.items.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'All interactions loaded',
            style: TextStyle(
                fontSize: 13,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
          ),
        ),
      );
    }
    return const SizedBox(height: 24);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state (T027)
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasFilter;
  final String? filterLabel;
  final VoidCallback onClearFilter;

  const _EmptyState({
    required this.hasFilter,
    required this.filterLabel,
    required this.onClearFilter,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasFilter
                ? Icons.filter_list_off
                : Icons.history_toggle_off_outlined,
            size: 40,
            color: cs.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            hasFilter
                ? 'No ${filterLabel?.toLowerCase() ?? ''} logged yet'
                : 'No interactions yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: cs.onSurface.withValues(alpha: 0.7),
            ),
          ),
          if (hasFilter) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onClearFilter,
              child: const Text('Clear filter'),
            ),
          ],
        ],
      ),
    );
  }
}
