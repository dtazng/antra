import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/providers/people_provider.dart';
import 'package:antra/screens/people/create_person_sheet.dart';

/// A search-and-select bottom sheet for picking an existing person.
/// Returns the selected [PeopleData] via Navigator.pop, or null if dismissed.
class PersonPickerSheet extends ConsumerStatefulWidget {
  const PersonPickerSheet({super.key});

  @override
  ConsumerState<PersonPickerSheet> createState() => _PersonPickerSheetState();
}

class _PersonPickerSheetState extends ConsumerState<PersonPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final allAsync = ref.watch(allPeopleProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Handle
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search people…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 12),
                  ),
                  onChanged: (v) => setState(() => _query = v.trim()),
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
                        ...filtered.map((person) => ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16),
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor: cs.primaryContainer,
                                child: Text(
                                  person.name[0].toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: cs.onPrimaryContainer,
                                  ),
                                ),
                              ),
                              title: Text(person.name),
                              subtitle: person.company != null
                                  ? Text(
                                      person.company!,
                                      style: TextStyle(
                                          color: cs.onSurfaceVariant,
                                          fontSize: 12),
                                    )
                                  : null,
                              onTap: () => Navigator.of(context).pop(person),
                            )),
                        // "Create new person" row at the bottom
                        ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: cs.secondaryContainer,
                            child: Icon(Icons.person_add_outlined,
                                size: 18, color: cs.onSecondaryContainer),
                          ),
                          title: const Text('Create new person'),
                          onTap: () async {
                            final created =
                                await showModalBottomSheet<PeopleData?>(
                              context: context,
                              isScrollControlled: true,
                              builder: (_) => CreatePersonSheet(
                                  initialName: _query.isNotEmpty ? _query : null),
                            );
                            if (created != null && context.mounted) {
                              Navigator.of(context).pop(created);
                            }
                          },
                        ),
                      ],
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
