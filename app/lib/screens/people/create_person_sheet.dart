import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/database/daos/people_dao.dart';
import 'package:antra/providers/database_provider.dart';

const _uuid = Uuid();

class CreatePersonSheet extends ConsumerStatefulWidget {
  /// Pre-fill the name field (e.g. from an @mention in the capture bar).
  final String? initialName;

  const CreatePersonSheet({super.key, this.initialName});

  @override
  ConsumerState<CreatePersonSheet> createState() => _CreatePersonSheetState();
}

class _CreatePersonSheetState extends ConsumerState<CreatePersonSheet> {
  late final TextEditingController _nameController;
  final _notesController = TextEditingController();
  bool _isSaving = false;
  List<PeopleData> _duplicates = [];
  bool _checkedDuplicates = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _checkDuplicates() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final db = await ref.read(appDatabaseProvider.future);
    final matches = await PeopleDao(db).findSimilarPeople(name);
    setState(() {
      _duplicates = matches;
      _checkedDuplicates = true;
    });
  }

  Future<void> _save({bool forceCreate = false}) async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _isSaving) return;

    // First pass: check for duplicates (unless forced or pre-filled from @mention)
    if (!forceCreate && !_checkedDuplicates) {
      await _checkDuplicates();
      if (_duplicates.isNotEmpty) return; // Show warning, wait for user action
    }

    setState(() => _isSaving = true);
    try {
      final db = await ref.read(appDatabaseProvider.future);
      final now = DateTime.now().toUtc().toIso8601String();
      final id = _uuid.v4();
      final notes = _notesController.text.trim();

      await PeopleDao(db).insertPerson(
        PeopleCompanion.insert(
          id: id,
          name: name,
          notes: notes.isEmpty ? const Value.absent() : Value(notes),
          createdAt: now,
          updatedAt: now,
          deviceId: 'local',
        ),
      );

      // Return the created PeopleData so callers can use it immediately.
      final created = PeopleData(
        id: id,
        name: name,
        notes: notes.isEmpty ? null : notes,
        reminderCadenceDays: null,
        lastInteractionAt: null,
        createdAt: now,
        updatedAt: now,
        syncId: null,
        deviceId: 'local',
        isDeleted: 0,
        company: null,
        role: null,
        email: null,
        phone: null,
        birthday: null,
        location: null,
        tags: null,
        relationshipType: null,
        needsFollowUp: 0,
        followUpDate: null,
      );

      if (mounted) Navigator.of(context).pop(created);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add Person', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            autofocus: widget.initialName == null,
            decoration: InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) {
              // Reset duplicate check when user edits name
              if (_checkedDuplicates) {
                setState(() {
                  _checkedDuplicates = false;
                  _duplicates = [];
                });
              }
            },
          ),

          // Duplicate warning card
          if (_checkedDuplicates && _duplicates.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.errorContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: cs.error.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Similar person already exists:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final dup in _duplicates)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              dup.name +
                                  (dup.company != null
                                      ? ' · ${dup.company}'
                                      : ''),
                              style: TextStyle(
                                  fontSize: 13, color: cs.onErrorContainer),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(dup),
                            child: const Text('Use this'),
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 12),
                  Text(
                    'These are different people with similar names.',
                    style: TextStyle(
                        fontSize: 11,
                        color: cs.onErrorContainer.withValues(alpha: 0.7)),
                  ),
                  const SizedBox(height: 4),
                  OutlinedButton(
                    onPressed: () => _save(forceCreate: true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.error,
                      side:
                          BorderSide(color: cs.error.withValues(alpha: 0.5)),
                    ),
                    child: const Text('Create anyway'),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            decoration: InputDecoration(
              labelText: 'Context notes (optional)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              hintStyle:
                  TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
            ),
            minLines: 2,
            maxLines: 4,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _isSaving ? null : () => _save(),
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}
