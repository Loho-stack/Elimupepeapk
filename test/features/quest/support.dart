import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:elimupepe/data/api_call.dart';
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

/// Dio needs the real event loop; this lets pending requests finish, then draws a frame.
Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
  await tester.pump(const Duration(milliseconds: 100));
}

/// Loads the session state outside the fake-async zone of the test.
Future<void> loadState(WidgetTester tester, QuestRig rig) async {
  await tester.runAsync(rig.session.refresh);
}
