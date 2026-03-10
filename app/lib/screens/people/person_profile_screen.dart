import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/database/daos/people_dao.dart';
import 'package:antra/providers/database_provider.dart';
import 'package:antra/providers/people_provider.dart';
import 'package:antra/widgets/bullet_list_item.dart';

class PersonProfileScreen extends ConsumerStatefulWidget {
  final PeopleData person;

  const PersonProfileScreen({super.key, required this.person});

  @override
  ConsumerState<PersonProfileScreen> createState() =>
      _PersonProfileScreenState();
}

class _PersonProfileScreenState extends ConsumerState<PersonProfileScreen> {
  late PeopleData _person;
  bool _editingNotes = false;
  late TextEditingController _notesController;

  static const _cadenceOptions = [null, 7, 14, 30, 60];
  static const _cadenceLabels = {
    null: 'No reminder',
    7: 'Weekly',
    14: 'Bi-weekly',
    30: 'Monthly',
    60: 'Every 2 months',
  };

  @override
  void initState() {
    super.initState();
    _person = widget.person;
    _notesController = TextEditingController(text: _person.notes ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveNotes() async {
    final db = await ref.read(appDatabaseProvider.future);
    await PeopleDao(db).updatePerson(
      PeopleCompanion(
        id: Value(_person.id),
        notes: Value(_notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim()),
      ),
    );
    setState(() {
      _editingNotes = false;
      _person = _person.copyWith(notes: Value(_notesController.text.trim()));
    });
  }

  Future<void> _setCadence(int? cadence) async {
    final db = await ref.read(appDatabaseProvider.future);
    await PeopleDao(db).updatePerson(
      PeopleCompanion(
        id: Value(_person.id),
        reminderCadenceDays: Value(cadence),
      ),
    );
    setState(() {
      _person = _person.copyWith(reminderCadenceDays: Value(cadence));
    });
  }

  String _lastInteractionLabel() {
    final ts = _person.lastInteractionAt;
    if (ts == null) return 'No interactions recorded';
    final dt = DateTime.tryParse(ts);
    if (dt == null) return 'Unknown';
    return 'Last interaction: ${DateFormat('MMM d, yyyy').format(dt.toLocal())}';
  }

  @override
  Widget build(BuildContext context) {
    final bulletsAsync = ref.watch(bulletsForPersonProvider(_person.id));

    return Scaffold(
      appBar: AppBar(title: Text(_person.name)),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Last interaction
                  Text(
                    _lastInteractionLabel(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                  ),
                  const SizedBox(height: 16),

                  // Context notes
                  Row(
                    children: [
                      Text(
                        'Context Notes',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(
                          _editingNotes ? Icons.check : Icons.edit_outlined,
                        ),
                        onPressed: _editingNotes
                            ? _saveNotes
                            : () => setState(() => _editingNotes = true),
                      ),
                    ],
                  ),
                  if (_editingNotes)
                    TextField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Add context about this person…',
                      ),
                      minLines: 2,
                      maxLines: 6,
                      autofocus: true,
                    )
                  else
                    Text(
                      _person.notes?.isNotEmpty == true
                          ? _person.notes!
                          : 'No notes yet.',
                      style: TextStyle(
                        color: _person.notes?.isNotEmpty == true
                            ? null
                            : Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.4),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Reminder cadence
                  Row(
                    children: [
                      Text(
                        'Check-in Reminder',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const Spacer(),
                      DropdownButton<int?>(
                        value: _person.reminderCadenceDays,
                        items: _cadenceOptions.map((v) {
                          return DropdownMenuItem<int?>(
                            value: v,
                            child: Text(_cadenceLabels[v]!),
                          );
                        }).toList(),
                        onChanged: _setCadence,
                        underline: const SizedBox.shrink(),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Text(
                    'Interaction Timeline',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
            ),
          ),
          bulletsAsync.when(
            data: (bulletList) {
              if (bulletList.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No linked bullets yet.'),
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => BulletListItem(bullet: bulletList[index]),
                  childCount: bulletList.length,
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}
