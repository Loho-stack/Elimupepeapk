import '../json.dart';
import '../api_call.dart';
import '../models/account.dart';
import '../models/home.dart';
import '../models/learning.dart';
import '../models/lesson.dart';
import '../models/msafara.dart';
import '../models/msafara_checkpoint.dart';
import '../models/msafara_quests.dart';

Paged<T> _paged<T>(Envelope e, T Function(Map<String, dynamic>) parse) {
  final meta = e.meta ?? const <String, dynamic>{};
  int n(String k, int fallback) => meta[k] is int ? meta[k] as int : fallback;
  final items = e.rows.map(parse).toList();
  return Paged(
    items: items,
    currentPage: n('current_page', 1),
    lastPage: n('last_page', 1),
    total: n('total', items.length),
  );
}

/// E-23.
class HomeRepository {
  HomeRepository(this._api);
  final ApiCall _api;

  Future<HomeData> home() async {
    final e = await _api.get('/student/home');
    return parsed(() => HomeData.fromJson(e.object));
  }
}

/// E-24, E-25, E-26, E-87.
class LearningRepository {
  LearningRepository(this._api);
  final ApiCall _api;

  /// [filter]: all, in_progress, not_started, done. [sort]: recent, progress, name. [q]: up to 80 characters.
  Future<LearningAreasData> areas({String filter = 'all', String sort = 'recent', String q = ''}) async {
    final e = await _api.get('/student/learning-areas', query: {
      if (filter != 'all') 'filter': filter,
      if (sort != 'recent') 'sort': sort,
      if (q.trim().isNotEmpty) 'q': q.trim(),
    });
    return parsed(() => LearningAreasData.fromJson(e.object));
  }

  Future<AreaOutline> outline(int courseId) async {
    final e = await _api.get('/student/learning-areas/$courseId');
    return parsed(() => AreaOutline.fromJson(e.object));
  }

  Future<Paged<SavedLesson>> saved({int page = 1}) async {
    final e = await _api.get('/student/saved-lessons', query: {'page': page});
    return parsed(() => _paged(e, SavedLesson.fromJson));
  }

  Future<List<QuizEntry>> quizzes() async {
    final e = await _api.get('/student/learning-areas/quizzes');
    return parsed(() => e.rows.map(QuizEntry.fromJson).toList());
  }
}

/// E-27, E-28, E-29, E-30, E-36.
class LessonRepository {
  LessonRepository(this._api);
  final ApiCall _api;

  Future<LessonData> lesson(int lessonId) async {
    final e = await _api.get('/student/lessons/$lessonId');
    return parsed(() => LessonData.fromJson(e.object));
  }

  /// Safe to call again with the same [key]: the server runs it once and replays the answer.
  Future<CompleteResult> complete({
    required int lessonId,
    required int courseId,
    required String key,
  }) async {
    final e = await _api.post('/student/lessons/$lessonId/complete',
        body: {'course_id': courseId}, idempotencyKey: key);
    return parsed(() => CompleteResult.fromJson(e.object));
  }

  /// An empty [body] removes the note. Returns true when the note is now empty.
  Future<bool> saveNote(int lessonId, String body) async {
    final e = await _api.put('/student/lessons/$lessonId/note', body: {'body': body});
    return parsed(() => e.object.boolean('empty'));
  }

  /// A set, not a toggle: repeating it changes nothing. Returns the state after the call.
  Future<bool> setSaved(int lessonId, bool saved) async {
    final e = await _api.put('/student/lessons/$lessonId/save', body: {'saved': saved});
    return parsed(() => e.object.boolean('saved'));
  }

  Future<LessonQuestions> questions(int lessonId) async {
    final e = await _api.get('/student/lessons/$lessonId/questions');
    return parsed(() => LessonQuestions.fromJson(e.object));
  }
}

/// E-31..E-35.
class QuestionsRepository {
  QuestionsRepository(this._api);
  final ApiCall _api;

  Future<Paged<MyQuestion>> list({int page = 1}) async {
    final e = await _api.get('/student/questions', query: {'page': page});
    return parsed(() => _paged(e, MyQuestion.fromJson));
  }

  Future<MyQuestion> detail(int id) async {
    final e = await _api.get('/student/questions/$id');
    return parsed(() => MyQuestion.fromJson(e.object));
  }

  /// Returns the new question id. It waits for review.
  Future<int> ask({
    required int courseId,
    required int lessonId,
    required String text,
    int? parentId,
    required String key,
  }) async {
    final e = await _api.post('/student/questions',
        body: {
          'course_id': courseId,
          'lesson_id': lessonId,
          'text': text,
          if (parentId != null) 'parent_id': parentId,
        },
        idempotencyKey: key);
    return parsed(() => e.object.integer('id'));
  }

  /// Editing an approved question sends it back to review. A 409 `question_answered`
  /// (a [ConflictError]) means it has a reply and cannot be edited.
  Future<void> update(int id, String text) async {
    await _api.put('/student/questions/$id', body: {'text': text});
  }

  Future<void> delete(int id) async {
    await _api.delete('/student/questions/$id');
  }
}

/// E-19, E-20, E-21, E-84.
class NotificationsRepository {
  NotificationsRepository(this._api);
  final ApiCall _api;

  Future<NotificationPage> list({int page = 1, bool unreadOnly = false}) async {
    final e = await _api.get('/notifications', query: {'page': page, if (unreadOnly) 'unread': 1});
    return parsed(() {
      final paged = _paged(e, AppNotification.fromJson);
      return NotificationPage(paged, e.meta?['unread_count'] is int ? e.meta!['unread_count'] as int : 0);
    });
  }

