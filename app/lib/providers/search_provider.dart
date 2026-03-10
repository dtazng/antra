import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/database/daos/bullets_dao.dart';
import 'package:antra/providers/database_provider.dart';

part 'search_provider.g.dart';

/// Holds the current search filter state.
class SearchFilters {
  final String query;
  final String? tagFilter;
  final String? personFilter;
  final String? dateFrom;
  final String? dateTo;

  const SearchFilters({
    this.query = '',
    this.tagFilter,
    this.personFilter,
    this.dateFrom,
    this.dateTo,
  });

  SearchFilters copyWith({
    String? query,
    Object? tagFilter = _sentinel,
    Object? personFilter = _sentinel,
    Object? dateFrom = _sentinel,
    Object? dateTo = _sentinel,
  }) {
    return SearchFilters(
      query: query ?? this.query,
      tagFilter: tagFilter == _sentinel ? this.tagFilter : tagFilter as String?,
      personFilter:
          personFilter == _sentinel ? this.personFilter : personFilter as String?,
      dateFrom: dateFrom == _sentinel ? this.dateFrom : dateFrom as String?,
      dateTo: dateTo == _sentinel ? this.dateTo : dateTo as String?,
    );
  }

  bool get isEmpty =>
      query.isEmpty &&
      tagFilter == null &&
      personFilter == null &&
      dateFrom == null &&
      dateTo == null;
}

// Sentinel for distinguishing null from "not passed".
const _sentinel = Object();

/// Manages search query, filters, and result stream with 200 ms debounce.
@riverpod
class SearchNotifier extends _$SearchNotifier {
  Timer? _debounce;
  StreamSubscription<List<Bullet>>? _subscription;
  final _resultsController = StreamController<List<Bullet>>.broadcast();

  @override
  SearchFilters build() => const SearchFilters();

  Stream<List<Bullet>> get resultsStream => _resultsController.stream;

  void setQuery(String query) {
    state = state.copyWith(query: query);
    _scheduleRefresh();
  }

  void setTagFilter(String? tag) {
    state = state.copyWith(tagFilter: tag);
    _scheduleRefresh();
  }

  void setPersonFilter(String? personId) {
    state = state.copyWith(personFilter: personId);
    _scheduleRefresh();
  }

  void setDateRange(String? from, String? to) {
    state = state.copyWith(dateFrom: from, dateTo: to);
    _scheduleRefresh();
  }

  void clearFilters() {
    state = const SearchFilters();
    _scheduleRefresh();
  }

  void _scheduleRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), _refresh);
  }

  Future<void> _refresh() async {
    await _subscription?.cancel();
    _subscription = null;

    if (state.isEmpty) {
      _resultsController.add([]);
      return;
    }

    final db = await ref.read(appDatabaseProvider.future);
    final dao = BulletsDao(db);

    Stream<List<Bullet>> stream;

    if (state.dateFrom != null && state.dateTo != null) {
      stream = dao.filterByDateRange(state.dateFrom!, state.dateTo!);
    } else if (state.personFilter != null) {
      stream = dao.filterByPerson(state.personFilter!);
    } else if (state.tagFilter != null) {
      stream = dao.filterByTag(state.tagFilter!);
    } else if (state.query.isNotEmpty) {
      stream = dao.searchBullets(state.query);
    } else {
      _resultsController.add([]);
      return;
    }

    // Apply additional in-memory filters when combining multiple criteria.
    _subscription = stream.listen((bullets) {
      var filtered = bullets;

      if (state.query.isNotEmpty &&
          (state.personFilter != null ||
              state.tagFilter != null ||
              (state.dateFrom != null && state.dateTo != null))) {
        final q = state.query.toLowerCase();
        filtered = filtered
            .where((b) => b.content.toLowerCase().contains(q))
            .toList();
      }

      _resultsController.add(filtered);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _subscription?.cancel();
    _resultsController.close();
  }
}
