import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:antra/database/daos/smart_prompt_dismissals_dao.dart';
import 'package:antra/models/smart_prompt.dart';
import 'package:antra/providers/database_provider.dart';
import 'package:antra/services/smart_prompt_service.dart';

part 'smart_prompt_providers.g.dart';

/// Streams smart prompts triggered by upcoming important dates.
@riverpod
Stream<List<SmartPrompt>> importantDatePrompts(
    ImportantDatePromptsRef ref) async* {
  final db = await ref.watch(appDatabaseProvider.future);
  final svc = SmartPromptService(db: db);
  yield* svc.watchImportantDatePrompts();
}

/// Streams inactivity prompts (90+ day gap).
@riverpod
Stream<List<SmartPrompt>> inactivityPrompts(
    InactivityPromptsRef ref) async* {
  final db = await ref.watch(appDatabaseProvider.future);
  final svc = SmartPromptService(db: db);
  yield* svc.watchInactivityPrompts();
}

/// Streams follow-up prompts (6–8 day window).
@riverpod
Stream<List<SmartPrompt>> followUpPrompts(
    FollowUpPromptsRef ref) async* {
  final db = await ref.watch(appDatabaseProvider.future);
  final svc = SmartPromptService(db: db);
  yield* svc.watchFollowUpPrompts();
}

/// Merges all prompt types into a single sorted list for the Needs Attention
/// section. Re-evaluates whenever any of the three source streams emit.
@riverpod
List<SmartPrompt> needsAttentionPrompts(NeedsAttentionPromptsRef ref) {
  final importantDate = ref.watch(importantDatePromptsProvider);
  final inactivity = ref.watch(inactivityPromptsProvider);
  final followUp = ref.watch(followUpPromptsProvider);

  final combined = [
    ...importantDate.valueOrNull ?? [],
    ...inactivity.valueOrNull ?? [],
    ...followUp.valueOrNull ?? [],
  ];

  // Important-date prompts first (soonest first), then follow-up, then inactivity.
  combined.sort((a, b) {
    const order = {'important_date': 0, 'follow_up': 1, 'inactivity': 2};
    final cmp = (order[a.promptType] ?? 3).compareTo(order[b.promptType] ?? 3);
    if (cmp != 0) return cmp;
    return (a.daysUntil ?? 999).compareTo(b.daysUntil ?? 999);
  });

  return combined;
}

/// Mutations for dismissing or snoozing smart prompts.
@riverpod
class SmartPromptActions extends _$SmartPromptActions {
  @override
  void build() {}

  /// Marks a prompt as done for this occurrence.
  ///
  /// - `important_date`: dismisses for 365 days (until next year's reminder)
  /// - `inactivity` / `follow_up`: dismisses for 30 days
  Future<void> markDone(SmartPrompt prompt) async {
    final db = await ref.read(appDatabaseProvider.future);
    final dao = SmartPromptDismissalsDao(db);

    final days = prompt.promptType == 'important_date' ? 365 : 30;
    final until = DateTime.now().add(Duration(days: days));
    await dao.insert(
      promptType: prompt.promptType,
      personId: prompt.personId,
      importantDateId: prompt.importantDateId,
      dismissedUntil: _isoDate(until),
    );
  }

  /// Snoozes a prompt until [snoozeUntil].
  Future<void> snooze(SmartPrompt prompt, DateTime snoozeUntil) async {
    final db = await ref.read(appDatabaseProvider.future);
    final dao = SmartPromptDismissalsDao(db);
    await dao.insert(
      promptType: prompt.promptType,
      personId: prompt.personId,
      importantDateId: prompt.importantDateId,
      dismissedUntil: _isoDate(snoozeUntil),
    );
  }

  static String _isoDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}
