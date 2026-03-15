import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/providers/person_important_dates_providers.dart';

/// Reminder preset identifiers.
enum _ReminderPreset {
  none,
  onTheDay,
  oneDayBefore,
  threeDaysBefore,
  oneWeekBefore,
  twoWeeksBefore,
  oneMonthBefore,
  custom,
}

extension _ReminderPresetLabel on _ReminderPreset {
  String get label => switch (this) {
        _ReminderPreset.none => 'No reminder',
        _ReminderPreset.onTheDay => 'On the day',
        _ReminderPreset.oneDayBefore => '1 day before',
        _ReminderPreset.threeDaysBefore => '3 days before',
        _ReminderPreset.oneWeekBefore => '1 week before',
        _ReminderPreset.twoWeeksBefore => '2 weeks before',
        _ReminderPreset.oneMonthBefore => '1 month before',
        _ReminderPreset.custom => 'Custom',
      };

  /// Returns [reminderOffsetDays, reminderRecurrence] for non-custom presets.
  (int?, String?) get defaults => switch (this) {
        _ReminderPreset.none => (null, null),
        _ReminderPreset.onTheDay => (0, 'yearly'),
        _ReminderPreset.oneDayBefore => (1, 'yearly'),
        _ReminderPreset.threeDaysBefore => (3, 'yearly'),
        _ReminderPreset.oneWeekBefore => (7, 'yearly'),
        _ReminderPreset.twoWeeksBefore => (14, 'yearly'),
        _ReminderPreset.oneMonthBefore => (30, 'yearly'),
        _ReminderPreset.custom => (null, null),
      };
}

_ReminderPreset _presetFromOffsetDays(int? days) {
  if (days == null) return _ReminderPreset.none;
  return switch (days) {
    0 => _ReminderPreset.onTheDay,
    1 => _ReminderPreset.oneDayBefore,
    3 => _ReminderPreset.threeDaysBefore,
    7 => _ReminderPreset.oneWeekBefore,
    14 => _ReminderPreset.twoWeeksBefore,
    30 => _ReminderPreset.oneMonthBefore,
    _ => _ReminderPreset.custom,
  };
}

/// Modal bottom sheet to add or edit an important date.
class ImportantDateFormSheet extends ConsumerStatefulWidget {
  const ImportantDateFormSheet({
    super.key,
    required this.personId,
    this.existing,
  });

  final String personId;

  /// When non-null, pre-fills the form for editing.
  final PersonImportantDate? existing;

  @override
  ConsumerState<ImportantDateFormSheet> createState() =>
      _ImportantDateFormSheetState();
}

class _ImportantDateFormSheetState
    extends ConsumerState<ImportantDateFormSheet> {
  final _labelCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  bool _isBirthday = false;
  int _month = 1;
  int _day = 1;
  int? _year;
  _ReminderPreset _preset = _ReminderPreset.none;

  // Custom reminder fields
  int _customOffsetDays = 7;
  String _customRecurrence = 'yearly';

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    if (ex != null) {
      _labelCtrl.text = ex.label;
      _noteCtrl.text = ex.note ?? '';
      _isBirthday = ex.isBirthday == 1;
      _month = ex.month;
      _day = ex.day;
      _year = ex.year;
      _preset = _presetFromOffsetDays(ex.reminderOffsetDays);
      if (_preset == _ReminderPreset.custom) {
        _customOffsetDays = ex.reminderOffsetDays ?? 7;
        _customRecurrence = ex.reminderRecurrence ?? 'yearly';
      }
    }
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  (int?, String?) get _resolvedReminder {
    if (_preset == _ReminderPreset.custom) {
      return (_customOffsetDays, _customRecurrence);
    }
    return _preset.defaults;
  }

  Future<void> _save() async {
    if (_labelCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final (offsetDays, recurrence) = _resolvedReminder;
    try {
      if (widget.existing == null) {
        await ref.read(addImportantDateProvider.notifier).call(
              personId: widget.personId,
              label: _labelCtrl.text.trim(),
              isBirthday: _isBirthday,
              month: _month,
              day: _day,
              year: _year,
              reminderOffsetDays: offsetDays,
              reminderRecurrence: recurrence,
              note: _noteCtrl.text.trim().isEmpty
                  ? null
                  : _noteCtrl.text.trim(),
            );
      } else {
        await ref.read(updateImportantDateProvider.notifier).call(
              id: widget.existing!.id,
              label: _labelCtrl.text.trim(),
              isBirthday: _isBirthday,
              month: _month,
              day: _day,
              year: _year,
              reminderOffsetDays: offsetDays,
              reminderRecurrence: recurrence,
              note: _noteCtrl.text.trim().isEmpty
                  ? null
                  : _noteCtrl.text.trim(),
            );
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1F2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              widget.existing == null ? 'Add Date' : 'Edit Date',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
            ),
            const SizedBox(height: 16),

            // Birthday toggle
            Row(
              children: [
                const Text('Birthday',
                    style: TextStyle(fontSize: 14, color: Colors.white70)),
                const Spacer(),
                Switch(
                  value: _isBirthday,
                  onChanged: (v) => setState(() {
                    _isBirthday = v;
                    if (v) _labelCtrl.text = 'Birthday';
                  }),
                  activeColor: Colors.white,
                  trackColor: WidgetStateProperty.all(
                      Colors.white.withValues(alpha: 0.2)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Label
            _FieldLabel('Title'),
            TextField(
              controller: _labelCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('e.g. Anniversary'),
            ),
            const SizedBox(height: 16),

            // Date row: month / day / year
            _FieldLabel('Date'),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _DropdownField<int>(
                    value: _month,
                    items: List.generate(
                      12,
                      (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text(_monthName(i + 1)),
                      ),
                    ),
                    onChanged: (v) => setState(() => _month = v!),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _DropdownField<int>(
                    value: _day,
                    items: List.generate(
                      31,
                      (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text('${i + 1}'),
                      ),
                    ),
                    onChanged: (v) => setState(() => _day = v!),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Year (opt.)'),
                    onChanged: (v) => setState(
                        () => _year = int.tryParse(v.trim())),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Reminder preset
            _FieldLabel('Reminder'),
            _DropdownField<_ReminderPreset>(
              value: _preset,
              items: _ReminderPreset.values
                  .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(p.label),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _preset = v!),
            ),

            // Custom reminder fields
            if (_preset == _ReminderPreset.custom) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Days before'),
                      controller:
                          TextEditingController(text: '$_customOffsetDays'),
                      onChanged: (v) => setState(() =>
                          _customOffsetDays = int.tryParse(v) ?? 7),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DropdownField<String>(
                      value: _customRecurrence,
                      items: const [
                        DropdownMenuItem(
                            value: 'yearly', child: Text('Yearly')),
                        DropdownMenuItem(
                            value: 'once', child: Text('Once')),
                      ],
                      onChanged: (v) =>
                          setState(() => _customRecurrence = v!),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            // Note
            _FieldLabel('Note (optional)'),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Add a note…'),
            ),
            const SizedBox(height: 24),

            // Save button
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(widget.existing == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  static String _monthName(int m) => const [
        '', 'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December',
      ][m];

  static InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.07),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white54),
        ),
      );
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?) onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      isExpanded: true,
      dropdownColor: const Color(0xFF1A1F2E),
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.07),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      ),
    );
  }
}
