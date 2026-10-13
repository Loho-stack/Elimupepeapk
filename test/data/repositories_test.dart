import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:elimupepe/core/network/api_exception.dart';
import 'package:elimupepe/data/api_call.dart';
import 'package:elimupepe/data/api_error.dart';
import 'package:elimupepe/data/idempotency.dart';
import 'package:elimupepe/data/models/learning.dart';
import 'package:elimupepe/data/models/lesson.dart';
import 'package:elimupepe/data/repositories/app_repositories.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

/// Fixtures in test/fixtures/app_api are written from the App API payload code and the 2B test assertions.
String fixture(String name) => File('test/fixtures/app_api/$name.json').readAsStringSync();

ResponseBody fixtureBody(String name, {int status = 200, Map<String, List<String>>? headers}) =>
    ResponseBody.fromString(fixture(name), status, headers: {
      Headers.contentTypeHeader: ['application/json'],
      ...?headers,
    });

({AppRepositories repos, ScriptedAdapter adapter}) setup(Responder handler) {
  final adapter = ScriptedAdapter(handler);
  final dio = Dio(BaseOptions(baseUrl: 'https://staging.loholearning.co.ke/api/app/v1'))
    ..httpClientAdapter = adapter;
  return (repos: AppRepositories(ApiCall(dio)), adapter: adapter);
}

Future<AppApiError> failure(Future<void> Function() call) async {
  try {
    await call();
  } on AppApiError catch (e) {
    return e;
  }
  fail('expected an AppApiError');
}

