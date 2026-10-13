import '../json.dart';

/// `state` of a learning area, as `LearningAreas::shape` computes it.
enum AreaState {
  inProgress('in_progress'),
  notStarted('not_started'),
  done('done'),
  comingSoon('coming_soon');

  const AreaState(this.wire);
  final String wire;

  static AreaState parse(String v) => AreaState.values.firstWhere(
        (s) => s.wire == v,
        orElse: () => throw FormatException('unknown area state "$v"'),
      );
}

/// One learning area (course) with the learner's progress. `E-24`, the hero, and the `area` of `E-25`.
class LearningArea {
  const LearningArea({
    required this.id,
    required this.title,
    required this.cover,
    required this.level,
    required this.total,
    required this.done,
    required this.percent,
    required this.state,
    required this.videos,
    required this.slides,
    required this.notes,
    required this.minutesLeft,
    required this.nextLessonId,
    required this.nextLesson,
    required this.activity,
  });

  final int id;
  final String title;
  final String? cover;
  final String level;
  final int total;
  final int done;
  final int percent;
  final AreaState state;
  final int videos;
  final int slides;
  final int notes;
  final int? minutesLeft;
  final int? nextLessonId;
  final String? nextLesson;
  final DateTime? activity;

  factory LearningArea.fromJson(Map<String, dynamic> j) {
    // `mix` is an object with only the kinds that exist; an empty one may arrive as [].
    final raw = j['mix'];
    final mix = raw is Map ? Map<String, dynamic>.from(raw) : const <String, dynamic>{};
    int kind(String k) => mix[k] is int ? mix[k] as int : 0;
    return LearningArea(
      id: j.integer('id'),
      title: j.str('title'),
      cover: j.strOrNull('cover'),
      level: j.strOrNull('level') ?? '',
      total: j.integer('total'),
      done: j.integer('done'),
      percent: j.integer('percent'),
      state: AreaState.parse(j.str('state')),
      videos: kind('videos'),
      slides: kind('slides'),
      notes: kind('notes'),
      minutesLeft: j.intOrNull('minutes_left'),
      nextLessonId: j.intOrNull('next_lesson_id'),
      nextLesson: j.strOrNull('next_lesson'),
      activity: j.timeOrNull('activity'),
    );
  }
}

class AreaChips {
  const AreaChips({required this.inProgress, required this.lessonsWeek, required this.booksReading});
  final int inProgress;
  final int lessonsWeek;
  final int booksReading;

  factory AreaChips.fromJson(Map<String, dynamic> j) => AreaChips(
        inProgress: j.integer('in_progress'),
        lessonsWeek: j.integer('lessons_week'),
        booksReading: j.integer('books_reading'),
      );
}

/// `GET /student/learning-areas` (E-24).
class LearningAreasData {
  const LearningAreasData({required this.hero, required this.chips, required this.areas});
  final LearningArea? hero;
  final AreaChips chips;
  final List<LearningArea> areas;

  factory LearningAreasData.fromJson(Map<String, dynamic> j) => LearningAreasData(
        hero: j.objOrNull('hero') == null ? null : LearningArea.fromJson(j.obj('hero')),
        chips: AreaChips.fromJson(j.obj('chips')),
        areas: j.list('areas', LearningArea.fromJson),
      );
}

/// A row of `GET /student/saved-lessons` (E-26).
class SavedLesson {
  const SavedLesson({
    required this.lessonId,
    required this.courseId,
    required this.title,
    required this.area,
    required this.cover,
    required this.savedAt,
  });
  final int lessonId;
  final int courseId;
  final String title;
  final String? area;
  final String? cover;
  final DateTime? savedAt;

  factory SavedLesson.fromJson(Map<String, dynamic> j) => SavedLesson(
        lessonId: j.integer('lesson_id'),
        courseId: j.integer('course_id'),
        title: j.str('title'),
        area: j.strOrNull('area'),
        cover: j.strOrNull('cover'),
        savedAt: j.timeOrNull('saved_at'),
      );
}

/// A row of `GET /student/learning-areas/quizzes` (E-87). Quizzes are web-only.
class QuizEntry {
  const QuizEntry({
    required this.id,
    required this.title,
    required this.cover,
    required this.state,
    required this.attempts,
    required this.best,
    required this.total,
    required this.webviewPath,
  });
  final int id;
  final String title;
  final String? cover;

  /// `not_started`, `attempted` or `passed`.
  final String state;
  final int attempts;
  final double? best;
  final double? total;

  /// Opens in the SSO webview; null when the server could not build a path.
  final String? webviewPath;

  factory QuizEntry.fromJson(Map<String, dynamic> j) => QuizEntry(
        id: j.integer('id'),
        title: j.str('title'),
        cover: j.strOrNull('cover'),
        state: j.str('state'),
        attempts: j.integer('attempts'),
        best: j.numberOrNull('best'),
        total: j.numberOrNull('total'),
        webviewPath: j.obj('webview').strOrNull('path'),
      );
}

/// One lesson row of an area outline (E-25).
class OutlineLesson {
  const OutlineLesson({
    required this.id,
    required this.name,
    required this.kind,
    required this.icon,
    required this.minutes,
    required this.done,
    required this.locked,
    required this.lock,
    required this.webview,
  });
  final int id;
  final String name;
  final String kind;
  final String icon;
  final int? minutes;
  final bool done;
  final bool locked;

  /// `enrol`, `drip` or `order` when [locked].
  final String? lock;

  /// `render` is `webview`: the lesson opens in the SSO webview, not natively.
  final bool webview;

  factory OutlineLesson.fromJson(Map<String, dynamic> j) => OutlineLesson(
        id: j.integer('id'),
        name: j.str('name'),
        kind: j.str('kind'),
        icon: j.str('icon'),
        minutes: j.intOrNull('minutes'),
        done: j.boolean('done'),
        locked: j.boolean('locked'),
        lock: j.strOrNull('lock'),
        webview: j.str('render') == 'webview',
      );
}

class OutlineChapter {
  const OutlineChapter({required this.id, required this.title, required this.lessons});
  final int id;
  final String title;
  final List<OutlineLesson> lessons;

  factory OutlineChapter.fromJson(Map<String, dynamic> j) => OutlineChapter(
        id: j.integer('id'),
        title: j.str('title'),
        lessons: j.list('lessons', OutlineLesson.fromJson),
      );
}

/// `GET /student/learning-areas/{course}` (E-25).
class AreaOutline {
  const AreaOutline({
    required this.area,
    required this.chapters,
    required this.bookmarks,
    required this.questions,
  });
  final LearningArea area;
  final List<OutlineChapter> chapters;
  final int bookmarks;
  final int questions;

  factory AreaOutline.fromJson(Map<String, dynamic> j) => AreaOutline(
        area: LearningArea.fromJson(j.obj('area')),
        chapters: j.list('chapters', OutlineChapter.fromJson),
        bookmarks: j.integer('bookmarks'),
        questions: j.integer('questions'),
      );
}
