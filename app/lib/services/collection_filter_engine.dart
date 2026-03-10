import 'dart:convert';

import 'package:antra/database/app_database.dart';
import 'package:antra/database/daos/bullets_dao.dart';

/// A single filter rule stored as JSON in `collections.filter_rules`.
///
/// Supported rule types:
///   {"type": "tag",        "value": "work"}
///   {"type": "person",     "personId": "uuid"}
///   {"type": "bullet_type","value": "task"}
///   {"type": "date_range", "from": "2024-01-01", "to": "2024-01-31"}
class FilterRule {
  final String type;
  final Map<String, dynamic> params;

  const FilterRule({required this.type, required this.params});

  factory FilterRule.fromJson(Map<String, dynamic> json) {
    return FilterRule(type: json['type'] as String, params: json);
  }

  Map<String, dynamic> toJson() => params;
}

/// Parses and executes filter rules against the local drift database.
class CollectionFilterEngine {
  final BulletsDao _dao;

  CollectionFilterEngine(AppDatabase db) : _dao = BulletsDao(db);

  /// Parses [filterRulesJson] (a JSON array string) and returns a merged
  /// [Stream<List<Bullet>>] that satisfies ALL provided rules.
  ///
  /// Multiple rules are AND-ed via in-memory intersection (by bullet id).
  Stream<List<Bullet>> applyRules(String filterRulesJson) {
    final List<dynamic> raw = jsonDecode(filterRulesJson) as List<dynamic>;
    if (raw.isEmpty) return Stream.value([]);

    final rules = raw
        .map((r) => FilterRule.fromJson(r as Map<String, dynamic>))
        .toList();

    // Gather one stream per rule.
    final streams = <Stream<List<Bullet>>>[];
    for (final rule in rules) {
      final s = _streamForRule(rule);
      if (s != null) streams.add(s);
    }

    if (streams.isEmpty) return Stream.value([]);
    if (streams.length == 1) return streams.first;

    // Combine multiple streams: emit the intersection of bullet IDs.
    return _combineStreams(streams);
  }

  Stream<List<Bullet>>? _streamForRule(FilterRule rule) {
    switch (rule.type) {
      case 'tag':
        final tag = rule.params['value'] as String?;
        if (tag == null) return null;
        return _dao.filterByTag(tag);

      case 'person':
        final personId = rule.params['personId'] as String?;
        if (personId == null) return null;
        return _dao.filterByPerson(personId);

      case 'bullet_type':
        final bulletType = rule.params['value'] as String?;
        if (bulletType == null) return null;
        return _dao.searchBullets('').map(
              (list) => list.where((b) => b.type == bulletType).toList(),
            );

      case 'date_range':
        final from = rule.params['from'] as String?;
        final to = rule.params['to'] as String?;
        if (from == null || to == null) return null;
        return _dao.filterByDateRange(from, to);

      default:
        return null;
    }
  }

  /// Intersects multiple bullet streams by bullet id.
  Stream<List<Bullet>> _combineStreams(List<Stream<List<Bullet>>> streams) {
    // Use a simple approach: watch the first stream and filter in memory.
    // For production, reactive combination would use rxdart's CombineLatest.
    // Here we implement a basic version using async* and a local cache.
    return streams.first.asyncMap((firstResults) async {
      if (firstResults.isEmpty) return <Bullet>[];
      var ids = firstResults.map((b) => b.id).toSet();
      // For each additional rule we do a one-shot get via the same stream.
      // (Streams beyond the first update lazily — acceptable for V1.)
      for (var i = 1; i < streams.length; i++) {
        final others = await streams[i].first;
        final otherIds = others.map((b) => b.id).toSet();
        ids = ids.intersection(otherIds);
      }
      return firstResults.where((b) => ids.contains(b.id)).toList();
    });
  }
}