void main() {
  group('models from the real response shapes', () {
    test('home', () async {
      final t = setup((o) => fixtureBody('home'));
      final h = await t.repos.home.home();
      expect(t.adapter.seen.single.path, '/student/home');
      expect(h.streak, 4);
      expect(h.widgets.continueLearning!.lesson, 'Adding fractions');
      expect(h.widgets.classes.single.startsAt.toUtc().hour, 7); // 10:00 +03:00
      expect(h.widgets.dueAssignments.single.urgent, isTrue);
      expect(h.widgets.coins!.balance, 120.5);
      expect(h.widgets.week!.totalMinutes, 55);
      expect(h.widgets.msafara!.kmToday, 18.5);
      expect(h.school, isNull);
      expect(h.subscription.active, isTrue);
    });

    test('home with nothing to show', () async {
      final t = setup((o) => fixtureBody('home_empty'));
      final h = await t.repos.home.home();
      expect(h.widgets.continueLearning, isNull);
      expect(h.widgets.coins, isNull);
      expect(h.widgets.week, isNull);
      expect(h.widgets.reading, isEmpty);
      expect(h.subscription.coveredBy, 'school');
    });

    test('learning areas, filter and sort go in the query only when not default', () async {
      final t = setup((o) => fixtureBody('learning_areas'));
      final d = await t.repos.learning.areas(filter: 'done', sort: 'name', q: ' sci ');
      final q = t.adapter.seen.single.queryParameters;
      expect(q, {'filter': 'done', 'sort': 'name', 'q': 'sci'});
      expect(d.areas.map((a) => a.state), [
        AreaState.inProgress,
        AreaState.notStarted,
        AreaState.done,
        AreaState.comingSoon,
      ]);
      expect(d.hero!.id, 41);
      expect(d.areas.first.videos, 1);
      expect(d.areas.first.notes, 2);
      expect(d.areas[2].videos, 0);
      expect(d.chips.lessonsWeek, 3);

      await t.repos.learning.areas();
      expect(t.adapter.seen.last.queryParameters, isEmpty);
    });

    test('saved lessons, quizzes and the area outline', () async {
      final t = setup((o) => switch (o.path) {
            '/student/saved-lessons' => fixtureBody('saved_lessons'),
            '/student/learning-areas/quizzes' => fixtureBody('quizzes'),
            _ => fixtureBody('area_outline'),
          });
      final saved = await t.repos.learning.saved();
      expect(saved.items.single.lessonId, 512);
      expect(saved.hasMore, isFalse);

      final quizzes = await t.repos.learning.quizzes();
      expect(quizzes.first.best, 8.0);
      expect(quizzes.first.webviewPath, '/quiz-start/60/9/fractions-quiz');
      expect(quizzes.last.webviewPath, isNull);

      final outline = await t.repos.learning.outline(41);
      expect(t.adapter.seen.last.path, '/student/learning-areas/41');
      final lessons = outline.chapters.single.lessons;
      expect(lessons.map((l) => l.done), [true, false, false]);
      expect(lessons.last.locked, isTrue);
      expect(lessons.last.lock, 'order');
      expect(lessons.last.webview, isTrue);
      expect(outline.bookmarks, 1);
    });

    test('lessons: youtube, html with questions, webview', () async {
      final t = setup((o) => fixtureBody(switch (o.path) {
            '/student/lessons/511' => 'lesson_youtube',
            '/student/lessons/512' => 'lesson_html',
            _ => 'lesson_webview',
          }));
      final yt = await t.repos.lessons.lesson(511);
      expect((yt.content as LessonYoutube).videoId, 'dQw4w9WgXcQ');
      expect(yt.prev, isNull);
      expect(yt.next!.id, 512);
      expect(yt.done, isTrue);

      final html = await t.repos.lessons.lesson(512);
      expect((html.content as LessonHtml).html, contains('<b>fractions</b>'));
      expect(html.nextWaits, isTrue);
      expect(html.next!.lock, 'order');
      expect(html.note, 'remember the common denominator');
      expect(html.questions.approved.single.who, 'Wanjiru');
      expect(html.questions.approved.single.answers.single.who, 'Grace');
      expect(html.questions.minePending.single.who, isNull);
      expect(html.position!.of, 3);

      final web = await t.repos.lessons.lesson(513);
      expect((web.content as LessonWebview).path, '/fullscreen-view/41/513');
      expect(web.courseLast, isTrue);
    });

    test('questions, notifications and profile', () async {
      final t = setup((o) => fixtureBody(switch (o.path) {
            '/student/questions' => 'questions',
            '/student/questions/70' => 'question_detail',
            '/notifications' => 'notifications',
            _ => 'me_student',
          }));
      final list = await t.repos.questions.list();
      expect(list.items.map((q) => q.approved), [false, true]);
      expect(list.total, 2);
      final q = await t.repos.questions.detail(70);
      expect(q.answers.single.who, 'Grace');
      expect(q.answered, isTrue);

      final n = await t.repos.notifications.list();
      expect(n.unreadCount, 1);
      expect(n.page.items.single.unread, isTrue);
      expect(n.page.items.single.id, '0a1b2c');

      final me = await t.repos.account.me();
      expect(me.role, 'student');
      expect(me.grade, 'Grade 5');
    });

    test('a decimal that arrives as a string is still a number', () async {
      final t = setup((o) => ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'data': [
              {'id': 60, 'title': 'Q', 'cover': null, 'state': 'attempted', 'attempts': 1, 'best': '8.50', 'total': '10.00', 'webview': {'required': true, 'path': null}}
            ]
          }),
          200,
          headers: {Headers.contentTypeHeader: ['application/json']}));
      final q = (await t.repos.learning.quizzes()).single;
      expect(q.best, 8.5);
      expect(q.total, 10.0);
    });

    test('a missing required field is a ParseError, not a crash', () async {
      final t = setup((o) => ResponseBody.fromString(
          jsonEncode({'success': true, 'data': {'server_time': '2026-10-14T09:30:00+03:00'}}), 200,
          headers: {Headers.contentTypeHeader: ['application/json']}));
      expect(await failure(() => t.repos.home.home()), isA<ParseError>());
    });

    test('an unknown area state or lesson type is a ParseError', () async {
      final t = setup((o) => ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'data': {
              'hero': null,
              'chips': {'in_progress': 0, 'lessons_week': 0, 'books_reading': 0},
              'areas': [
                {'id': 1, 'title': 'x', 'cover': null, 'level': '', 'total': 1, 'done': 0, 'percent': 0, 'state': 'archived', 'mix': {}, 'minutes_left': null, 'next_lesson_id': null, 'next_lesson': null, 'activity': null}
              ]
            }
          }),
          200,
          headers: {Headers.contentTypeHeader: ['application/json']}));
      expect(await failure(() => t.repos.learning.areas()), isA<ParseError>());
    });

    test('a body that is not the envelope is a ParseError', () async {
      final t = setup((o) => ResponseBody.fromString('<html>oops</html>', 200));
      expect(await failure(() => t.repos.home.home()), isA<ParseError>());
    });
  });

  group('errors', () {
    Future<AppApiError> failWith(String fixtureName, int status, [Future<void> Function(AppRepositories)? call]) async {
      final t = setup((o) => fixtureBody(fixtureName, status: status));
      return failure(() => (call ?? (r) => r.lessons.lesson(1))(t.repos));
    }

    test('subscription_required', () async {
      expect(await failWith('error_subscription', 403), isA<SubscriptionRequiredError>());
    });

    test('lesson_locked keeps the lock reason and has a friendly message', () async {
      final e = await failWith('error_locked', 403) as LessonLockedError;
      expect(e.lock, 'order');
      expect(e.message, isNot(contains('previous lesson')));
      expect(e.message, 'Finish the lesson before it first.');
    });

    test('access_expired, forbidden, not found, server, unknown', () async {
      Future<AppApiError> raw(int status, Object body) async {
        final t = setup((o) => ResponseBody.fromString(jsonEncode(body), status,
            headers: {Headers.contentTypeHeader: ['application/json']}));
        return failure(() => t.repos.home.home());
      }

      expect(await raw(403, {'success': false, 'message': 'x', 'error_code': 'access_expired'}), isA<AccessExpiredError>());
      expect(await raw(403, {'success': false, 'message': 'Forbidden.'}), isA<ForbiddenError>());
      expect(await raw(404, {'success': false, 'message': 'Not found.'}), isA<NotFoundError>());
      expect(await raw(500, {'success': false, 'message': 'Boom: SQLSTATE[42S02] table users'}), isA<ServerError>());
      expect(await raw(418, {'success': false}), isA<UnknownError>());
    });

    test('server text never reaches the friendly message', () async {
      final e = await failWith('error_validation', 422);
      expect(e, isA<ValidationError>());
      expect((e as ValidationError).fields['course_id'], ['You are not enrolled in this course.']);
      expect(e.message, isNot(contains('enrolled')));
      expect(e.has('course_id'), isTrue);
    });

    test('409 question_answered is a ConflictError, 409 without a code is in flight', () async {
      final t = setup((o) => fixtureBody('error_answered', status: 409));
      final e = await failure(() => t.repos.questions.update(70, 'new text'));
      expect(e, isA<ConflictError>());
      expect((e as ConflictError).questionAnswered, isTrue);

      final inFlight = setup((o) => ResponseBody.fromString(
          jsonEncode({'success': false, 'message': 'Request in progress. Retry in a moment.'}), 409,
          headers: {Headers.contentTypeHeader: ['application/json']}));
      final f = await failure(() => inFlight.repos.lessons.complete(lessonId: 1, courseId: 1, key: 'k'));
      expect(f, isA<InFlightError>());
      expect(f.retryable, isTrue);
    });

    test('422 about the Idempotency-Key is a bug of the app, not a validation error', () async {
      final t = setup((o) => ResponseBody.fromString(
          jsonEncode({'success': false, 'message': 'x', 'errors': {'Idempotency-Key': ['required']}}), 422,
          headers: {Headers.contentTypeHeader: ['application/json']}));
      expect(await failure(() => t.repos.lessons.complete(lessonId: 1, courseId: 1, key: 'k')), isA<IdempotencyKeyError>());
    });

    test('429 carries Retry-After', () async {
      final t = setup((o) => ResponseBody.fromString(jsonEncode({'success': false}), 429, headers: {
            Headers.contentTypeHeader: ['application/json'],
            'retry-after': ['12'],
          }));
      final e = await failure(() => t.repos.home.home());
      expect((e as RateLimitedError).retryAfter, const Duration(seconds: 12));
    });

    test('the offline and expired-session exceptions of the interceptors map to typed errors', () async {
      final dio = Dio();
      dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
        h.reject(DioException(requestOptions: o, error: const OfflineException(), type: DioExceptionType.connectionError));
      }));
      expect(await failure(() => ApiCall(dio).get('/x')), isA<OfflineError>());

      final dio2 = Dio();
      dio2.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
        h.reject(DioException(requestOptions: o, error: const SessionExpiredException()));
      }));
      expect(await failure(() => ApiCall(dio2).get('/x')), isA<SessionExpiredError>());
    });

    test('a timeout is treated as offline', () async {
      final dio = Dio();
      dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
        h.reject(DioException(requestOptions: o, type: DioExceptionType.receiveTimeout));
      }));
      expect(await failure(() => ApiCall(dio).get('/x')), isA<OfflineError>());
    });
  });

  group('Idempotency-Key', () {
    test('keys are UUID v4 and different each time', () {
      final a = newIdempotencyKey();
      final b = newIdempotencyKey();
      final uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
      expect(a, matches(uuid));
      expect(b, matches(uuid));
      expect(a, isNot(b));
    });

    test('one PendingAction sends the same key on the first try and on the retry', () async {
      var calls = 0;
      final t = setup((o) {
        calls++;
        return calls == 1
            ? ResponseBody.fromString('', 503)
            : fixtureBody('complete', headers: {'idempotent-replayed': ['true']});
      });
      final action = PendingAction();

      final first = await failure(() => t.repos.lessons.complete(lessonId: 512, courseId: 41, key: action.key));
      expect(first, isA<ServerError>());
      final result = await t.repos.lessons.complete(lessonId: 512, courseId: 41, key: action.key);

      final keys = t.adapter.seen.map((o) => o.headers['Idempotency-Key']).toList();
      expect(keys, [action.key, action.key]);
      expect(t.adapter.seen.first.method, 'POST');
      expect(t.adapter.seen.first.path, '/student/lessons/512/complete');
      expect(t.adapter.seen.first.data, {'course_id': 41});
      expect(t.adapter.seen.first.extra['retryable'], isTrue);
      expect(result.newlyCompleted, isTrue);
      expect(result.coinsAwarded, 5);
      expect(result.progress!.percent, 67);
    });

    test('a replayed answer is flagged', () async {
      final t = setup((o) => fixtureBody('complete', headers: {'idempotent-replayed': ['true']}));
      final e = await ApiCall(Dio(BaseOptions(baseUrl: 'https://x.test'))..httpClientAdapter = t.adapter).post('/a', idempotencyKey: 'k');
      expect(e.replayed, isTrue);
    });

    test('asking a question sends the key and the parent only when it is a reply', () async {
      final t = setup((o) => ResponseBody.fromString(
          jsonEncode({'success': true, 'data': {'id': 73, 'status': 'pending'}}), 201,
          headers: {Headers.contentTypeHeader: ['application/json']}));
      final id = await t.repos.questions.ask(courseId: 41, lessonId: 512, text: 'Why?', key: 'k1');
      expect(id, 73);
      expect(t.adapter.seen.single.data, {'course_id': 41, 'lesson_id': 512, 'text': 'Why?'});
      await t.repos.questions.ask(courseId: 41, lessonId: 512, text: 'Thanks', parentId: 70, key: 'k2');
      expect(t.adapter.seen.last.data, containsPair('parent_id', 70));
    });
  });

  group('writes', () {
    test('note, save, delete account and logout bodies and paths', () async {
      final t = setup((o) => ResponseBody.fromString(
          jsonEncode({'success': true, 'data': {'saved': true, 'empty': false, 'lesson_id': 512, 'unread_count': 0}}),
          200,
          headers: {Headers.contentTypeHeader: ['application/json']}));
      expect(await t.repos.lessons.saveNote(512, 'hi'), isFalse);
      expect(await t.repos.lessons.setSaved(512, true), isTrue);
      await t.repos.account.deleteAccount(password: 'pw');
      await t.repos.account.logout(deviceToken: 'tok');
      await t.repos.account.logoutAll();
      await t.repos.questions.delete(70);

      final seen = t.adapter.seen;
      expect([for (final o in seen) '${o.method} ${o.path}'], [
        'PUT /student/lessons/512/note',
        'PUT /student/lessons/512/save',
        'DELETE /me',
        'POST /auth/logout',
        'POST /auth/logout-all',
        'DELETE /student/questions/70',
      ]);
      expect(seen[0].data, {'body': 'hi'});
      expect(seen[1].data, {'saved': true});
      expect(seen[2].data, {'password': 'pw'});
      expect(seen[3].data, {'device_token': 'tok'});
    });
  });
}
