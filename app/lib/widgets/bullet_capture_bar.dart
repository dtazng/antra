import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/database/daos/bullets_dao.dart';
import 'package:antra/database/daos/people_dao.dart';
import 'package:antra/providers/database_provider.dart';
import 'package:antra/screens/people/create_person_sheet.dart';
import 'package:antra/screens/people/person_picker_sheet.dart';
import 'package:antra/theme/app_theme.dart';
import 'package:antra/widgets/glass_surface.dart';
import 'package:antra/widgets/person_avatar.dart';

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

  /// Explicitly linked people (via picker or @mention).
  List<PeopleData> _linkedPeople = [];

  /// People suggestions shown when user types @word.
  List<PeopleData> _suggestions = [];
  String _currentMention = '';

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
  // Type toggle
  // ---------------------------------------------------------------------------

  void _toggleType() {
    setState(() {
      _selectedType = _selectedType == 'note' ? 'task' : 'note';
    });
  }

  // ---------------------------------------------------------------------------
  // Person picker (multi-select)
  // ---------------------------------------------------------------------------

  Future<void> _pickPerson() async {
    final picked = await showModalBottomSheet<List<PeopleData>?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PersonPickerSheet(alreadyLinked: _linkedPeople),
    );
    if (picked != null && mounted) {
      setState(() {
        for (final p in picked) {
          if (!_linkedPeople.any((existing) => existing.id == p.id)) {
            _linkedPeople.add(p);
          }
        }
      });
    }
  }

  void _removeLinkedPerson(PeopleData person) {
    setState(() => _linkedPeople.removeWhere((p) => p.id == person.id));
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
        .where((p) => p.name.toLowerCase().startsWith(partial.toLowerCase()))
        .take(5)
        .toList();
    if (mounted) setState(() => _suggestions = filtered);
  }

  /// Opens CreatePersonSheet pre-filled with [name] and, on success, adds
  /// the new person to [_linkedPeople].
  Future<void> _createAndSelectPerson(String name) async {
    final created = await showModalBottomSheet<PeopleData?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CreatePersonSheet(initialName: name),
    );
    if (created != null && mounted) {
      _selectSuggestion(created);
    }
  }

  void _clearSuggestions() {
    if (_suggestions.isNotEmpty) setState(() => _suggestions = []);
    _currentMention = '';
  }

  void _selectSuggestion(PeopleData person) {
    final text = _controller.text;
    final cursor = _controller.selection.baseOffset;
    final beforeCursor = text.substring(0, cursor);
    final replaced = beforeCursor.replaceAll(
      RegExp('@${RegExp.escape(_currentMention)}\$'),
      '@${person.name}',
    );
    final afterCursor = text.substring(cursor);
    _controller.value = TextEditingValue(
      text: '$replaced $afterCursor',
      selection: TextSelection.collapsed(offset: replaced.length + 1),
    );
    // Add to linked people if not already present.
    if (!_linkedPeople.any((p) => p.id == person.id)) {
      setState(() => _linkedPeople.add(person));
    }
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

      // Link all explicitly selected people (via picker or @mention chips).
      final linkedIds = <String>{};
      for (final p in _linkedPeople) {
        await peopleDao.insertLink(id, p.id, linkType: 'mention');
        linkedIds.add(p.id);
      }

      // Process @mentions in text: link bullet to mentioned people not already linked.
      final mentionedNames = _extractMentions(content);
      for (final name in mentionedNames) {
        final person = await peopleDao.getPersonByName(name);
        if (person != null && !linkedIds.contains(person.id)) {
          await peopleDao.insertLink(id, person.id, linkType: 'mention');
        }
      }

      _controller.clear();
      setState(() => _linkedPeople = []);
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

  Widget _buildPersonChip(PeopleData person) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PersonAvatar(
            personId: person.id,
            displayName: person.name,
            radius: 10,
          ),
          const SizedBox(width: 4),
          Text(
            person.name,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(width: 2),
          GestureDetector(
            onTap: () => _removeLinkedPerson(person),
            child: const Icon(Icons.close, size: 12, color: Colors.white38),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Padding(
      padding: EdgeInsets.only(
        bottom: keyboardVisible ? 0 : MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // @mention suggestions overlay
          if (_currentMention.isNotEmpty || _suggestions.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: AntraColors.auroraNavy,
                border: Border(
                  top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.12)),
                ),
              ),
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  ..._suggestions.map((person) => ListTile(
                        dense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        leading: PersonAvatar(
                          personId: person.id,
                          displayName: person.name,
                          radius: 14,
                        ),
                        title: Text(
                          person.name,
                          style: const TextStyle(
                              fontSize: 14, color: Colors.white),
                        ),
                        onTap: () => _selectSuggestion(person),
                      )),
                  if (_currentMention.isNotEmpty)
                    ListTile(
                      dense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor:
                            Colors.white.withValues(alpha: 0.18),
                        child: const Icon(Icons.add,
                            size: 16, color: Colors.white),
                      ),
                      title: Text.rich(
                        TextSpan(children: [
                          const TextSpan(
                            text: 'Create ',
                            style: TextStyle(color: Colors.white),
                          ),
                          TextSpan(
                            text: '"$_currentMention"',
                            style: const TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.white,
                            ),
                          ),
                        ]),
                        style: const TextStyle(fontSize: 14),
                      ),
                      onTap: () => _createAndSelectPerson(_currentMention),
                    ),
                ],
              ),
            ),

          GlassSurface(
            style: GlassStyle.bar,
            padding: EdgeInsets.zero,
            borderRadius: BorderRadius.circular(AntraRadius.card),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Linked people chips
                  if (_linkedPeople.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _linkedPeople
                            .map(_buildPersonChip)
                            .toList(),
                      ),
                    ),

                  // Input row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Type toggle
                      GestureDetector(
                        onTap: _toggleType,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          child: Text(
                            _selectedType == 'note' ? 'Note' : 'Task',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),

                      // Text field
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: InputDecoration(
                            hintText: 'What happened today\u2026',
                            hintStyle: TextStyle(
                              color: Colors.white38,
                              fontSize: 15,
                            ),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                vertical: 8, horizontal: 10),
                            filled: true,
                            fillColor: Colors.white10,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                  AntraRadius.card),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                  AntraRadius.card),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                  AntraRadius.card),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          cursorColor: Colors.white70,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          minLines: 1,
                          maxLines: 4,
                          style: const TextStyle(
                              fontSize: 15, color: Colors.white),
                        ),
                      ),

                      // Person link button
                      GestureDetector(
                        onTap: _pickPerson,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          child: Icon(
                            Icons.alternate_email,
                            size: 18,
                            color: _linkedPeople.isNotEmpty
                                ? Colors.white70
                                : Colors.white38,
                          ),
                        ),
                      ),

                      // Submit button
                      _SubmitButton(
                        isSubmitting: _isSubmitting,
                        onPressed: _isSubmitting ? null : _submit,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
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
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: onPressed != null
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.add_rounded, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