  Future<int> unreadCount() async {
    final e = await _api.get('/notifications/unread-count');
    return parsed(() => e.object.integer('unread_count'));
  }

  /// Returns the unread count after the change.
  Future<int> markRead(String id) async {
    final e = await _api.post('/notifications/$id/read');
    return parsed(() => e.object.integer('unread_count'));
  }

  Future<int> markAllRead() async {
    final e = await _api.post('/notifications/read-all');
    return parsed(() => e.object.integer('unread_count'));
  }
}

class NotificationPage {
  const NotificationPage(this.page, this.unreadCount);
  final Paged<AppNotification> page;
  final int unreadCount;
}

/// E-07, E-08, E-09, E-11.
class AccountRepository {
  AccountRepository(this._api);
  final ApiCall _api;

  Future<Profile> me() async {
    final e = await _api.get('/me');
    return parsed(() => Profile.fromJson(e.object));
  }

  /// Needs the account password. After a successful call every token is revoked.
  Future<void> deleteAccount({required String password, String? reason}) async {
    await _api.delete('/me', body: {'password': password, if (reason != null) 'reason': reason});
  }

  Future<void> logout({String? deviceToken}) async {
    await _api.post('/auth/logout', body: {if (deviceToken != null) 'device_token': deviceToken});
  }

  Future<void> logoutAll() async {
    await _api.post('/auth/logout-all');
  }
}

/// Elimu Quest (Msafara), `/msafara/*`. Every write takes the caller's key, so a retry of the
/// same action sends the same key.
class MsafaraRepository {
  MsafaraRepository(this._api);
  final ApiCall _api;

  /// Always available; the app calls it on launch and after every terms or profile change.
  Future<MsafaraState> state() async {
    final e = await _api.get('/msafara/state');
    return parsed(() => MsafaraState.fromJson(e.object));
  }

  /// [lang] is `en` or `sw`.
  Future<Terms> terms({String lang = 'en'}) async {
    final e = await _api.get('/msafara/terms', query: {'lang': lang});
    return parsed(() => Terms.fromJson(e.object));
  }

  /// Both boxes must be ticked; the server answers 422 otherwise.
  Future<TermsResult> acceptTerms({required String key}) async {
    final e = await _api.post('/msafara/terms',
        body: {'accept_terms': true, 'parent_agreed': true}, idempotencyKey: key);
    return parsed(() => TermsResult.fromJson(e.object));
  }

  Future<ProfileForm> profile() async {
    final e = await _api.get('/msafara/profile');
    return parsed(() => ProfileForm.fromJson(e.object));
  }

  /// Send only the fields that are missing.
  Future<ProfileResult> saveProfile({String? grade, String? county, required String key}) async {
    final e = await _api.post('/msafara/profile',
        body: {if (grade != null) 'grade': grade, if (county != null) 'county': county}, idempotencyKey: key);
    return parsed(() => ProfileResult.fromJson(e.object));
  }

  Future<QuestHome> home() async {
    final e = await _api.get('/msafara/home');
    return parsed(() => QuestHome.fromJson(e.object));
  }

  Future<QuestList> quests() async {
    final e = await _api.get('/msafara/quests');
    return parsed(() => QuestList.fromJson(e.object));
  }

  /// [no] is 1 to 5, or 6 for the bonus.
  Future<QuestDetail> quest(int no) async {
    final e = await _api.get('/msafara/quests/$no');
    return parsed(() => QuestDetail.fromJson(e.object));
  }

  /// A reading ping. The server measures the time; a fresh [key] goes with every ping. [page] is
  /// 1-based and only for book quests. No 429 retry: a ping that is refused is skipped.
  Future<QuestLock> ping(int no, {int? page, required String key}) async {
    final e = await _api.post('/msafara/quests/$no/ping',
        body: {if (page != null) 'page': page}, idempotencyKey: key, retry: false);
    return parsed(() => QuestLock.fromJson(e.object));
  }

  /// A 409 `quest_locked` (a [QuestLockedError]) means the reading is not done.
  Future<QuestionSet> questions(int no) async {
    final e = await _api.get('/msafara/quests/$no/questions');
    return parsed(() => QuestionSet.fromJson(e.object));
  }

  /// [choice] is the option number from 1 (mcq, true_false); [text] is one word (fill_blank).
  Future<AnswerResult> answer(int no,
      {required int questionId, int? choice, String? text, required String key}) async {
    final e = await _api.post('/msafara/quests/$no/answer',
        body: {'question_id': questionId, if (choice != null) 'choice': choice, if (text != null) 'text': text},
        idempotencyKey: key);
    return parsed(() => AnswerResult.fromJson(e.object));
  }

  /// Today's checkpoint, or the one of [day] (0 is Launch Day). 404: none for this learner's band.
  Future<Checkpoint> checkpoint({int? day}) async {
    final e = await _api.get(day == null ? '/msafara/checkpoint' : '/msafara/checkpoint/$day');
    return parsed(() => Checkpoint.fromJson(e.object));
  }

  ///409 `checkpoint_locked`, `checkpoint_closed` and `already_answered` are [ConflictError]s.
  Future<CheckpointResult> answerCheckpoint(int day, {required String option, required String key}) async {
    final e = await _api.post('/msafara/checkpoint/$day', body: {'option': option}, idempotencyKey: key);
    return parsed(() => CheckpointResult.fromJson(e.object));
  }
}
