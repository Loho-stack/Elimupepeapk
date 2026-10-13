import 'package:dio/dio.dart';
import 'package:elimupepe/app/app_config.dart';
import 'package:elimupepe/app/app_services.dart';
import 'package:elimupepe/core/auth/token_store.dart';
import 'package:elimupepe/core/services/analytics_service.dart';
import 'package:elimupepe/core/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';

Map<String, dynamic> appLoginBody({
  String role = 'student',
  int roleId = 3,
  Map<String, dynamic> user = const {},
}) {
  final env = tokensEnvelope(access: 'acc-1', refresh: 'ref-1');
  (env['data'] as Map<String, dynamic>)['user'] = {
    'id': 42,
    'name': 'Amina Wanjiru',
    'role': role,
    'role_id': roleId,
    'avatar_url': 'https://cdn.example.test/a.png',
    'language': 'en',
    if (role == 'student') 'student_id': 'LO-ABCD1234',
    if (role == 'student') 'grade': 'Grade 6',
    if (role != 'student') 'email': 'p@example.test',
    ...user,
  };
  return env;
}

void main() {
  late MemoryKv kv;
  late ScriptedAdapter adapter;

  Future<void> setUpServices({bool appApiLogin = false}) async {
    SharedPreferences.setMockInitialValues({'a11y.settings': '{}', 'grade': 'x'});
    kv = MemoryKv();
    adapter = ScriptedAdapter((o) => jsonBody({}));
    AppServices.override(AppServices.create(
      AppConfig.resolve(envDefine: 'prod', appApiV1Login: appApiLogin),
      kv: kv,
      adapter: adapter,
      connectivity: FakeConnectivity(),
    ));
  }

  tearDown(() => AppServices.override(null));

  group('legacy login (flag off)', () {
    setUp(() => setUpServices());

    test('stores the token only in secure storage and never a password',
        () async {
      adapter.handler = (o) => jsonBody({
            'token': 'legacy-tok',
            'user': {
              'id': 7,
              'name': 'Amina Wanjiru',
              'role_id': 3,
              'student_id': 'LO-ABCD1234'
            }
          });
      final r = await AuthService.instance
          .login(studentId: 'lo-abcd1234', password: 'my-secret-pw');
      expect(r.success, isTrue);
      expect(kv.data['access_token'], 'legacy-tok');
      expect(kv.data.keys.any((k) => k.contains('password')), isFalse);
      expect(kv.data.values.contains('my-secret-pw'), isFalse);
      expect((await SharedPreferences.getInstance()).getKeys(),
          {'a11y.settings', 'grade'});
      // The request was sent without any bearer token.
      expect(adapter.seen.single.path, '/v1/auth/login');
      expect(adapter.authHeaders, [null]);
    });

    test('there is no force retry that silently logs out another device',
        () async {
      adapter.handler = (o) => jsonBody({
            'success': false,
            'message': 'You are already logged in on another device.'
          }, status: 401);
      final r = await AuthService.instance
          .login(studentId: 'LO-ABCD1234', password: 'pw');
      expect(r.success, isFalse);
      expect(adapter.seen, hasLength(1));
    });

    test('email logins and malformed ids are rejected without a request',
        () async {
      var r = await AuthService.instance
          .login(studentId: 'kid@example.test', password: 'x');
      expect(r.success, isFalse);
      r = await AuthService.instance.login(studentId: 'nope', password: 'x');
      expect(r.success, isFalse);
      expect(adapter.seen, isEmpty);
    });
  });

  group('App API v1 login (flag on)', () {
    setUp(() => setUpServices(appApiLogin: true));

    test('student: POSTs /auth/student/login and stores both tokens',
        () async {
      adapter.handler = (o) => jsonBody(appLoginBody());
      final r = await AuthService.instance
          .login(studentId: 'lo-abcd1234', password: 'pw');
      expect(r.success, isTrue);
      expect(r.studentId, 'LO-ABCD1234');
      final req = adapter.seen.single;
      expect(req.uri.toString(),
          'https://elimupepe.loholearning.co.ke/api/app/v1/auth/student/login');
      expect(req.data, {'student_id': 'LO-ABCD1234', 'password': 'pw'});
      expect(adapter.authHeaders, [null]);

      final tokens = (await AppServices.instance.tokenStore.read())!;
      expect(tokens.accessToken, 'acc-1');
      expect(tokens.refreshToken, 'ref-1');
      expect(tokens.accessExpiresAt, isNotNull);
      expect(tokens.refreshExpiresAt, isNotNull);

      final profile = await AppServices.instance.profile.read();
      expect(profile.name, 'Amina Wanjiru');
      expect(profile.avatarUrl, 'https://cdn.example.test/a.png');
      expect(kv.data.values.contains('pw'), isFalse);
    });

    test('parent and teacher send identifier and password', () async {
      adapter.handler = (o) =>
          jsonBody(appLoginBody(role: 'parent', roleId: 7));
      var r = await AuthService.instance.loginWithAppApi(
          role: 'parent', identifier: ' p@example.test ', password: 'pw');
      expect(r.success, isTrue);
      expect(r.roleId, 7);
      expect(adapter.seen.last.path, '/auth/parent/login');
      expect(adapter.seen.last.data,
          {'identifier': 'p@example.test', 'password': 'pw'});

      adapter.handler = (o) => jsonBody(appLoginBody(
          role: 'teacher',
          roleId: 2,
          user: {'school_id': 5, 'teacher_administrative': false}));
      r = await AuthService.instance.loginWithAppApi(
          role: 'teacher', identifier: 't@example.test', password: 'pw');
      expect(r.success, isTrue);
      expect(r.roleId, 2);
      expect(adapter.seen.last.path, '/auth/teacher/login');
    });

    test('401, 403, 422 and 429 map to safe messages', () async {
      final messages = <int, String>{};
      for (final code in [401, 403, 422, 429]) {
        adapter.handler =
            (o) => jsonBody({'success': false, 'message': 'srv-$code'}, status: code);
        final r = await AuthService.instance
            .login(studentId: 'LO-ABCD1234', password: 'pw');
        expect(r.success, isFalse, reason: '$code');
        messages[code] = r.message;
      }
      expect(messages[401], 'srv-401');
      expect(messages[403], contains('not active'));
      expect(messages[429], contains('Too many attempts'));
      // A failed login never leaves a session behind.
      expect(await AppServices.instance.tokenStore.hasSession, isFalse);
    });

    test('a response without a token or with a wrong role is refused',
        () async {
      adapter.handler = (o) => jsonBody({'success': true, 'data': {}});
      var r = await AuthService.instance
          .login(studentId: 'LO-ABCD1234', password: 'pw');
      expect(r.success, isFalse);

      adapter.handler = (o) =>
          jsonBody(appLoginBody(role: 'admin', roleId: 1));
      r = await AuthService.instance
          .login(studentId: 'LO-ABCD1234', password: 'pw');
      expect(r.success, isFalse);
      expect(await AppServices.instance.tokenStore.hasSession, isFalse);
    });
  });

  group('logout and account deletion', () {
    setUp(() => setUpServices());

    Future<void> signIn({bool v1 = false}) async {
      await AppServices.instance.tokenStore.save(
        v1
            ? const AuthTokens2('a', 'r').toTokens()
            : const AuthTokens2('a', null).toTokens(),
      );
      await AppServices.instance.profile
          .update(name: 'Amina', avatarUrl: 'https://a.test/x.png');
      kv.data['auth_student_id'] = 'LO-ABCD1234';
      await AppServices.instance.remembered.remember('LO-ABCD1234');
      final p = await SharedPreferences.getInstance();
      await p.setString('points', '10');
    }

    test('logout wipes the device but keeps an opted-in Student ID only',
        () async {
      await signIn();
      await AuthService.instance.logout();

      expect(adapter.seen.single.path, '/v1/auth/logout');
      expect(adapter.authHeaders.single, 'Bearer a');
      expect(await AppServices.instance.tokenStore.hasSession, isFalse);
      expect((await AppServices.instance.profile.read()).isEmpty, isTrue);
      expect(await AppServices.instance.remembered.studentId(),
          'LO-ABCD1234');
      expect(kv.data.keys.toSet(),
          {'migration_v1_done', 'remembered_student_id'});
      expect((await SharedPreferences.getInstance()).getKeys(),
          {'a11y.settings'});
      expect(kv.data.containsKey('auth_student_id'), isFalse);
    });

    test('logout of an App API v1 session revokes only this device',
        () async {
      await signIn(v1: true);
      await AuthService.instance.logout();
      expect(adapter.seen.single.uri.path, '/api/app/v1/auth/logout');
      expect(await AppServices.instance.tokenStore.hasSession, isFalse);
    });

    test('logout still wipes locally when the server is unreachable',
        () async {
      await signIn();
      adapter.handler = (o) => throw DioException(
          requestOptions: o, type: DioExceptionType.connectionError);
      await AuthService.instance.logout();
      expect(await AppServices.instance.tokenStore.hasSession, isFalse);
    });

    test('account deletion also forgets the remembered Student ID',
        () async {
      await signIn();
      adapter.handler = (o) => jsonBody({}, status: 200);
      expect(await AuthService.instance.deleteAccount(), isTrue);
      expect(await AppServices.instance.remembered.studentId(), isNull);
      expect(kv.data.keys, ['migration_v1_done']);
    });

    test('an expired session (unrefreshable 401) signals the app once',
        () async {
      await signIn();
      var signals = 0;
      AppServices.instance.sessionExpired.addListener(() => signals++);
      adapter.handler = (o) => status(401);
      await expectLater(
          AppServices.instance.apiClient.api.get('/student/courses'),
          throwsA(isA<DioException>()));
      expect(signals, 1);
      expect(await AppServices.instance.tokenStore.hasSession, isFalse);
    });
  });

  group('AnalyticsPolicy', () {
    test('unknown events are dropped', () {
      expect(AnalyticsPolicy.sanitize('profile_viewed', {'a': 1}), isNull);
    });

    test('only listed parameters survive', () {
      final p = AnalyticsPolicy.sanitize('book_download_success', {
        'book_id': '12',
        'book_category': 'Textbooks',
        'book_title': 'Secret title',
        'book_author': 'Someone',
        'student_id': 'LO-ABCD1234',
        'email': 'a@b.test',
      });
      expect(p, {'book_id': '12', 'book_category': 'Textbooks'});
    });

    test('login_failed reasons are fixed codes, never server text', () {
      expect(AnalyticsPolicy.sanitize('login_failed', {'reason': 'network'}),
          {'reason': 'network'});
      expect(
          AnalyticsPolicy.sanitize(
              'login_failed', {'reason': 'Student LO-ABCD1234 not found'}),
          isEmpty);
    });

    test('long strings are cut and non-primitive values dropped', () {
      final p = AnalyticsPolicy.sanitize('book_download_error', {
        'book_id': 'x' * 100,
        'error_type': <String>['a'],
      });
      expect((p!['book_id'] as String).length, 40);
      expect(p.containsKey('error_type'), isFalse);
    });

    test('every event and key in the policy is free of identifiers', () {
      const banned = [
        'name',
        'email',
        'phone',
        'student',
        'token',
        'password',
        'title',
        'author',
        'answer',
        'message',
      ];
      for (final e in AnalyticsPolicy.events.entries) {
        for (final k in e.value) {
          for (final b in banned) {
            expect(k.contains(b), isFalse, reason: '${e.key}.$k');
          }
        }
      }
    });
  });
}

/// Small helper so the tests read clearly.
class AuthTokens2 {
  const AuthTokens2(this.access, this.refresh);
  final String access;
  final String? refresh;
  AuthTokens toTokens() => AuthTokens(accessToken: access, refreshToken: refresh);
}
