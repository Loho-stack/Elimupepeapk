import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:elimupepe/data/api_call.dart';
import 'package:elimupepe/data/api_error.dart';
import 'package:elimupepe/data/models/msafara_quests.dart';
import 'package:elimupepe/data/repositories/app_repositories.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

/// Fixtures in test/fixtures/msafara are the examples of docs/api/MSAFARA_V1.md (branch app-api/msafara).
String fixture(String name) => File('test/fixtures/msafara/$name.json').readAsStringSync();

Map<String, dynamic> data(String name) =>
    (jsonDecode(fixture(name)) as Map<String, dynamic>)['data'] as Map<String, dynamic>;

ResponseBody body(String name, {int status = 200}) => ResponseBody.fromString(fixture(name), status,
    headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

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
  group('models from the contract examples', () {
    test('home', () {
      final h = QuestHome.fromJson(data('home'));
      expect(h.day, 12);
      expect(h.label, 'Day 12 of 92');
      expect(h.leg!.percent, 39);
      expect(h.town!.name, 'Voi');
      expect(h.km.total, 182.5);
      expect(h.km.dailyCap, 360.0);
      expect(h.dailyGoal!.percent, 40);
      expect(h.quests, hasLength(2));
      expect(h.quests.first.isBook, isTrue);
      expect(h.quests.first.pageFrom, 4);
      expect(h.quests.first.unlocked, isFalse);
      expect(h.quests.last.completed, isTrue);
      expect(h.quests.last.score, 0.8);
      expect(h.checkpoint!.available, isTrue);
      expect(h.checkpoint!.attemptsLeft, 2);
      expect(h.missed.single.town, 'Mombasa');
      expect(h.board!.movement, 2);
      expect(h.bonus, isNull);
      expect(h.inRun, isTrue);
    });

    test('home outside the run', () {
      final h = QuestHome.fromJson(data('home_ended'));
      expect(h.inRun, isFalse);
      expect(h.ended, isTrue);
      expect(h.quests, isEmpty);
      expect(h.checkpoint, isNull);
      expect(h.km.total, 1210.5);
    });

    test('quest list', () {
      final l = QuestList.fromJson(data('quests'));
      expect(l.quests.first.pageCount, 64);
      expect(l.quests.first.remainingSeconds, 105);
      expect(l.quests.first.concept, 'Reading day 2 of 5');
      expect(l.quests.last.right, 4);
      expect(l.quests.last.lang, 'sw');
    });

    test('book quest', () {
      final d = QuestDetail.fromJson(data('quest_book'));
      expect(d.kind, 'book');
      expect(d.lesson, isNull);
      expect(d.lock.requiredSeconds, 180);
      expect(d.lock.fraction, closeTo(75 / 180, 0.0001));
      expect(d.book!.startPage, 4);
      expect(d.book!.pdfUrl, startsWith('https://'));
    });

    test('lesson quest', () {
      final d = QuestDetail.fromJson(data('quest_lesson'));
      expect(d.book, isNull);
      expect(d.lesson!.language, 'sw');
      expect(d.lesson!.paragraphs, ['Paragraph one.', 'Paragraph two.']);
    });

    test('ping replies carry in_range and the page range', () {
      final ok = QuestLock.fromJson(data('ping'));
      expect((ok.inRange, ok.pageFrom, ok.pageTo, ok.remaining), (true, 4, 9, 85));
      final off = QuestLock.fromJson(data('ping_off_range'));
      expect(off.inRange, isFalse);
    });

    test('questions', () {
      final s = QuestionSet.fromJson(data('questions'));
      expect(s.size, 3);
      expect(s.nextQuestionId, 8302);
      expect(s.questions.map((q) => q.type), ['mcq', 'fill_blank', 'true_false']);
      expect(s.questions.first.answered, isTrue);
      expect(s.questions[1].options, isEmpty);
      expect(s.questions[1].isFill, isTrue);
      expect(s.questions[1].explanation, isNull);
    });

    test('answers', () {
      final a = AnswerResult.fromJson(data('answer'));
      expect((a.correct, a.chosen, a.pageRef), (true, 'Tana', 7));
      expect(a.quest.completed, isFalse);
      expect(a.quest.right, 2);

      final last = AnswerResult.fromJson(data('answer_last'));
      expect(last.quest.completed, isTrue);
      expect(last.quest.score, 0.6667);
      expect(last.quest.passed, isTrue);
      expect(last.quest.kmExpected, 10.0);
    });

    test('an answered question takes the reply', () {
      final s = QuestionSet.fromJson(data('questions'));
      final q = s.questions[1].withAnswer(AnswerResult.fromJson(data('answer')));
      expect(q.answered, isTrue);
      expect(q.correct, isTrue);
      expect(q.explanation, contains('Tana'));
    });
  });

  group('MsafaraRepository, quests', () {
    test('home and quests are plain GETs', () async {
      final t = setup((o) => o.path == '/msafara/home' ? body('home') : body('quests'));
      await t.repos.msafara.home();
      await t.repos.msafara.quests();
      expect(t.adapter.seen.map((o) => '${o.method} ${o.path}'), ['GET /msafara/home', 'GET /msafara/quests']);
    });

    test('quest/{no}', () async {
      final t = setup((o) => body('quest_book'));
      final d = await t.repos.msafara.quest(1);
      expect(t.adapter.seen.single.path, '/msafara/quests/1');
      expect(d.book, isNotNull);
    });

    test('a ping sends the page, a fresh key, and is not retried on 429', () async {
      final t = setup((o) => body('ping'));
      await t.repos.msafara.ping(1, page: 5, key: 'k-a');
      await t.repos.msafara.ping(1, page: 6, key: 'k-b');
      final first = t.adapter.seen.first;
      expect(first.method, 'POST');
      expect(first.path, '/msafara/quests/1/ping');
      expect(first.data, {'page': 5});
      expect(first.headers['Idempotency-Key'], 'k-a');
      expect(first.extra['retryable'], isNot(true));
      expect(t.adapter.seen.last.headers['Idempotency-Key'], 'k-b');
    });

    test('a lesson ping has an empty body', () async {
      final t = setup((o) => body('ping'));
      await t.repos.msafara.ping(2, key: 'k');
      expect(t.adapter.seen.single.data, <String, dynamic>{});
    });

    test('a 429 on a ping comes straight back as RateLimitedError', () async {
      final t = setup((o) => jsonBody({'success': false, 'message': 'Too many attempts.'}, status: 429));
      final e = await failure(() => t.repos.msafara.ping(1, page: 5, key: 'k'));
      expect(e, isA<RateLimitedError>());
      expect(t.adapter.seen, hasLength(1), reason: 'not retried');
    });

    test('questions: 409 quest_locked carries the seconds left', () async {
      final t = setup((o) => jsonBody(
          {'success': false, 'message': 'x', 'code': 'quest_locked', 'remaining': 105},
          status: 409));
      final e = await failure(() => t.repos.msafara.questions(1));
      expect(e, isA<QuestLockedError>().having((q) => q.remaining, 'remaining', 105));
    });

    test('answer: choice for a pick, text for a blank, key on both', () async {
      final t = setup((o) => body('answer'));
      await t.repos.msafara.answer(1, questionId: 8301, choice: 2, key: 'k1');
      await t.repos.msafara.answer(1, questionId: 8302, text: 'Tana', key: 'k2');
      expect(t.adapter.seen[0].path, '/msafara/quests/1/answer');
      expect(t.adapter.seen[0].data, {'question_id': 8301, 'choice': 2});
      expect(t.adapter.seen[0].headers['Idempotency-Key'], 'k1');
      expect(t.adapter.seen[1].data, {'question_id': 8302, 'text': 'Tana'});
    });

    test('answer: quest_completed is a ConflictError, 422 a ValidationError', () async {
      var t = setup((o) => jsonBody({'success': false, 'message': 'x', 'code': 'quest_completed'}, status: 409));
      var e = await failure(() => t.repos.msafara.answer(1, questionId: 1, choice: 1, key: 'k'));
      expect(e, isA<ConflictError>().having((c) => c.code, 'code', 'quest_completed'));

      t = setup((o) => jsonBody({
            'success': false,
            'message': 'The given data was invalid.',
            'errors': {'choice': ['Choose one of the answers.']},
          }, status: 422));
      e = await failure(() => t.repos.msafara.answer(1, questionId: 1, choice: 9, key: 'k'));
      expect(e, isA<ValidationError>().having((v) => v.has('choice'), 'has', true));
    });
  });
}
