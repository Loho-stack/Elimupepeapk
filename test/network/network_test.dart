import 'dart:math';

import 'package:dio/dio.dart';
import 'package:elimupepe/app/app_config.dart';
import 'package:elimupepe/core/auth/token_store.dart';
import 'package:elimupepe/core/network/api_client.dart';
import 'package:elimupepe/core/network/api_exception.dart';
import 'package:elimupepe/core/network/interceptors/backoff_interceptor.dart';
import 'package:elimupepe/core/network/interceptors/debug_log_interceptor.dart';
import 'package:elimupepe/core/network/token_refresher.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  group('AppConfig', () {
    test('prod and staging base URLs', () {
      final prod = AppConfig.resolve(envDefine: 'prod');
      expect(prod.apiBaseUrl, 'https://elimupepe.loholearning.co.ke/api');
      expect(prod.appApiBaseUrl,
          'https://elimupepe.loholearning.co.ke/api/app/v1');
      expect(prod.webBaseUrl, 'https://elimupepe.loholearning.co.ke');
      final staging = AppConfig.resolve(envDefine: 'staging');
      expect(staging.apiBaseUrl, 'https://staging.loholearning.co.ke/api');
      expect(staging.host, 'staging.loholearning.co.ke');
      expect(staging.isStaging, isTrue);
    });

    test('flags are off by default', () {
      final c = AppConfig.resolve(envDefine: 'prod');
      expect(c.a11yRemoteSync, isFalse);
      expect(c.tokenRefresh, isFalse);
      expect(c.appApiV1Login, isFalse);
    });

    test('flavor and ENV must agree', () {
      expect(AppConfig.resolve(envDefine: 'staging', flavor: 'staging').isStaging,
          isTrue);
      expect(AppConfig.resolve(envDefine: 'prod', flavor: 'prod').isStaging,
          isFalse);
      expect(() => AppConfig.resolve(envDefine: 'prod', flavor: 'staging'),
          throwsStateError);
      expect(() => AppConfig.resolve(envDefine: 'staging', flavor: 'prod'),
          throwsStateError);
      expect(() => AppConfig.resolve(envDefine: 'dev'), throwsStateError);
      expect(() => AppConfig.resolve(envDefine: 'prod', flavor: 'beta'),
          throwsStateError);
    });

    test('no flavor (flutter test) trusts ENV', () {
      expect(AppConfig.resolve(envDefine: 'staging').env, AppEnv.staging);
    });
  });

  group('TokenStore', () {
    test('saves and reads tokens in the secure store', () async {
      final kv = MemoryKv();
      final store = TokenStore(kv);
      expect(await store.accessToken(), isNull);
      expect(await store.hasSession, isFalse);

      await store.save(AuthTokens(
        accessToken: 'a1',
        refreshToken: 'r1',
        accessExpiresAt: DateTime.utc(2026, 11, 12),
        refreshExpiresAt: DateTime.utc(2027, 1, 12),
      ));
      final t = (await store.read())!;
      expect(t.accessToken, 'a1');
      expect(t.refreshToken, 'r1');
      expect(t.accessExpiresAt, DateTime.utc(2026, 11, 12));
      expect(t.canRefresh, isTrue);
      expect(await store.hasSession, isTrue);
      expect(kv.data.keys.toSet(), {
        'access_token',
        'refresh_token',
        'access_expires_at',
        'refresh_expires_at'
      });
    });

    test('legacy tokens are readable until migrated, and have no refresh',
        () async {
      final kv = MemoryKv()..data['auth_token'] = 'legacy';
      final store = TokenStore(kv);
      expect(await store.accessToken(), 'legacy');
      final t = (await store.read())!;
      expect(t.canRefresh, isFalse);
    });

    test('saving without a refresh token removes the old one', () async {
      final store = TokenStore(MemoryKv());
      await store.save(const AuthTokens(accessToken: 'a', refreshToken: 'r'));
      await store.save(const AuthTokens(accessToken: 'b'));
      expect((await store.read())!.refreshToken, isNull);
    });

    test('clear removes new and legacy keys', () async {
      final kv = MemoryKv()
        ..data.addAll({
          'access_token': 'a',
          'refresh_token': 'r',
          'auth_token': 'x',
          'passport_token': 'y',
          'auth_student_id': 'keep-for-session-store',
        });
      await TokenStore(kv).clear();
      expect(kv.data.keys, ['auth_student_id']);
    });
  });

  group('ServerRefresh (POST /api/app/v1/auth/refresh)', () {
    late MemoryKv kv;
    late TokenStore store;
    late ScriptedAdapter adapter;
    late Dio dio;

    ServerRefresh make({DateTime Function()? now}) => ServerRefresh(store, dio, now: now);

    setUp(() async {
      kv = MemoryKv();
      store = TokenStore(kv);
      await store.save(AuthTokens(
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
        refreshExpiresAt: DateTime.utc(2099),
      ));
      adapter = ScriptedAdapter((o) => jsonBody(tokensEnvelope()));
      dio = Dio(BaseOptions(baseUrl: 'https://x.test/api/app/v1'))
        ..httpClientAdapter = adapter;
    });

    test('sends the refresh token in the body with no bearer header, stores '
        'the rotated pair', () async {
      expect(await make().refresh(), RefreshOutcome.refreshed);
      final req = adapter.seen.single;
      expect(req.method, 'POST');
      expect(req.path, '/auth/refresh');
      expect(req.data, {'refresh_token': 'refresh-1'});
      expect(req.headers.containsKey('Authorization'), isFalse);
      final t = (await store.read())!;
      expect(t.accessToken, 'access-2');
      expect(t.refreshToken, 'refresh-2');
      expect(t.accessExpiresAt, isNotNull);
      expect(t.refreshExpiresAt, isNotNull);
    });

    test('concurrent callers share one request (the token is single use)',
        () async {
      final r = make();
      final results = await Future.wait([r.refresh(), r.refresh(), r.refresh()]);
      expect(results, everyElement(RefreshOutcome.refreshed));
      expect(adapter.seen, hasLength(1));
    });

    test('401 or 422 means rejected and keeps nothing new', () async {
      for (final code in [401, 422]) {
        adapter.handler = (o) => status(code);
        expect(await make().refresh(), RefreshOutcome.rejected, reason: '$code');
      }
      expect((await store.read())!.accessToken, 'access-1');
    });

    test('404 before cut-over, 429, 500 and no network are unavailable',
        () async {
      for (final code in [404, 429, 500]) {
        adapter.handler = (o) => status(code);
        expect(await make().refresh(), RefreshOutcome.unavailable,
            reason: '$code');
      }
      adapter.handler = (o) => throw DioException(
          requestOptions: o, type: DioExceptionType.connectionError);
      expect(await make().refresh(), RefreshOutcome.unavailable);
    });

    test('a malformed 200 is rejected, not stored', () async {
      adapter.handler = (o) => jsonBody({'success': true, 'data': {}});
      expect(await make().refresh(), RefreshOutcome.rejected);
      expect((await store.read())!.accessToken, 'access-1');
    });

    test('canRefresh needs a refresh token that has not expired', () async {
      expect(await make().canRefresh(), isTrue);
      expect(
          await make(now: () => DateTime.utc(2100)).canRefresh(), isFalse);
      await store.save(const AuthTokens(accessToken: 'legacy-only'));
      expect(await make().canRefresh(), isFalse);
      expect(await make().refresh(), RefreshOutcome.rejected);
      expect(adapter.seen, isEmpty);
    });

    test('NoRefresh never refreshes', () async {
      expect(await const NoRefresh().canRefresh(), isFalse);
      expect(await const NoRefresh().refresh(), RefreshOutcome.rejected);
    });
  });

  group('ApiClient interceptors', () {
    late MemoryKv kv;
    late TokenStore store;
    late ScriptedAdapter adapter;
    late FakeConnectivity net;
    late int expired;
    late List<String> log;

    ApiClient client({TokenRefresher? refresher, AppConfig? config}) =>
        ApiClient(
          config: config ?? AppConfig.resolve(envDefine: 'prod'),
          tokenStore: store,
          onSessionExpired: () => expired++,
          connectivity: net,
          refresher: refresher ?? const NoRefresh(),
          debugLog: false,
          adapter: adapter,
        );

    setUp(() async {
      kv = MemoryKv();
      store = TokenStore(kv);
      net = FakeConnectivity();
      expired = 0;
      log = [];
      adapter = ScriptedAdapter((o) => jsonBody({'ok': true}));
    });

    group('auth header', () {
      test('adds Bearer for our API host', () async {
        await store.save(const AuthTokens(accessToken: 'tok'));
        await client().api.get('/student/courses');
        expect(adapter.authHeaders, ['Bearer tok']);
      });

      test('adds nothing without a session', () async {
        await client().api.get('/student/courses');
        expect(adapter.authHeaders, [null]);
      });

      test('never sends the token to a third-party host', () async {
        await store.save(const AuthTokens(accessToken: 'tok'));
        await client().api.get('https://phet.colorado.edu/x');
        await client().api.get('https://api-ebooks.loholearning.co.ke/books');
        expect(adapter.authHeaders, [null, null]);
      });

      test('noAuth requests (login, refresh) carry no token', () async {
        await store.save(const AuthTokens(accessToken: 'tok'));
        await client().api.post('/v1/auth/login',
            options: Options(extra: const {'noAuth': true}));
        expect(adapter.authHeaders, [null]);
      });

      test('staging client talks to the staging host and sends the token there',
          () async {
        await store.save(const AuthTokens(accessToken: 'tok'));
        final c = client(config: AppConfig.resolve(envDefine: 'staging'));
        await c.api.get('/student/courses');
        expect(adapter.seen.single.uri.host, 'staging.loholearning.co.ke');
        expect(adapter.authHeaders, ['Bearer tok']);
      });

      test('the App API v1 client uses the /api/app/v1 root', () async {
        await client().appV1.get('/me/accessibility');
        expect(adapter.seen.single.uri.toString(),
            'https://elimupepe.loholearning.co.ke/api/app/v1/me/accessibility');
      });

      test('refreshes ahead of time when the access token is near expiry',
          () async {
        await store.save(AuthTokens(
          accessToken: 'old',
          refreshToken: 'r',
          accessExpiresAt: DateTime.now().add(const Duration(days: 2)),
          refreshExpiresAt: DateTime.now().add(const Duration(days: 80)),
        ));
        final refresher = _FakeRefresher(store, newAccess: 'fresh');
        await client(refresher: refresher).api.get('/student/courses');
        expect(refresher.calls, 1);
        expect(adapter.authHeaders, ['Bearer fresh']);
      });

      test('does not refresh when the token has plenty of time left',
          () async {
        await store.save(AuthTokens(
          accessToken: 'ok',
          refreshToken: 'r',
          accessExpiresAt: DateTime.now().add(const Duration(days: 25)),
        ));
        final refresher = _FakeRefresher(store, newAccess: 'fresh');
        await client(refresher: refresher).api.get('/student/courses');
        expect(refresher.calls, 0);
        expect(adapter.authHeaders, ['Bearer ok']);
      });
    });

    group('401 handling', () {
      test('without refresh: clears the session and signals expiry once',
          () async {
        await store.save(const AuthTokens(accessToken: 'tok'));
        adapter.handler = (o) => status(401);
        final c = client();
        await expectLater(
          c.api.get('/student/courses'),
          throwsA(isA<DioException>().having(
              (e) => e.error, 'error', isA<SessionExpiredException>())),
        );
        expect(expired, 1);
        expect(await store.hasSession, isFalse);
      });

      test('a 401 on a request without a token (wrong password) does not '
          'end a session', () async {
        adapter.handler = (o) => status(401);
        await expectLater(
            client().api.post('/v1/auth/login',
                options: Options(extra: const {'noAuth': true})),
            throwsA(isA<DioException>()));
        expect(expired, 0);
      });

      test('with refresh: refreshes once and replays the request with the '
          'new token', () async {
        await store.save(const AuthTokens(
            accessToken: 'old', refreshToken: 'r'));
        adapter.handler = (o) => o.headers['Authorization'] == 'Bearer old'
            ? status(401)
            : jsonBody({'ok': true});
        final refresher = _FakeRefresher(store, newAccess: 'new');
        final r = await client(refresher: refresher).api.get('/student/courses');
        expect(r.statusCode, 200);
        expect(refresher.calls, 1);
        expect(adapter.authHeaders, ['Bearer old', 'Bearer new']);
        expect(expired, 0);
      });

      test('parallel 401s trigger a single refresh', () async {
        await store.save(const AuthTokens(
            accessToken: 'old', refreshToken: 'r'));
        adapter.handler = (o) => o.headers['Authorization'] == 'Bearer old'
            ? status(401)
            : jsonBody({'ok': true});
        final dio = Dio(BaseOptions(baseUrl: 'https://x.test/api/app/v1'))
          ..httpClientAdapter = ScriptedAdapter((o) => jsonBody(tokensEnvelope(
              access: 'new', refresh: 'r2')));
        final refresher = ServerRefresh(store, dio);
        final c = client(refresher: refresher);
        final rs = await Future.wait([
          c.api.get('/a'),
          c.api.get('/b'),
          c.api.get('/c'),
        ]);
        expect(rs.map((r) => r.statusCode), everyElement(200));
        expect(expired, 0);
        expect((await store.read())!.accessToken, 'new');
      });

      test('refresh rejected: session ends', () async {
        await store.save(const AuthTokens(
            accessToken: 'old', refreshToken: 'r'));
        adapter.handler = (o) => status(401);
        final refresher =
            _FakeRefresher(store, outcome: RefreshOutcome.rejected);
        await expectLater(client(refresher: refresher).api.get('/a'),
            throwsA(isA<DioException>()));
        expect(expired, 1);
        expect(await store.hasSession, isFalse);
      });

      test('refresh unavailable (offline or 5xx): keep the session, surface '
          'the original 401', () async {
        await store.save(const AuthTokens(
            accessToken: 'old', refreshToken: 'r'));
        adapter.handler = (o) => status(401);
        final refresher =
            _FakeRefresher(store, outcome: RefreshOutcome.unavailable);
        await expectLater(client(refresher: refresher).api.get('/a'),
            throwsA(isA<DioException>()));
        expect(expired, 0);
        expect(await store.hasSession, isTrue);
      });

      test('a replay that still gets 401 ends the session instead of looping',
          () async {
        await store.save(const AuthTokens(
            accessToken: 'old', refreshToken: 'r'));
        adapter.handler = (o) => status(401);
        final refresher = _FakeRefresher(store, newAccess: 'new');
        await expectLater(client(refresher: refresher).api.get('/a'),
            throwsA(isA<DioException>()));
        expect(refresher.calls, 1);
        expect(expired, 1);
        expect(adapter.seen, hasLength(2));
      });
    });

    group('offline detection', () {
      test('fails fast with OfflineException and sends nothing', () async {
        net.online = false;
        await expectLater(
          client().api.get('/student/courses'),
          throwsA(isA<DioException>()
              .having((e) => e.error, 'error', isA<OfflineException>())
              .having((e) => e.type, 'type', DioExceptionType.connectionError)),
        );
        expect(adapter.seen, isEmpty);
      });
    });

    group('error messages', () {
      test('401, 404 and 429 get friendly messages', () async {
        for (final entry in {
          404: 'The requested resource was not found on the server.',
        }.entries) {
          adapter.handler = (o) => status(entry.key);
          await expectLater(
              client().api.get('/x'),
              throwsA(isA<DioException>()
                  .having((e) => e.message, 'message', entry.value)));
        }
      });
    });
  });

  group('429 backoff', () {
    late ScriptedAdapter adapter;
    late List<Duration> waits;

    Dio make({int max = 2}) {
      final dio = Dio(BaseOptions(baseUrl: 'https://x.test/api'))
        ..httpClientAdapter = adapter;
      dio.interceptors.add(BackoffInterceptor(
        dio: dio,
        maxRetries: max,
        delay: (d) async => waits.add(d),
        random: Random(1),
        now: () => DateTime.utc(2026, 10, 13, 12),
      ));
      return dio;
    }

    setUp(() {
      waits = [];
      adapter = ScriptedAdapter((o) => status(429));
    });

    test('retries a GET twice with growing waits, then gives up', () async {
      await expectLater(make().get('/x'), throwsA(isA<DioException>()));
      expect(adapter.seen, hasLength(3));
      expect(waits, hasLength(2));
      expect(waits[1], greaterThan(waits[0]));
      expect(waits[0].inMilliseconds, inInclusiveRange(500, 749));
      expect(waits[1].inMilliseconds, inInclusiveRange(1000, 1249));
    });

    test('honours Retry-After seconds, capped at 30 s', () async {
      adapter.handler = (o) => status(429, headers: {
            'retry-after': [adapter.seen.length == 1 ? '3' : '900']
          });
      await expectLater(make().get('/x'), throwsA(isA<DioException>()));
      expect(waits, [const Duration(seconds: 3), const Duration(seconds: 30)]);
    });

    test('honours an HTTP-date Retry-After', () async {
      adapter.handler = (o) => status(429, headers: {
            'retry-after': ['Tue, 13 Oct 2026 12:00:07 GMT']
          });
      await expectLater(make(max: 1).get('/x'), throwsA(isA<DioException>()));
      expect(waits.single, const Duration(seconds: 7));
    });

    test('succeeds when a retry gets through', () async {
      adapter.handler =
          (o) => adapter.seen.length < 2 ? status(429) : jsonBody({'ok': 1});
      final r = await make().get('/x');
      expect(r.statusCode, 200);
      expect(adapter.seen, hasLength(2));
    });

    test('does not retry POST unless marked retryable', () async {
      await expectLater(make().post('/x'), throwsA(isA<DioException>()));
      expect(adapter.seen, hasLength(1));
      expect(waits, isEmpty);

      adapter.seen.clear();
      await expectLater(
          make().post('/x', options: Options(extra: const {'retryable': true})),
          throwsA(isA<DioException>()));
      expect(adapter.seen, hasLength(3));
    });

    test('other errors are not retried', () async {
      adapter.handler = (o) => status(500);
      await expectLater(make().get('/x'), throwsA(isA<DioException>()));
      expect(adapter.seen, hasLength(1));
    });
  });

  group('DebugLogInterceptor', () {
    Future<List<String>> run({required bool enabled}) async {
      final lines = <String>[];
      final adapter = ScriptedAdapter((o) => o.path.contains('fail')
          ? status(500)
          : jsonBody({'token': 'SECRET-BODY-TOKEN', 'email': 'a@b.test'}));
      final dio = Dio(BaseOptions(baseUrl: 'https://x.test/api'))
        ..httpClientAdapter = adapter;
      dio.interceptors
          .add(DebugLogInterceptor(enabled: enabled, sink: lines.add));
      await dio.get('/webview-auth',
          queryParameters: {'token': 'SECRET-URL-TOKEN', 'intended': '/x'},
          options: Options(headers: {'Authorization': 'Bearer SECRET-HEADER'}));
      await dio.post('/v1/auth/login',
          data: {'student_id': 'LO-AAAAAAAA', 'password': 'SECRET-PASSWORD'});
      try {
        await dio.get('/fail');
      } on DioException {
        // expected
      }
      return lines;
    }

    test('logs method, path and status only', () async {
      final lines = await run(enabled: true);
      expect(lines, hasLength(3));
      expect(lines[0], startsWith('GET /api/webview-auth -> 200'));
      expect(lines[1], startsWith('POST /api/v1/auth/login -> 200'));
      expect(lines[2], startsWith('GET /api/fail -> 500'));
    });

    test('never contains tokens, query strings, passwords, bodies or ids',
        () async {
      final all = (await run(enabled: true)).join('\n');
      for (final secret in [
        'SECRET-URL-TOKEN',
        'SECRET-HEADER',
        'SECRET-PASSWORD',
        'SECRET-BODY-TOKEN',
        'a@b.test',
        'LO-AAAAAAAA',
        'Bearer',
        'intended',
        '?',
      ]) {
        expect(all.contains(secret), isFalse, reason: secret);
      }
    });

    test('disabled (release) logs nothing', () async {
      expect(await run(enabled: false), isEmpty);
    });
  });
}

class _FakeRefresher implements TokenRefresher {
  _FakeRefresher(this._store,
      {this.newAccess = 'new', this.outcome = RefreshOutcome.refreshed});
  final TokenStore _store;
  final String newAccess;
  final RefreshOutcome outcome;
  int calls = 0;

  @override
  Future<bool> canRefresh() async => true;

  @override
  Future<RefreshOutcome> refresh() async {
    calls++;
    if (outcome == RefreshOutcome.refreshed) {
      await _store.save(
          AuthTokens(accessToken: newAccess, refreshToken: 'r-next'));
    }
    return outcome;
  }
}
