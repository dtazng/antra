import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:antra/database/daos/people_dao.dart';
import 'package:antra/providers/database_provider.dart';
import 'package:antra/services/person_detection_service.dart';

part 'person_detection_providers.g.dart';

/// State for suggestions attached to a single bullet entry.
class PersonDetectionState {
  const PersonDetectionState({
    required this.bulletId,
    required this.suggestions,
  });

  final String bulletId;
  final List<PersonDetectionSuggestion> suggestions;

  PersonDetectionState copyWith({
    List<PersonDetectionSuggestion>? suggestions,
  }) =>
      PersonDetectionState(
        bulletId: bulletId,
        suggestions: suggestions ?? this.suggestions,
      );
}

/// Manages person detection suggestions for a specific [bulletId].
///
/// Suggestions are set after a bullet is saved and auto-clear when the
/// list is empty or when all suggestions are dismissed.
@riverpod
class PersonDetectionNotifier extends _$PersonDetectionNotifier {
  @override
  PersonDetectionState build(String bulletId) {
    return PersonDetectionState(bulletId: bulletId, suggestions: []);
  }

  /// Sets suggestions — called after PersonDetectionService.detect() runs.
  void setSuggestions(List<PersonDetectionSuggestion> suggestions) {
    state = state.copyWith(suggestions: suggestions);
  }

  /// Links [personId] to this bullet and removes that suggestion chip.
  Future<void> acceptSuggestion(String personId) async {
    final db = await ref.read(appDatabaseProvider.future);
    await PeopleDao(db).insertLink(state.bulletId, personId);
    state = state.copyWith(
      suggestions: state.suggestions
          .where((s) => s.personId != personId)
          .toList(),
    );
  }

  /// Clears all suggestions without linking.
  void dismissAll() {
    state = state.copyWith(suggestions: []);
  }
}
