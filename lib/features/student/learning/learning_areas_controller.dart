import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/models/account.dart';
import '../../../data/models/learning.dart';
import '../../../data/repositories/repositories.dart';
import '../load_controller.dart';

enum AreaFilter {
  all('all', 'All'),
  inProgress('in_progress', 'In progress'),
  notStarted('not_started', 'Not started'),
  done('done', 'Done');

  const AreaFilter(this.wire, this.label);
  final String wire;
  final String label;
}

enum AreaSort {
  recent('recent', 'Recent'),
  progress('progress', 'Progress'),
  name('name', 'Name');

  const AreaSort(this.wire, this.label);
  final String wire;
  final String label;
}

/// State of "My Learning Areas": three tabs (areas, saved lessons, quizzes). Filtering, sorting
/// and search are done by the server (`filter`, `sort`, `q`), so the lists are the web's.
/// Saved lessons and quizzes load the first time their tab is opened.
class LearningAreasController extends ChangeNotifier {
  LearningAreasController(
    this._repo, {
    this.searchDelay = const Duration(milliseconds: 400),
  }) {
    areas = LoadController(_fetchAreas);
    saved = LoadController(() => _repo.saved());
    quizzes = LoadController(_repo.quizzes);
  }

  final LearningRepository _repo;
  final Duration searchDelay;

  late final LoadController<LearningAreasData> areas;
  late final LoadController<Paged<SavedLesson>> saved;
  late final LoadController<List<QuizEntry>> quizzes;

  int _tab = 0;
  AreaFilter _filter = AreaFilter.all;
  AreaSort _sort = AreaSort.recent;
  String _query = '';
  Timer? _timer;
  bool _disposed = false;

  int get tab => _tab;
  AreaFilter get filter => _filter;
  AreaSort get sort => _sort;
  String get query => _query;

  Future<LearningAreasData> _fetchAreas() =>
      _repo.areas(filter: _filter.wire, sort: _sort.wire, q: _query);

  Future<void> start() => areas.load();

  void selectTab(int index) {
    if (index == _tab) return;
    _tab = index;
    if (index == 1 && saved.data == null && !saved.loading) saved.load();
    if (index == 2 && quizzes.data == null && !quizzes.loading) quizzes.load();
    notifyListeners();
  }

  void setFilter(AreaFilter value) {
    if (value == _filter) return;
    _filter = value;
    notifyListeners();
    areas.load();
  }

  void setSort(AreaSort value) {
    if (value == _sort) return;
    _sort = value;
    notifyListeners();
    areas.load();
  }

  /// Waits for a pause in typing before asking the server.
  void setQuery(String value) {
    final q = value.trim();
    if (q == _query) return;
    _query = q;
    _timer?.cancel();
    _timer = Timer(searchDelay, () {
      if (!_disposed) areas.load();
    });
    notifyListeners();
  }

  bool get filtering => _filter != AreaFilter.all || _query.isNotEmpty;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    areas.dispose();
    saved.dispose();
    quizzes.dispose();
    super.dispose();
  }
}
