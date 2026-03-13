import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/database/daos/people_dao.dart';
import 'package:antra/providers/database_provider.dart';
import 'package:antra/widgets/glass_surface.dart';

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
    return GlassSurface(
      style: GlassStyle.modal,
      padding: EdgeInsets.fromLTRB(
        16,
        20,
        16,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Add Person',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white),
          ),
          const SizedBox(height: 16),
          _GlassTextField(
            controller: _nameController,
            autofocus: widget.initialName == null,
            labelText: 'Name',
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) {
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
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Similar person already exists:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
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
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.white70),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(dup),
                            child: const Text('Use this',
                                style: TextStyle(color: Colors.white54)),
                          ),
                        ],
                      ),
                    ),
                  Divider(
                      height: 12,
                      color: Colors.white.withValues(alpha: 0.15)),
                  const Text(
                    'These are different people with similar names.',
                    style: TextStyle(fontSize: 11, color: Colors.white38),
                  ),
                  const SizedBox(height: 4),
                  OutlinedButton(
                    onPressed: () => _save(forceCreate: true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: const Text('Create anyway'),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          _GlassTextField(
            controller: _notesController,
            labelText: 'Context notes (optional)',
            minLines: 2,
            maxLines: 4,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              foregroundColor: Colors.white,
              side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.25), width: 0.5),
            ),
            onPressed: _isSaving ? null : () => _save(),
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int? minLines;
  final int? maxLines;

  const _GlassTextField({
    required this.controller,
    required this.labelText,
    this.autofocus = false,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.onSubmitted,
    this.minLines,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: TextField(
          controller: controller,
          autofocus: autofocus,
          style: const TextStyle(color: Colors.white),
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          minLines: minLines,
          maxLines: maxLines ?? 1,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            labelText: labelText,
            labelStyle: const TextStyle(color: Colors.white54),
            border: InputBorder.none,
            floatingLabelStyle: const TextStyle(color: Colors.white38),
          ),
        ),
      ),
    );
  }
}
