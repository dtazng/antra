import 'package:antra/database/app_database.dart';
import 'package:antra/database/daos/people_dao.dart';

/// A detection match returned by [PersonDetectionService.detect].
class PersonDetectionSuggestion {
  const PersonDetectionSuggestion({
    required this.personId,
    required this.personName,
    required this.matchedText,
    required this.confidence,
  });

  final String personId;
  final String personName;
  final String matchedText;

  /// 1.0 = exact full name, 0.8 = unique first name, 0.6 = prefix match.
  final double confidence;
}

/// Detects person names in free-form log text using local DB matching.
///
/// Algorithm:
/// 1. Tokenize log text into words and 2–3-word phrases.
/// 2. Case-insensitive match against non-deleted persons.
/// 3. Priority: exact full name > unique first name > prefix match.
/// 4. Returns up to 5 [PersonDetectionSuggestion]s, deduped by personId.
class PersonDetectionService {
  PersonDetectionService({required AppDatabase db})
      : _dao = PeopleDao(db);

  final PeopleDao _dao;

  static const _stopWords = {
    'a', 'an', 'the', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for',
    'of', 'with', 'by', 'from', 'that', 'this', 'it', 'its', 'is', 'are',
    'was', 'were', 'be', 'been', 'has', 'had', 'have', 'do', 'did', 'does',
    'i', 'me', 'my', 'we', 'our', 'you', 'your', 'he', 'she', 'him', 'her',
    'they', 'them', 'their', 'what', 'which', 'who', 'whom',
  };

  /// Detects person names in [logText] and returns up to 5 matches.
  Future<List<PersonDetectionSuggestion>> detect(String logText) async {
    if (logText.trim().isEmpty) return [];

    final allPersons = await _dao.getAllActivePersons();
    if (allPersons.isEmpty) return [];

    final words = _tokenize(logText);
    final phrases = _buildPhrases(words);

    final suggestions = <PersonDetectionSuggestion>[];
    final seenIds = <String>{};

    for (final person in allPersons) {
      if (seenIds.contains(person.id)) continue;

      final nameLower = person.name.toLowerCase();
      final nameParts = nameLower.split(RegExp(r'\s+'));

      // Exact full name match
      if (phrases.contains(nameLower)) {
        suggestions.add(PersonDetectionSuggestion(
          personId: person.id,
          personName: person.name,
          matchedText: person.name,
          confidence: 1.0,
        ));
        seenIds.add(person.id);
        continue;
      }

      // Unique first name match (only if no other person shares this first name)
      if (nameParts.isNotEmpty) {
        final firstName = nameParts.first;
        if (!_stopWords.contains(firstName) && words.contains(firstName)) {
          final sharesFirstName = allPersons
              .where((p) => p.id != person.id)
              .any((p) => p.name.toLowerCase().startsWith('$firstName '));
          if (!sharesFirstName) {
            suggestions.add(PersonDetectionSuggestion(
              personId: person.id,
              personName: person.name,
              matchedText: person.name.split(' ').first,
              confidence: 0.8,
            ));
            seenIds.add(person.id);
            continue;
          }
        }
      }

      // Prefix match (2+ word phrase that starts the person's name)
      for (final phrase in phrases) {
        if (phrase.length >= 3 &&
            nameLower.startsWith(phrase) &&
            !_stopWords.contains(phrase)) {
          suggestions.add(PersonDetectionSuggestion(
            personId: person.id,
            personName: person.name,
            matchedText: phrase,
            confidence: 0.6,
          ));
          seenIds.add(person.id);
          break;
        }
      }
    }

    // Sort by confidence desc, then return up to 5
    suggestions.sort((a, b) => b.confidence.compareTo(a.confidence));
    return suggestions.take(5).toList();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r"[^\w\s']"), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 2 && !_stopWords.contains(w))
        .toList();
  }

  /// Builds 1-word, 2-word, and 3-word phrases from [words].
  static Set<String> _buildPhrases(List<String> words) {
    final phrases = <String>{};
    for (int i = 0; i < words.length; i++) {
      phrases.add(words[i]);
      if (i + 1 < words.length) {
        phrases.add('${words[i]} ${words[i + 1]}');
      }
      if (i + 2 < words.length) {
        phrases.add('${words[i]} ${words[i + 1]} ${words[i + 2]}');
      }
    }
    return phrases;
  }
}
