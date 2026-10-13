import '../json.dart';

/// What a lesson is made of (`LessonRenderer::describe`). `render:"webview"` lessons carry no content:
/// the app opens [LessonWebview.path] through the SSO wrapper.
sealed class LessonContent {
  const LessonContent();

  factory LessonContent.fromLesson(Map<String, dynamic> lesson) {
    final type = lesson.str('type');
    if (type == 'webview') {
      return LessonWebview(lesson.obj('webview').str('path'));
    }
    final c = lesson.obj('content');
    return switch (type) {
      'youtube' => LessonYoutube(c.str('video_id')),
      'html' => LessonHtml(html: c.str('html'), hasEmbeddedMedia: c.boolean('has_embedded_media')),
      'video' => LessonVideo(url: c.str('url'), mime: c.strOrNull('mime')),
      'file' => LessonFile(url: c.str('url'), mime: c.str('mime'), name: c.str('name')),
      'empty' => LessonEmpty(c.str('message')),
      _ => throw FormatException('unknown lesson type "$type"'),
    };
  }
}

class LessonYoutube extends LessonContent {
  const LessonYoutube(this.videoId);
  final String videoId;
}

/// Editor text, already purified by the server (no scripts, styles or embeds).
class LessonHtml extends LessonContent {
  const LessonHtml({required this.html, required this.hasEmbeddedMedia});
  final String html;
  final bool hasEmbeddedMedia;
}

/// A self-hosted or direct https video file.
class LessonVideo extends LessonContent {
  const LessonVideo({required this.url, required this.mime});
  final String url;
  final String? mime;
}

/// PDF, Word or PowerPoint. PDFs render in the app; Word and PowerPoint open in the SSO webview.
class LessonFile extends LessonContent {
  const LessonFile({required this.url, required this.mime, required this.name});
  final String url;
  final String mime;
  final String name;
  bool get isPdf => mime == 'application/pdf';
}

class LessonEmpty extends LessonContent {
  const LessonEmpty(this.message);
  final String message;
}

class LessonWebview extends LessonContent {
  const LessonWebview(this.path);
  final String path;
}

class LessonPosition {
  const LessonPosition({required this.n, required this.of, required this.chapter});
  final int n;
  final int of;
  final String chapter;
  factory LessonPosition.fromJson(Map<String, dynamic> j) =>
      LessonPosition(n: j.integer('n'), of: j.integer('of'), chapter: j.str('chapter'));
}

/// The previous or next lesson link.
class LessonNeighbour {
  const LessonNeighbour({required this.id, required this.name, required this.kind, required this.locked, required this.lock});
  final int id;
  final String name;
  final String kind;
  final bool locked;
  final String? lock;
  factory LessonNeighbour.fromJson(Map<String, dynamic> j) => LessonNeighbour(
        id: j.integer('id'),
        name: j.str('name'),
        kind: j.str('kind'),
        locked: j.boolean('locked'),
        lock: j.strOrNull('lock'),
      );
}

class AreaProgress {
  const AreaProgress({required this.done, required this.total, required this.percent});
  final int done;
  final int total;
  final int percent;
  factory AreaProgress.fromJson(Map<String, dynamic> j) =>
      AreaProgress(done: j.integer('done'), total: j.integer('total'), percent: j.integer('percent'));
}

class QaAnswer {
  const QaAnswer({required this.text, required this.who});
  final String text;
  final String who;
  factory QaAnswer.fromJson(Map<String, dynamic> j) => QaAnswer(text: j.str('text'), who: j.str('who'));
}

/// A question on a lesson, as everyone in the area sees it (first names only).
class LessonQa {
  const LessonQa({required this.id, required this.text, required this.who, required this.when, required this.answers});
  final int id;
  final String text;

  /// null for the learner's own question.
  final String? who;
  final String when;
  final List<QaAnswer> answers;
  factory LessonQa.fromJson(Map<String, dynamic> j) => LessonQa(
        id: j.integer('id'),
        text: j.str('text'),
        who: j.strOrNull('who'),
        when: j.str('when'),
        answers: j.list('answers', QaAnswer.fromJson),
      );
}

class LessonQuestions {
  const LessonQuestions({required this.approved, required this.minePending});
  final List<LessonQa> approved;
  final List<LessonQa> minePending;
  factory LessonQuestions.fromJson(Map<String, dynamic> j) => LessonQuestions(
        approved: j.list('approved', LessonQa.fromJson),
        minePending: j.list('mine_pending', LessonQa.fromJson),
      );
}

/// `GET /student/lessons/{lesson}` (E-27).
class LessonData {
  const LessonData({
    required this.id,
    required this.courseId,
    required this.name,
    required this.kind,
    required this.minutes,
    required this.done,
    required this.content,
    required this.courseTitle,
    required this.position,
    required this.prev,
    required this.next,
    required this.nextWaits,
    required this.chapterLast,
    required this.courseLast,
    required this.progress,
    required this.saved,
    required this.canSave,
    required this.note,
    required this.questions,
  });

  final int id;
  final int courseId;
  final String name;
  final String? kind;
  final int? minutes;
  final bool done;
  final LessonContent content;
  final String courseTitle;
  final LessonPosition? position;
  final LessonNeighbour? prev;
  final LessonNeighbour? next;

  /// The next lesson stays closed until this one is marked done (complete-order courses).
  final bool nextWaits;
  final bool chapterLast;
  final bool courseLast;
  final AreaProgress? progress;
  final bool saved;
  final bool canSave;
  final String? note;
  final LessonQuestions questions;

  factory LessonData.fromJson(Map<String, dynamic> j) {
    final l = j.obj('lesson');
    LessonNeighbour? neighbour(String key) =>
        j.objOrNull(key) == null ? null : LessonNeighbour.fromJson(j.obj(key));
    return LessonData(
      id: l.integer('id'),
      courseId: l.integer('course_id'),
      name: l.str('name'),
      kind: l.strOrNull('kind'),
      minutes: l.intOrNull('minutes'),
      done: l.boolean('done'),
      content: LessonContent.fromLesson(l),
      courseTitle: j.obj('course').str('title'),
      position: j.objOrNull('position') == null ? null : LessonPosition.fromJson(j.obj('position')),
      prev: neighbour('prev'),
      next: neighbour('next'),
      nextWaits: j.boolean('next_waits'),
      chapterLast: j.boolean('chapter_last'),
      courseLast: j.boolean('course_last'),
      progress: j.objOrNull('progress') == null ? null : AreaProgress.fromJson(j.obj('progress')),
      saved: j.boolean('saved'),
      canSave: j.boolean('can_save'),
      note: j.strOrNull('note'),
      questions: LessonQuestions.fromJson(j.obj('questions')),
    );
  }
}

/// `POST /student/lessons/{lesson}/complete` (E-28).
class CompleteResult {
  const CompleteResult({
    required this.lessonId,
    required this.courseId,
    required this.newlyCompleted,
    required this.courseFinished,
    required this.coinsAwarded,
    required this.progress,
  });
  final int lessonId;
  final int courseId;
  final bool newlyCompleted;
  final bool courseFinished;
  final int coinsAwarded;
  final AreaProgress? progress;

  factory CompleteResult.fromJson(Map<String, dynamic> j) => CompleteResult(
        lessonId: j.integer('lesson_id'),
        courseId: j.integer('course_id'),
        newlyCompleted: j.boolean('newly_completed'),
        courseFinished: j.boolean('course_finished'),
        coinsAwarded: j.number('coins_awarded').round(),
        progress: j.objOrNull('progress') == null ? null : AreaProgress.fromJson(j.obj('progress')),
      );
}
