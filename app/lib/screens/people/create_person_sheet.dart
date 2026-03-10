import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/database/daos/people_dao.dart';
import 'package:antra/providers/database_provider.dart';

const _uuid = Uuid();

class CreatePersonSheet extends ConsumerStatefulWidget {
  const CreatePersonSheet({super.key});

  @override
  ConsumerState<CreatePersonSheet> createState() => _CreatePersonSheetState();
}

class _CreatePersonSheetState extends ConsumerState<CreatePersonSheet> {
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _isSaving) return;

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

      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Context notes (optional)',
              border: OutlineInputBorder(),
            ),
            minLines: 2,
            maxLines: 4,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _isSaving ? null : _save,
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
