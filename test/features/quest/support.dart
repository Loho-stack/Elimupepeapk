import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:elimupepe/data/api_call.dart';
import 'package:elimupepe/data/api_error.dart';
import 'package:elimupepe/data/models/msafara.dart';
import 'package:elimupepe/data/models/msafara_checkpoint.dart';
import 'package:elimupepe/data/models/msafara_quests.dart';
import 'package:elimupepe/data/repositories/repositories.dart';
import 'package:elimupepe/features/quest/quest_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

export '../student/support.dart';

/// The raw text of a fixture in test/fixtures/msafara (the examples of docs/api/MSAFARA_V1.md).
String raw(String name) => File('test/fixtures/msafara/$name.json').readAsStringSync();

Map<String, dynamic> data(String name) => (jsonDecode(raw(name)) as Map<String, dynamic>)['data'] as Map<String, dynamic>;

ResponseBody ok(String name) => ResponseBody.fromString(raw(name), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });

ResponseBody gate(String code, {List<String> missing = const []}) => jsonBody({
      'success': false,
      'message': 'x',
      'code': code,
      if (missing.isNotEmpty) 'missing': missing,
    }, status: 409);

/// A clock the test moves by hand.
class FakeClock implements QuestClock {
  @override
  Duration elapsed = Duration.zero;
}

class QuestRig {
  QuestRig(Responder handler, {Future<bool?> Function()? remoteEnabled, String lang = 'en'})
      : adapter = ScriptedAdapter(handler) {
    final dio = Dio(BaseOptions(baseUrl: 'https://staging.loholearning.co.ke/api/app/v1'))..httpClientAdapter = adapter;
    repo = MsafaraRepository(ApiCall(dio));
    session = MsafaraSession(repo, clock: clock, remoteEnabled: remoteEnabled, initialLanguage: lang);
  }

  final ScriptedAdapter adapter;
  final FakeClock clock = FakeClock();
  late final MsafaraRepository repo;
  late final MsafaraSession session;

  Iterable<RequestOptions> calls(String method, String path) =>
      adapter.seen.where((o) => o.method == method && o.path == path);
}

/// A repository whose quest calls answer from the test, without Dio, so widget tests need no real async.
class FakeQuestRepo extends MsafaraRepository {
  FakeQuestRepo() : super(ApiCall(Dio()));

  @override
  Future<MsafaraState> state() async => MsafaraState.fromJson(data('state_active'));

  final pingPages = <int?>[];
  final pingKeys = <String>[];

  /// What the n-th ping (1-based) answers: a [QuestLock] or an [AppApiError].
  Object Function(int n) pingReply = (n) => QuestLock.fromJson(data('ping'));

  @override
  Future<QuestLock> ping(int no, {int? page, required String key}) async {
    pingPages.add(page);
    pingKeys.add(key);
    final r = pingReply(pingPages.length);
    if (r is AppApiError) throw r;
    return r as QuestLock;
  }

  Object Function() questionsReply = () => QuestionSet.fromJson(data('questions'));
  int questionsCalls = 0;

  @override
  Future<QuestionSet> questions(int no) async {
    questionsCalls++;
    final r = questionsReply();
    if (r is AppApiError) throw r;
    return r as QuestionSet;
  }

  /// What the next `checkpoint` call answers: a [Checkpoint] or an [AppApiError].
  Object Function() checkpointReply = () => Checkpoint.fromJson(data('checkpoint'));
  int checkpointCalls = 0;

  @override
  Future<Checkpoint> checkpoint({int? day}) async {
    checkpointCalls++;
    final r = checkpointReply();
    if (r is AppApiError) throw r;
    return r as Checkpoint;
  }

  /// The replies of the next checkpoint answers, in order.
  final checkpointAnswerReplies = <Object>[];
  final checkpointAnswers = <({int day, String option, String key})>[];

  @override
  Future<CheckpointResult> answerCheckpoint(int day, {required String option, required String key}) async {
    checkpointAnswers.add((day: day, option: option, key: key));
    final r = checkpointAnswerReplies.removeAt(0);
    if (r is AppApiError) throw r;
    return r as CheckpointResult;
  }

  /// The replies of the next answers, in order: an [AnswerResult] or an [AppApiError].
  final answerReplies = <Object>[];
  final answers = <({int questionId, int? choice, String? text, String key})>[];

  @override
  Future<AnswerResult> answer(int no, {required int questionId, int? choice, String? text, required String key}) async {
    answers.add((questionId: questionId, choice: choice, text: text, key: key));
    final r = answerReplies.removeAt(0);
    if (r is AppApiError) throw r;
    return r as AnswerResult;
  }
}

/// Dio needs the real event loop; this lets pending requests finish, then draws a frame.
Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
  await tester.pump(const Duration(milliseconds: 100));
}

/// Loads the session state outside the fake-async zone of the test.
Future<void> loadState(WidgetTester tester, QuestRig rig) async {
  await tester.runAsync(rig.session.refresh);
}
