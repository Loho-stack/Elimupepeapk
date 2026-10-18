import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:elimupepe/data/api_call.dart';
import 'package:elimupepe/data/api_error.dart';
import 'package:elimupepe/data/models/msafara_checkpoint.dart';
import 'package:elimupepe/data/repositories/app_repositories.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

String fixture(String name) => File('test/fixtures/msafara/$name.json').readAsStringSync();

Map<String, dynamic> data(String name) =>
    (jsonDecode(fixture(name)) as Map<String, dynamic>)['data'] as Map<String, dynamic>;

ResponseBody body(String name) => ResponseBody.fromString(fixture(name), 200,
    headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

({AppRepositories repos, ScriptedAdapter adapter}) setup(Responder handler) {
  final adapter = ScriptedAdapter(handler);
  final dio = Dio(BaseOptions(baseUrl: 'https://staging.loholearning.co.ke/api/app/v1'))..httpClientAdapter = adapter;
  return (repos: AppRepositories(ApiCall(dio)), adapter: adapter);
}

void main() {
  group('checkpoint models from the contract examples', () {
    test('the checkpoint', () {
      final c = Checkpoint.fromJson(data('checkpoint'));
      expect((c.day, c.state, c.town, c.county), (12, 'open', 'Voi', 'Taita-Taveta'));
      expect(c.fact, 'Voi is the gateway to Tsavo East.');
      expect(c.options, ['Tsavo East', 'Amboseli', 'Nairobi National Park']);
      expect((c.canAnswer, c.attemptsLeft, c.maxAttempts), (true, 2, 2));
      expect((c.kmExpected, c.fullKm, c.coinsExpected), (20.0, 20.0, 20));
      expect(c.answers, isEmpty);
      expect(c.bandPending, isFalse);
      expect(c.finished, isFalse);
      expect(c.date!.toUtc(), DateTime.utc(2026, 10, 29, 21));
    });

    test('a band with no question yet', () {
      final c = Checkpoint.fromJson({...data('checkpoint'), 'fact': null, 'question': null, 'options': null, 'can_answer': false});
      expect(c.bandPending, isTrue);
      expect(c.options, isEmpty);
    });

    test('attempts and the correct answer', () {
      final c = Checkpoint.fromJson({
        ...data('checkpoint'),
        'attempts_left': 0,
        'correct_answer': 'Tsavo East',
        'answers': [
          {'attempt': 1, 'chosen': 'Amboseli', 'correct': false, 'late': false, 'answered_at': '2026-10-30T09:12:44+03:00'}
        ],
      });
      expect(c.answers.single.chosen, 'Amboseli');
      expect(c.finished, isTrue);
      expect(c.correctAnswer, 'Tsavo East');
    });

    test('the answer result', () {
      final r = CheckpointResult.fromJson(data('checkpoint_answer'));
      expect((r.correct, r.solved, r.coins, r.kmExpected, r.correctAnswer), (true, true, 20.0, 20.0, 'Tsavo East'));
      expect(r.attemptsLeft, 1);
    });
  });

  group('MsafaraRepository, checkpoint', () {
    test('today and a given day', () async {
      final t = setup((o) => body('checkpoint'));
      await t.repos.msafara.checkpoint();
      await t.repos.msafara.checkpoint(day: 0);
      expect(t.adapter.seen.map((o) => o.path), ['/msafara/checkpoint', '/msafara/checkpoint/0']);
    });

    test('answer sends the option and a key', () async {
      final t = setup((o) => body('checkpoint_answer'));
      await t.repos.msafara.answerCheckpoint(12, option: 'Tsavo East', key: 'k-1');
      final o = t.adapter.seen.single;
      expect((o.method, o.path), ('POST', '/msafara/checkpoint/12'));
      expect(o.data, {'option': 'Tsavo East'});
      expect(o.headers['Idempotency-Key'], 'k-1');
    });

    test('409 checkpoint codes are ConflictErrors, 404 is NotFoundError', () async {
      for (final code in ['checkpoint_locked', 'checkpoint_closed', 'already_answered']) {
        final t = setup((o) => jsonBody({'success': false, 'message': 'x', 'code': code}, status: 409));
        await expectLater(
          t.repos.msafara.answerCheckpoint(12, option: 'a', key: 'k'),
          throwsA(isA<ConflictError>().having((c) => c.code, 'code', code)),
        );
      }
      final t = setup((o) => jsonBody({'success': false, 'message': 'x'}, status: 404));
      await expectLater(t.repos.msafara.checkpoint(day: 12), throwsA(isA<NotFoundError>()));
    });
  });
}
