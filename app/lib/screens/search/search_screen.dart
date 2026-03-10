import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/database/daos/bullets_dao.dart';
import 'package:antra/providers/database_provider.dart';
import 'package:antra/providers/people_provider.dart';
import 'package:antra/providers/search_provider.dart';
import 'package:antra/screens/daily_log/daily_log_screen.dart';
import 'package:antra/widgets/bullet_list_item.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _queryController = TextEditingController();
  List<Bullet> _results = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(searchNotifierProvider.notifier).resultsStream.listen(
        (results) {
          if (mounted) setState(() => _results = results);
        },
      );
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    final fmt = DateFormat('yyyy-MM-dd');
    ref.read(searchNotifierProvider.notifier).setDateRange(
          fmt.format(picked.start),
          fmt.format(picked.end),
        );
  }

  Future<void> _navigateToBullet(Bullet bullet) async {
    final db = await ref.read(appDatabaseProvider.future);
    final dayLog = await BulletsDao(db).getDayLogById(bullet.dayId);
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DailyLogScreen(initialDate: dayLog?.date),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(searchNotifierProvider);
    final peopleAsync = ref.watch(allPeopleProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _queryController,
              onChanged: (v) =>
                  ref.read(searchNotifierProvider.notifier).setQuery(v),
              decoration: InputDecoration(
                hintText: 'Search bullets…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: filters.query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _queryController.clear();
                          ref
                              .read(searchNotifierProvider.notifier)
                              .setQuery('');
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _FilterChip(
                  label: filters.tagFilter != null
                      ? '#${filters.tagFilter}'
                      : 'Tag',
                  icon: Icons.tag,
                  active: filters.tagFilter != null,
                  onTap: () => _showTagDialog(context),
                  onDelete: filters.tagFilter != null
                      ? () => ref
                          .read(searchNotifierProvider.notifier)
                          .setTagFilter(null)
                      : null,
                ),
                const SizedBox(width: 8),
                peopleAsync.when(
                  data: (people) {
                    final active = filters.personFilter != null
                        ? people
                            .where((p) => p.id == filters.personFilter)
                            .firstOrNull
                        : null;
                    return _FilterChip(
                      label: active != null ? '@${active.name}' : 'Person',
                      icon: Icons.person_outline,
                      active: filters.personFilter != null,
                      onTap: () => _showPersonPicker(context, people),
                      onDelete: filters.personFilter != null
                          ? () => ref
                              .read(searchNotifierProvider.notifier)
                              .setPersonFilter(null)
                          : null,
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: filters.dateFrom != null
                      ? '${_short(filters.dateFrom!)} – ${_short(filters.dateTo!)}'
                      : 'Date range',
                  icon: Icons.date_range_outlined,
                  active: filters.dateFrom != null,
                  onTap: _pickDateRange,
                  onDelete: filters.dateFrom != null
                      ? () => ref
                          .read(searchNotifierProvider.notifier)
                          .setDateRange(null, null)
                      : null,
                ),
                if (!filters.isEmpty) ...[
                  const SizedBox(width: 8),
                  ActionChip(
                    label: const Text('Clear all'),
                    onPressed: () {
                      _queryController.clear();
                      ref
                          .read(searchNotifierProvider.notifier)
                          .clearFilters();
                    },
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildResults(filters)),
        ],
      ),
    );
  }

  Widget _buildResults(SearchFilters filters) {
    if (filters.isEmpty) {
      return const Center(
        child: Text(
          'Enter a search term or apply a filter.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    if (_results.isEmpty) {
      return const Center(
        child: Text(
          'No results found.\nTry different keywords or filters.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final bullet = _results[index];
        return InkWell(
          onTap: () => _navigateToBullet(bullet),
          child: BulletListItem(bullet: bullet),
        );
      },
    );
  }

  Future<void> _showTagDialog(BuildContext context) async {
    final ctrl = TextEditingController(
      text: ref.read(searchNotifierProvider).tagFilter ?? '',
    );
    final tag = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Filter by tag'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'tag name (no #)'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim().toLowerCase()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, ctrl.text.trim().toLowerCase()),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (tag != null && tag.isNotEmpty) {
      ref.read(searchNotifierProvider.notifier).setTagFilter(tag);
    }
  }

  Future<void> _showPersonPicker(
    BuildContext context,
    List<PeopleData> people,
  ) async {
    final picked = await showDialog<PeopleData>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Filter by person'),
        children: people
            .map(
              (p) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, p),
                child: Text(p.name),
              ),
            )
            .toList(),
      ),
    );
    if (picked != null) {
      ref.read(searchNotifierProvider.notifier).setPersonFilter(picked.id);
    }
  }

  String _short(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return DateFormat('MMM d').format(dt);
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilterChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      selected: active,
      selectedColor: scheme.primaryContainer,
      onSelected: (_) => onTap(),
      onDeleted: onDelete,
      showCheckmark: false,
    );
  }
}
