import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:antra/database/app_database.dart';
import 'package:antra/providers/person_important_dates_providers.dart';
import 'package:antra/screens/people/important_date_form_sheet.dart';

/// Compact list of important dates for a person.
/// Birthday row always appears first; additional dates follow sorted by month/day.
/// Swipe left to delete; tap any row to edit.
class ImportantDatesSection extends ConsumerWidget {
  const ImportantDatesSection({
    super.key,
    required this.personId,
  });

  final String personId;

  static const _months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _dateLabel(PersonImportantDate d) {
    final month = d.month >= 1 && d.month <= 12 ? _months[d.month] : '?';
    final day = d.day.toString();
    return d.year != null ? '$month $day, ${d.year}' : '$month $day';
  }

  static String _reminderLabel(PersonImportantDate d) {
    if (d.reminderOffsetDays == null) return '';
    final offset = d.reminderOffsetDays!;
    if (offset == 0) return 'Reminder: On the day';
    if (offset == 1) return 'Reminder: 1 day before';
    if (offset == 7) return 'Reminder: 1 week before';
    if (offset == 14) return 'Reminder: 2 weeks before';
    if (offset == 30) return 'Reminder: 1 month before';
    if (offset % 7 == 0) return 'Reminder: ${offset ~/ 7} weeks before';
    return 'Reminder: $offset days before';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datesAsync = ref.watch(personImportantDatesProvider(personId));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'IMPORTANT DATES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white38,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _openAddSheet(context, ref),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text(
                  '+ Add date',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
              ),
            ],
          ),
          datesAsync.when(
            data: (dates) {
              if (dates.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No important dates yet',
                    style: const TextStyle(
                        fontSize: 13, color: Colors.white38),
                  ),
                );
              }
              return Column(
                children: dates
                    .map((d) => _DateRow(
                          date: d,
                          dateLabel: _dateLabel(d),
                          reminderLabel: _reminderLabel(d),
                          onTap: () => _openEditSheet(context, ref, d),
                          onDelete: () => ref
                              .read(deleteImportantDateProvider.notifier)
                              .call(d.id),
                        ))
                    .toList(),
              );
            },
            loading: () => const SizedBox(height: 32),
            error: (e, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  void _openAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ImportantDateFormSheet(personId: personId),
    );
  }

  void _openEditSheet(
      BuildContext context, WidgetRef ref, PersonImportantDate date) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          ImportantDateFormSheet(personId: personId, existing: date),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.date,
    required this.dateLabel,
    required this.reminderLabel,
    required this.onTap,
    required this.onDelete,
  });

  final PersonImportantDate date;
  final String dateLabel;
  final String reminderLabel;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(date.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete_outline, color: Colors.redAccent),
      ),
      onDismissed: (_) => onDelete(),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                date.isBirthday == 1 ? '🎂' : '📅',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      date.label,
                      style: const TextStyle(
                          fontSize: 14, color: Colors.white),
                    ),
                    if (reminderLabel.isNotEmpty)
                      Text(
                        reminderLabel,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white38),
                      ),
                  ],
                ),
              ),
              Text(
                dateLabel,
                style: const TextStyle(
                    fontSize: 13, color: Colors.white60),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  size: 14, color: Colors.white24),
            ],
          ),
        ),
      ),
    );
  }
}
