import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/database/daos/bullets_dao.dart';
import 'package:antra/providers/database_provider.dart';
import 'package:antra/providers/people_provider.dart';
import 'package:antra/providers/search_provider.dart';
import 'package:antra/screens/daily_log/daily_log_screen.dart';
import 'package:antra/theme/app_theme.dart';
import 'package:antra/widgets/aurora_background.dart';
import 'package:antra/widgets/bullet_list_item.dart';
import 'package:antra/widgets/glass_surface.dart';

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
      backgroundColor: AntraColors.auroraDeepNavy,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Search',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: AuroraBackground(
        variant: AuroraVariant.search,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: GlassSurface(
                style: GlassStyle.chip,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.white54, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _queryController,
                        onChanged: (v) =>
                            ref.read(searchNotifierProvider.notifier).setQuery(v),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search bullets…',
                          hintStyle: const TextStyle(color: Colors.white38),
                          border: InputBorder.none,
                          isDense: true,
                          suffixIcon: filters.query.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear,
                                      color: Colors.white54, size: 18),
                                  onPressed: () {
                                    _queryController.clear();
                                    ref
                                        .read(searchNotifierProvider.notifier)
                                        .setQuery('');
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
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
                    _GlassClearChip(
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
            Expanded(child: _buildResults(filters)),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(SearchFilters filters) {
    if (filters.isEmpty) {
      return const Center(
        child: Text(
          'Enter a search term or apply a filter.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38),
        ),
      );
    }
    if (_results.isEmpty) {
      return const Center(
        child: Text(
          'No results found.\nTry different keywords or filters.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final bullet = _results[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassSurface(
            style: GlassStyle.card,
            padding: EdgeInsets.zero,
            onTap: () => _navigateToBullet(bullet),
            child: BulletListItem(bullet: bullet),
          ),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? Colors.white.withValues(alpha: 0.20)
              : Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AntraRadius.chip),
          border: Border.all(
            color: Colors.white.withValues(alpha: active ? 0.30 : 0.15),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white70),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
            if (onDelete != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onDelete,
                child: const Icon(Icons.close, size: 14, color: Colors.white54),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GlassClearChip extends StatelessWidget {
  final VoidCallback onPressed;
  const _GlassClearChip({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AntraRadius.chip),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
        child: const Text(
          'Clear all',
          style: TextStyle(fontSize: 13, color: Colors.white54),
        ),
      ),
    );
  }
}
