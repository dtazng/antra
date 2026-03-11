import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/database/daos/bullets_dao.dart';
import 'package:antra/database/daos/people_dao.dart';
import 'package:antra/providers/database_provider.dart';
import 'package:antra/providers/people_provider.dart';

const _uuid = Uuid();

/// Quick interaction logging sheet, pre-attached to a person.
///
/// Shows a type selector (Note / Event / Task), a text field, and a Save
/// button. On save, creates a [Bullet] in today's DayLog and links it to the
/// given person via [PeopleDao.insertLink]. If [pinOnSave] is true, also
/// calls [PeopleDao.setPinned] so the note appears in the Pinned section.
class LogInteractionSheet extends ConsumerStatefulWidget {
  final String personId;
  final String personName;
  final String initialType;
  final bool pinOnSave;

  const LogInteractionSheet({
    super.key,
    required this.personId,
    required this.personName,
    this.initialType = 'note',
    this.pinOnSave = false,
  });

  @override
  ConsumerState<LogInteractionSheet> createState() =>
      _LogInteractionSheetState();
}

class _LogInteractionSheetState extends ConsumerState<LogInteractionSheet> {
  late String _selectedType;
  final _controller = TextEditingController();
  bool _isSaving = false;

  static const _types = ['note', 'event', 'task'];
  static const _typeLabels = {'note': 'Note', 'event': 'Event', 'task': 'Task'};
  static const _typeIcons = {
    'note': Icons.sticky_note_2_outlined,
    'event': Icons.radio_button_unchecked,
    'task': Icons.check_box_outline_blank,
  };

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final db = await ref.read(appDatabaseProvider.future);
      final bulletsDao = BulletsDao(db);
      final peopleDao = PeopleDao(db);

      final today = DateTime.now();
      final dateStr =
          '${today.year.toString().padLeft(4, '0')}-'
          '${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';

      final dayLog = await bulletsDao.getOrCreateDayLog(dateStr);
      final now = DateTime.now().toUtc().toIso8601String();
      final bulletId = _uuid.v4();

      final companion = BulletsCompanion.insert(
        id: bulletId,
        dayId: dayLog.id,
        content: content,
        type: Value(_selectedType),
        status: const Value('open'),
        position: 0,
        createdAt: now,
        updatedAt: now,
        deviceId: 'local',
      );

      await bulletsDao.insertBullet(companion);
      await peopleDao.insertLink(bulletId, widget.personId, linkType: 'manual');

      if (widget.pinOnSave) {
        await peopleDao.setPinned(bulletId, widget.personId, pinned: true);
      }

      ref.invalidate(recentBulletsForPersonProvider(widget.personId));
      ref.invalidate(interactionSummaryProvider(widget.personId));
      if (widget.pinOnSave) {
        ref.invalidate(pinnedBulletsForPersonProvider(widget.personId));
      }

      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Person badge
                  Row(
                    children: [
                      Chip(
                        avatar: const Icon(Icons.person_outline, size: 14),
                        label: Text(widget.personName,
                            style: const TextStyle(fontSize: 12)),
                        backgroundColor: cs.secondaryContainer,
                        side: BorderSide.none,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Type selector
                  Row(
                    children: _types.map((type) {
                      final selected = _selectedType == type;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          selected: selected,
                          avatar: Icon(_typeIcons[type], size: 14),
                          label: Text(_typeLabels[type]!,
                              style: const TextStyle(fontSize: 12)),
                          onSelected: (_) =>
                              setState(() => _selectedType = type),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  // Content field
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    minLines: 3,
                    maxLines: 6,
                    decoration: InputDecoration(
                      hintText: 'What happened? Add a note…',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Save button
                  FilledButton(
                    onPressed: _isSaving ? null : _save,
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(44)),
                    child: _isSaving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
