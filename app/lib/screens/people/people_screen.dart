import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/database/daos/people_dao.dart';
import 'package:antra/providers/people_provider.dart';
import 'package:antra/screens/people/create_person_sheet.dart';
import 'package:antra/screens/people/person_profile_screen.dart';
import 'package:antra/theme/app_theme.dart';
import 'package:antra/widgets/aurora_background.dart';
import 'package:antra/widgets/person_avatar.dart';
import 'package:antra/widgets/person_status_badge.dart';

class PeopleScreen extends ConsumerStatefulWidget {
  const PeopleScreen({super.key});

  @override
  ConsumerState<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends ConsumerState<PeopleScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    ref
        .read(peopleScreenNotifierProvider.notifier)
        .setSearchQuery(query.trim());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(peopleScreenNotifierProvider);
    final sortedAsync = ref.watch(peopleSortedProvider(
      state.sort,
      needsFollowUpOnly: state.needsFollowUpOnly,
    ));

    return Scaffold(
      backgroundColor: AntraColors.auroraDeepNavy,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('People', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort_rounded),
            onPressed: () => _showSortSheet(context, state),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'people_fab',
        onPressed: () => showModalBottomSheet<PeopleData?>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const CreatePersonSheet(),
        ),
        child: const Icon(Icons.person_add_outlined),
      ),
      body: AuroraBackground(
        variant: AuroraVariant.people,
        child: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by name or company…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: state.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          ref
                              .read(peopleScreenNotifierProvider.notifier)
                              .setSearchQuery('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              ),
            ),
          ),

          // Filter chip row
          _FilterChipRow(state: state),

          // People list
          Expanded(
            child: sortedAsync.when(
              data: (allPeople) {
                // Dart-side filtering: search, tag, relationship type
                final filtered = _applyFilters(allPeople, state);

                if (filtered.isEmpty) {
                  return _EmptyState(hasFilters: state.searchQuery.isNotEmpty ||
                      state.tag != null ||
                      state.relationshipType != null ||
                      state.needsFollowUpOnly);
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 4, bottom: 80),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final person = filtered[index];
                    return _PersonTile(
                      person: person,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PersonProfileScreen(person: person),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
        ),
      ),
    );
  }

  List<PeopleData> _applyFilters(
    List<PeopleData> people,
    PeopleScreenState state,
  ) {
    var result = people;

    if (state.searchQuery.isNotEmpty) {
      final q = state.searchQuery.toLowerCase();
      result = result
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              (p.company ?? '').toLowerCase().contains(q))
          .toList();
    }

    if (state.tag != null) {
      final tag = state.tag!.toLowerCase();
      result = result
          .where((p) =>
              (p.tags ?? '')
                  .split(',')
                  .map((t) => t.trim().toLowerCase())
                  .contains(tag))
          .toList();
    }

    if (state.relationshipType != null) {
      result = result
          .where((p) => p.relationshipType == state.relationshipType)
          .toList();
    }

    return result;
  }

  void _showSortSheet(BuildContext context, PeopleScreenState state) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Sort by',
                  style: Theme.of(ctx).textTheme.titleSmall),
            ),
            for (final sort in PeopleSort.values)
              ListTile(
                title: Text(_sortLabel(sort)),
                trailing: state.sort == sort
                    ? Icon(Icons.check,
                        color: Theme.of(ctx).colorScheme.primary)
                    : null,
                onTap: () {
                  ref
                      .read(peopleScreenNotifierProvider.notifier)
                      .setSort(sort);
                  Navigator.of(ctx).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  String _sortLabel(PeopleSort sort) {
    switch (sort) {
      case PeopleSort.lastInteraction:
        return 'Last interaction';
      case PeopleSort.nameAZ:
        return 'Name A–Z';
      case PeopleSort.recentlyCreated:
        return 'Recently added';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _FilterChipRow extends ConsumerWidget {
  final PeopleScreenState state;
  const _FilterChipRow({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(peopleScreenNotifierProvider.notifier);
    final activeCount = (state.needsFollowUpOnly ? 1 : 0) +
        (state.tag != null ? 1 : 0) +
        (state.relationshipType != null ? 1 : 0);

    if (activeCount == 0 && !state.needsFollowUpOnly) {
      // Show only the "Needs follow-up" toggle when no filters active
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        child: Row(
          children: [
            FilterChip(
              label: const Text('Needs follow-up'),
              selected: state.needsFollowUpOnly,
              onSelected: (v) => notifier.setNeedsFollowUpOnly(v),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: [
          FilterChip(
            label: const Text('Needs follow-up'),
            selected: state.needsFollowUpOnly,
            onSelected: (v) => notifier.setNeedsFollowUpOnly(v),
          ),
          if (state.tag != null) ...[
            const SizedBox(width: 6),
            Chip(
              label: Text('#${state.tag}'),
              deleteIcon: const Icon(Icons.close, size: 14),
              onDeleted: () => notifier.setTagFilter(null),
            ),
          ],
          if (state.relationshipType != null) ...[
            const SizedBox(width: 6),
            Chip(
              label: Text(state.relationshipType!),
              deleteIcon: const Icon(Icons.close, size: 14),
              onDeleted: () => notifier.setRelationshipTypeFilter(null),
            ),
          ],
          if (activeCount > 0) ...[
            const Spacer(),
            TextButton(
              onPressed: notifier.clearFilters,
              child: const Text('Clear'),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PersonTile extends StatelessWidget {
  final PeopleData person;
  final VoidCallback onTap;

  const _PersonTile({required this.person, required this.onTap});

  String _lastSeenLabel() {
    final ts = person.lastInteractionAt;
    if (ts == null) return 'No interactions yet';
    final dt = DateTime.tryParse(ts);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    return DateFormat('MMM d').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = [person.role, person.company]
        .whereType<String>()
        .join(' · ');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            PersonAvatar(
              personId: person.id,
              displayName: person.name,
              radius: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle.isNotEmpty ? subtitle : _lastSeenLabel(),
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      _lastSeenLabel(),
                      style: const TextStyle(fontSize: 11, color: Colors.white38),
                    ),
                  ],
                  // Status badge (stale / follow-up)
                  const SizedBox(height: 4),
                  PersonStatusBadge(person: person),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  const _EmptyState({required this.hasFilters});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasFilters
                  ? Icons.search_off_rounded
                  : Icons.people_outline_rounded,
              size: 36,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters ? 'No matches' : 'No people yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasFilters
                ? 'Try adjusting your search or filters'
                : 'Tap + to add someone',
            style: TextStyle(
                fontSize: 13,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}
