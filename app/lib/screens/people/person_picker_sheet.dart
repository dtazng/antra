import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/providers/people_provider.dart';
import 'package:antra/screens/people/create_person_sheet.dart';
import 'package:antra/widgets/glass_surface.dart';
import 'package:antra/widgets/person_avatar.dart';

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
          return GlassSurface(
            style: GlassStyle.modal,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                // Handle
                const SizedBox(height: 8),
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
                const SizedBox(height: 12),
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
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 12),
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
                          ...filtered.map((person) => ListTile(
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
                                onTap: () =>
                                    Navigator.of(context).pop(person),
                              )),
                          // "Create new person" row at the bottom
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
                              if (created != null && context.mounted) {
                                Navigator.of(context).pop(created);
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
    );
  }
}
