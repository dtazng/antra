import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/providers/people_provider.dart';
import 'package:antra/screens/people/create_person_sheet.dart';
import 'package:antra/widgets/glass_surface.dart';
import 'package:antra/widgets/person_avatar.dart';

/// A multi-select bottom sheet for picking one or more people.
///
/// Returns a [List<PeopleData>] via [Navigator.pop]:
/// - Tapping "Done" pops with the current selection.
/// - Swiping down or tapping outside pops with [alreadyLinked] unchanged.
class PersonPickerSheet extends ConsumerStatefulWidget {
  const PersonPickerSheet({
    super.key,
    this.alreadyLinked = const [],
  });

  /// People already linked — shown pre-checked when the sheet opens.
  final List<PeopleData> alreadyLinked;

  @override
  ConsumerState<PersonPickerSheet> createState() => _PersonPickerSheetState();
}

class _PersonPickerSheetState extends ConsumerState<PersonPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';
  late List<PeopleData> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.of(widget.alreadyLinked);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _togglePerson(PeopleData person) {
    setState(() {
      if (_selected.any((p) => p.id == person.id)) {
        _selected.removeWhere((p) => p.id == person.id);
      } else {
        _selected.add(person);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final allAsync = ref.watch(allPeopleProvider);

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        // Drag-dismiss: caller receives original alreadyLinked unchanged
        // because we only pop _selected when Done is tapped explicitly.
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return GlassSurface(
              style: GlassStyle.modal,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  // Handle + Done row
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () =>
                                Navigator.of(context).pop(_selected),
                            child: const Text(
                              'Done',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Icon(Icons.search,
                                size: 20, color: Colors.white54),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              autofocus: true,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: 'Search people…',
                                hintStyle: TextStyle(color: Colors.white38),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 12),
                              ),
                              onChanged: (v) =>
                                  setState(() => _query = v.trim()),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: allAsync.when(
                      data: (people) {
                        final filtered = _query.isEmpty
                            ? people
                            : people
                                .where((p) =>
                                    p.name
                                        .toLowerCase()
                                        .contains(_query.toLowerCase()) ||
                                    (p.company ?? '')
                                        .toLowerCase()
                                        .contains(_query.toLowerCase()))
                                .toList();

                        return ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.only(bottom: 16),
                          children: [
                            ...filtered.map((person) {
                              final isSelected =
                                  _selected.any((p) => p.id == person.id);
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16),
                                leading: PersonAvatar(
                                  personId: person.id,
                                  displayName: person.name,
                                  radius: 18,
                                ),
                                title: Text(
                                  person.name,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: person.company != null
                                    ? Text(
                                        person.company!,
                                        style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12),
                                      )
                                    : null,
                                trailing: isSelected
                                    ? const Icon(Icons.check_rounded,
                                        color: Colors.white70)
                                    : null,
                                onTap: () => _togglePerson(person),
                              );
                            }),
                            // "Create new person" row — adds to selection, sheet stays open
                            ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.12),
                                ),
                                child: const Icon(Icons.person_add_outlined,
                                    size: 18, color: Colors.white54),
                              ),
                              title: const Text(
                                'Create new person',
                                style: TextStyle(color: Colors.white70),
                              ),
                              onTap: () async {
                                final created =
                                    await showModalBottomSheet<PeopleData?>(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => CreatePersonSheet(
                                      initialName:
                                          _query.isNotEmpty ? _query : null),
                                );
                                if (created != null && mounted) {
                                  setState(() {
                                    if (!_selected
                                        .any((p) => p.id == created.id)) {
                                      _selected.add(created);
                                    }
                                  });
                                }
                              },
                            ),
                          ],
                        );
                      },
                      loading: () => const Center(
                          child: CircularProgressIndicator(
                              color: Colors.white38)),
                      error: (e, _) => Center(
                          child: Text('Error: $e',
                              style:
                                  const TextStyle(color: Colors.white54))),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
