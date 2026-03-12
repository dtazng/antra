import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/database/daos/bullets_dao.dart';
import 'package:antra/database/daos/people_dao.dart';
import 'package:antra/providers/database_provider.dart';
import 'package:antra/screens/people/person_picker_sheet.dart';

const _uuid = Uuid();

/// Always-visible quick interaction capture bar, pinned to the bottom of
/// [DayViewScreen]. Provides a 3-tap path: type → person → Save.
class QuickLogBar extends ConsumerStatefulWidget {
  const QuickLogBar({
    super.key,
    required this.onInteractionLogged,
    required this.date,
  });

  /// Called with the new bullet's ID after a successful save.
  final void Function(String bulletId) onInteractionLogged;

  /// The date (YYYY-MM-DD) to log the interaction to.
  final String date;

  @override
  ConsumerState<QuickLogBar> createState() => _QuickLogBarState();
}

class _QuickLogBarState extends ConsumerState<QuickLogBar> {
  _LogType? _selectedType;
  PeopleData? _selectedPerson;
  final _noteController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Material(
        elevation: 8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_selectedType != null && _selectedPerson != null)
              _buildConfirmRow(context),
            _buildTypeRow(context),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Type row (always visible)
  // ---------------------------------------------------------------------------

  Widget _buildTypeRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final type in _LogType.values)
            _TypeButton(
              type: type,
              selected: _selectedType == type,
              onTap: () => _onTypeTap(context, type),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Confirm row (shown after type + person selected)
  // ---------------------------------------------------------------------------

  Widget _buildConfirmRow(BuildContext context) {
    final type = _selectedType!;
    final person = _selectedPerson!;
    final requiresNote = type == _LogType.note;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${type.emoji}  ${type.label} · ${person.name}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              TextButton(onPressed: _reset, child: const Text('Cancel')),
            ],
          ),
          if (requiresNote) ...[
            TextField(
              controller: _noteController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Write a note…',
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 6),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (requiresNote && _noteController.text.trim().isEmpty) || _saving
                  ? null
                  : () => _save(context),
              child: _saving
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Interaction logic
  // ---------------------------------------------------------------------------

  Future<void> _onTypeTap(BuildContext context, _LogType type) async {
    final person = await showModalBottomSheet<PeopleData>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const PersonPickerSheet(),
    );
    if (!mounted || person == null) return;
    setState(() {
      _selectedType = type;
      _selectedPerson = person;
      _noteController.clear();
    });
  }

  Future<void> _save(BuildContext context) async {
    final type = _selectedType;
    final person = _selectedPerson;
    if (type == null || person == null) return;

    setState(() => _saving = true);
    try {
      final db = await ref.read(appDatabaseProvider.future);
      final bulletsDao = BulletsDao(db);
      final peopleDao = PeopleDao(db);

      final now = DateTime.now().toUtc().toIso8601String();
      final dayLog = await bulletsDao.getOrCreateDayLog(widget.date);
      final bulletId = _uuid.v4();

      final content = type == _LogType.note
          ? _noteController.text.trim()
          : '${type.emoji} ${type.label} with ${person.name}';

      await bulletsDao.insertBullet(
        BulletsCompanion.insert(
          id: bulletId,
          dayId: dayLog.id,
          type: Value(type.dbType),
          content: content,
          position: 0,
          createdAt: now,
          updatedAt: now,
          deviceId: 'local',
        ),
      );
      await peopleDao.insertLink(bulletId, person.id);

      widget.onInteractionLogged(bulletId);
      if (mounted) _reset();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save interaction: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _reset() {
    setState(() {
      _selectedType = null;
      _selectedPerson = null;
      _noteController.clear();
    });
  }
}

// ---------------------------------------------------------------------------
// Type enum + button
// ---------------------------------------------------------------------------

enum _LogType {
  coffee('Coffee', '☕', 'event'),
  call('Call', '📞', 'event'),
  message('Message', '✉️', 'event'),
  note('Note', '✍️', 'note');

  const _LogType(this.label, this.emoji, this.dbType);
  final String label;
  final String emoji;
  final String dbType;
}

class _TypeButton extends StatelessWidget {
  const _TypeButton({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final _LogType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(type.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 2),
            Text(
              type.label,
              style: TextStyle(
                fontSize: 11,
                color: selected
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
