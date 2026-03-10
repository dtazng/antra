import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/database/daos/bullets_dao.dart';
import 'package:antra/database/daos/people_dao.dart';
import 'package:antra/providers/database_provider.dart';

const _uuid = Uuid();

class BulletCaptureBar extends ConsumerStatefulWidget {
  final String date;

  const BulletCaptureBar({super.key, required this.date});

  @override
  ConsumerState<BulletCaptureBar> createState() => _BulletCaptureBarState();
}

class _BulletCaptureBarState extends ConsumerState<BulletCaptureBar> {
  final _controller = TextEditingController();
  String _selectedType = 'note';
  bool _isSubmitting = false;

  /// People suggestions shown when user types @word.
  List<PeopleData> _suggestions = [];
  String _currentMention = '';

  static const _types = ['task', 'note', 'event'];
  static const _typeIcons = {
    'task': Icons.check_box_outline_blank,
    'note': Icons.circle_outlined,
    'event': Icons.radio_button_unchecked,
  };
  static const _typeLabels = {
    'task': 'Task',
    'note': 'Note',
    'event': 'Event',
  };

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // @mention autocomplete
  // ---------------------------------------------------------------------------

  void _onTextChanged() {
    final text = _controller.text;
    final cursor = _controller.selection.baseOffset;
    if (cursor < 0) return;

    final beforeCursor = text.substring(0, cursor);
    final mentionMatch = RegExp(r'@(\w*)$').firstMatch(beforeCursor);

    if (mentionMatch != null) {
      final partial = mentionMatch.group(1)!;
      _currentMention = partial;
      _fetchSuggestions(partial);
    } else {
      _clearSuggestions();
    }
  }

  Future<void> _fetchSuggestions(String partial) async {
    final db = await ref.read(appDatabaseProvider.future);
    final allPeople = await (db.select(db.people)
          ..where((t) => t.isDeleted.equals(0))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
    final filtered = allPeople
        .where((p) =>
            p.name.toLowerCase().startsWith(partial.toLowerCase()))
        .take(5)
        .toList();
    if (mounted) setState(() => _suggestions = filtered);
  }

  void _clearSuggestions() {
    if (_suggestions.isNotEmpty) setState(() => _suggestions = []);
    _currentMention = '';
  }

  void _selectSuggestion(PeopleData person) {
    final text = _controller.text;
    final cursor = _controller.selection.baseOffset;
    final beforeCursor = text.substring(0, cursor);
    // Replace the partial @word with the full @Name.
    final replaced = beforeCursor.replaceAll(
      RegExp('@${RegExp.escape(_currentMention)}\$'),
      '@${person.name}',
    );
    final afterCursor = text.substring(cursor);
    _controller.value = TextEditingValue(
      text: '$replaced $afterCursor',
      selection: TextSelection.collapsed(offset: replaced.length + 1),
    );
    _clearSuggestions();
  }

  // ---------------------------------------------------------------------------
  // Submit
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    _clearSuggestions();
    try {
      final db = await ref.read(appDatabaseProvider.future);
      final bulletsDao = BulletsDao(db);
      final peopleDao = PeopleDao(db);
      final dayLog = await bulletsDao.getOrCreateDayLog(widget.date);

      final now = DateTime.now().toUtc().toIso8601String();
      final id = _uuid.v4();

      final companion = BulletsCompanion.insert(
        id: id,
        dayId: dayLog.id,
        content: content,
        type: Value(_selectedType),
        status: const Value('open'),
        position: 0,
        createdAt: now,
        updatedAt: now,
        deviceId: 'local',
      );

      await bulletsDao.insertBulletWithTags(companion, content);

      // Process @mentions: link bullet to mentioned people.
      final mentionedNames = _extractMentions(content);
      for (final name in mentionedNames) {
        final person = await peopleDao.getPersonByName(name);
        if (person != null) {
          await peopleDao.insertLink(id, person.id);
          await peopleDao.updateLastInteractionAt(person.id, now);
        }
      }

      _controller.clear();
      if (mounted) FocusScope.of(context).unfocus();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Extracts @mention names from [content].
  List<String> _extractMentions(String content) {
    final regex = RegExp(r'@(\w+(?:\s+\w+)*)');
    return regex
        .allMatches(content)
        .map((m) => m.group(1)!)
        .toSet()
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // @mention suggestions
          if (_suggestions.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                border: Border(
                  top: BorderSide(color: cs.outlineVariant.withValues(alpha:0.4)),
                ),
              ),
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final person = _suggestions[index];
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: cs.primaryContainer,
                      child: Text(
                        person.name[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                    ),
                    title: Text(person.name,
                        style: const TextStyle(fontSize: 14)),
                    onTap: () => _selectSuggestion(person),
                  );
                },
              ),
            ),

          Container(
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(
                top: BorderSide(color: cs.outlineVariant.withValues(alpha:0.4)),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Bullet type pills
                Row(
                  children: _types.map((type) {
                    final selected = _selectedType == type;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _TypePill(
                        type: type,
                        icon: _typeIcons[type]!,
                        label: _typeLabels[type]!,
                        selected: selected,
                        onTap: () => setState(() => _selectedType = type),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                // Input row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: 'Capture a thought…',
                          hintStyle: TextStyle(
                            color: cs.onSurfaceVariant.withValues(alpha:0.6),
                            fontSize: 15,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        minLines: 1,
                        maxLines: 4,
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _SubmitButton(
                      isSubmitting: _isSubmitting,
                      onPressed: _isSubmitting ? null : _submit,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  final String type;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypePill({
    required this.type,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
                color:
                    selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final bool isSubmitting;
  final VoidCallback? onPressed;

  const _SubmitButton({required this.isSubmitting, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: onPressed != null ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: isSubmitting
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.onPrimary,
                  ),
                )
              : Icon(Icons.add_rounded, color: cs.onPrimary, size: 22),
        ),
      ),
    );
  }
}
