import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:elimupepe/data/api_call.dart';
import 'package:elimupepe/data/api_error.dart';
import 'package:elimupepe/data/models/msafara.dart';
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
    test('state: countdown', () {
      final s = MsafaraState.fromJson(data('state_countdown'));
      expect(s.stage, QuestStage.countdown);
      expect(s.secondsToStart, 10549);
      expect(s.opensAt!.toUtc(), DateTime.utc(2026, 10, 18, 21));
      expect(s.serverTime.toUtc().hour, 18); // 21:04 +03:00
      expect(s.seat, 'reserved');
      expect(s.seatsReserved, 18423);
      expect(s.calendar.today.day, isNull);
      expect(s.calendar.today.totalDays, 92);
      expect(s.calendar.startsOn, '2026-10-19');
      expect(s.learner!.gradeBand, 'G4-6');
      expect(s.flags.boards, isTrue);
    });

    test('state: active, terms pending, disabled', () {
      final a = MsafaraState.fromJson(data('state_active'));
      expect(a.stage, QuestStage.active);
      expect(a.secondsToStart, isNull);
      expect(a.calendar.today.town, 'Voi');
      expect(a.calendar.today.dayType, 'lesson');

      final t = MsafaraState.fromJson(data('state_terms'));
      expect(t.termsAccepted, isFalse);
      expect(t.profileMissing, ['grade', 'county']);
      expect(t.learner, isNull);
      expect(t.seat, 'open');

      final d = MsafaraState.fromJson(data('state_disabled'));
      expect(d.stage, QuestStage.disabled);
      expect(d.seat, isNull);
    });

    test('an unknown stage reads as disabled', () {
      final j = data('state_active')..['stage'] = 'something_new';
      expect(MsafaraState.fromJson(j).stage, QuestStage.disabled);
    });

    test('terms', () {
      final t = Terms.fromJson(data('terms'));
      expect(t.version, 'msafara-terms-v1');
      expect(t.sections.map((s) => s.heading), ['What we keep', 'Play fair']);
      expect(t.sections.first.items, hasLength(2));
      expect(t.attestations.map((a) => a.key), ['accept_terms', 'parent_agreed']);
      expect(t.attestations.last.note, isNotNull);
      expect(t.continueLabel, 'Continue');
    });

    test('terms result, profile form and profile result', () {
      final r = TermsResult.fromJson(data('terms_accepted'));
      expect((r.recorded, r.stage), (true, QuestStage.profile));

      final p = ProfileForm.fromJson(data('profile'));
      expect(p.needsGrade && p.needsCounty, isTrue);
      expect(p.grades.map((g) => g.key), ['PP1', 'G4', 'G10']);
      expect(p.counties, hasLength(4));

      final s = ProfileResult.fromJson(data('profile_saved'));
      expect((s.gradeLabel, s.county, s.stage), ('Grade 4', 'Nairobi', QuestStage.countdown));
    });
  });

  group('MsafaraRepository', () {
    test('state is a plain GET', () async {
      final t = setup((o) => body('state_countdown'));
      final s = await t.repos.msafara.state();
      expect(t.adapter.seen.single.method, 'GET');
      expect(t.adapter.seen.single.path, '/msafara/state');
      expect(s.stage, QuestStage.countdown);
    });

    test('terms asks for the language', () async {
      final t = setup((o) => body('terms'));
      await t.repos.msafara.terms(lang: 'sw');
      expect(t.adapter.seen.single.queryParameters, {'lang': 'sw'});
    });

    test('acceptTerms sends both attestations and the key', () async {
      final t = setup((o) => body('terms_accepted'));
      final r = await t.repos.msafara.acceptTerms(key: 'k-1');
      final o = t.adapter.seen.single;
      expect(o.method, 'POST');
      expect(o.headers['Idempotency-Key'], 'k-1');
      expect(o.data, {'accept_terms': true, 'parent_agreed': true});
      expect(r.stage, QuestStage.profile);
    });

    test('saveProfile sends only what is given', () async {
      final t = setup((o) => body('profile_saved'));
      await t.repos.msafara.saveProfile(grade: 'G4', key: 'k-2');
      expect(t.adapter.seen.single.data, {'grade': 'G4'});
      expect(t.adapter.seen.single.headers['Idempotency-Key'], 'k-2');
    });

    test('a bad shape is a ParseError', () async {
      final t = setup((o) => jsonBody({'success': true, 'data': {'stage': 'active'}}));
      expect(await failure(t.repos.msafara.state), isA<ParseError>());
    });

    test('409 gate codes map to MsafaraGateError', () async {
      for (final code in ['not_started', 'terms_required']) {
        final t = setup((o) => jsonBody({'success': false, 'message': 'x', 'code': code}, status: 409));
        final e = await failure(t.repos.msafara.profile);
        expect(e, isA<MsafaraGateError>().having((g) => g.code, 'code', code));
      }
      final t = setup((o) => jsonBody(
          {'success': false, 'message': 'x', 'code': 'profile_required', 'missing': ['grade', 'county']},
          status: 409));
      final e = await failure(() => t.repos.msafara.state());
      expect(e, isA<MsafaraGateError>().having((g) => g.missing, 'missing', ['grade', 'county']));
    });

    test('409 without a code is still the in-flight answer', () async {
      final t = setup((o) => jsonBody({'success': false, 'message': 'Request in progress.'}, status: 409));
      expect(await failure(() => t.repos.msafara.acceptTerms(key: 'k')), isA<InFlightError>());
    });

    test('404 is NotFoundError and 422 carries field errors', () async {
      var t = setup((o) => jsonBody({'success': false, 'message': 'Not found'}, status: 404));
      expect(await failure(t.repos.msafara.profile), isA<NotFoundError>());

      t = setup((o) => jsonBody({
            'success': false,
            'message': 'The given data was invalid.',
            'errors': {'parent_agreed': ['Tick the second box to continue.']},
          }, status: 422));
      final e = await failure(() => t.repos.msafara.acceptTerms(key: 'k'));
      expect(e, isA<ValidationError>().having((v) => v.has('parent_agreed'), 'has', true));
    });

    test('quest_locked carries the seconds left', () async {
      final t = setup((o) => jsonBody(
          {'success': false, 'message': 'x', 'code': 'quest_locked', 'remaining': 105},
          status: 409));
      final e = await failure(t.repos.msafara.profile);
      expect(e, isA<QuestLockedError>().having((q) => q.remaining, 'remaining', 105));
    });
  });
}
