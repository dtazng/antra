import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/database/daos/bullets_dao.dart';
import 'package:antra/database/daos/people_dao.dart';
import 'package:antra/providers/database_provider.dart';
import 'package:antra/screens/people/person_picker_sheet.dart';
import 'package:antra/theme/app_theme.dart';
import 'package:antra/widgets/glass_surface.dart';

const _uuid = Uuid();

/// Always-visible quick interaction capture bar, pinned to the bottom of
/// [DayViewScreen]. Provides a 3-tap path: type → person → Save.
///
/// Rendered as a [GlassSurface.bar] with spring tap feedback on type buttons.
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

class _QuickLogBarState extends ConsumerState<QuickLogBar>
    with SingleTickerProviderStateMixin {
  _LogType? _selectedType;
  PeopleData? _selectedPerson;
  final _noteController = TextEditingController();
  bool _saving = false;

  // Fade animation for smooth reset after save.
  late AnimationController _resetController;
  late Animation<double> _resetAnim;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: AntraMotion.fadeDismiss,
      value: 1.0,
    );
    _resetAnim = CurvedAnimation(
      parent: _resetController,
      curve: AntraMotion.dismissCurve,
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    _resetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _resetAnim,
      child: GlassSurface(
        style: GlassStyle.bar,
        padding: EdgeInsets.zero,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_selectedType != null && _selectedPerson != null)
                _buildConfirmRow(context),
              _buildTypeRow(context),
            ],
          ),
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
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${type.emoji}  ${type.label} · ${person.name}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
              TextButton(
                onPressed: _reset,
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white60),
                ),
              ),
            ],
          ),
          if (requiresNote) ...[
            TextField(
              controller: _noteController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Write a note…',
                hintStyle: const TextStyle(color: Colors.white38),
                isDense: true,
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed:
                  (requiresNote && _noteController.text.trim().isEmpty) ||
                          _saving
                      ? null
                      : () => _save(context),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.06),
                disabledForegroundColor: Colors.white38,
              ),
              child: _saving
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save'),
            ),
          ),
          const SizedBox(height: 4),
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
      backgroundColor: Colors.transparent,
      builder: (_) => GlassSurface(
        style: GlassStyle.modal,
        padding: EdgeInsets.zero,
        child: const PersonPickerSheet(),
      ),
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
      if (mounted) {
        // Fade out then reset — smooth dismissal.
        await _resetController.reverse();
        _reset();
        await _resetController.forward();
      }
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
// Type enum + button with tap glow feedback
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

class _TypeButton extends StatefulWidget {
  const _TypeButton({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final _LogType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_TypeButton> createState() => _TypeButtonState();
}

class _TypeButtonState extends State<_TypeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnim;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: AntraMotion.tapFeedback,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _pressController, curve: AntraMotion.tapCurve),
    );
    _glowAnim = Tween<double>(begin: 0.0, end: 0.35).animate(
      CurvedAnimation(parent: _pressController, curve: AntraMotion.tapCurve),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) {
        _pressController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _pressController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedBuilder(
          animation: _glowAnim,
          builder: (context, child) {
            return AnimatedContainer(
              duration: AntraMotion.tapFeedback,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: widget.selected
                    ? Colors.white.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: _glowAnim.value * 0.15),
                borderRadius: BorderRadius.circular(20),
                border: widget.selected
                    ? Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 0.5,
                      )
                    : null,
              ),
              child: child,
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.type.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 2),
              Text(
                widget.type.label,
                style: TextStyle(
                  fontSize: 11,
                  color: widget.selected ? Colors.white : Colors.white54,
                  fontWeight: widget.selected
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
