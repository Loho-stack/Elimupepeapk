import 'dart:io';
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:elimupepe/app/app_config.dart';
import 'package:elimupepe/app/app_services.dart';
import 'package:elimupepe/core/design/clay.dart';
import 'package:elimupepe/core/network/interceptors/connectivity_interceptor.dart';
import 'package:elimupepe/core/webview/sso_token_service.dart';
import 'package:elimupepe/core/webview/sso_webview.dart';
import 'package:elimupepe/core/webview/web_engine.dart';
import 'package:elimupepe/core/webview/webview_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../design/harness.dart';
import '../support/fakes.dart';

const policy = WebviewPolicy(ownHost: 'elimupepe.loholearning.co.ke');

class FakeEngine implements WebEngine {
  FakeEngine(this.events);
  final WebEngineEvents events;
  final loaded = <Uri>[];
  final history = <Uri>[];
  int reloads = 0;
  String? pageTitle;
  final scripts = <String>[];

  @override
  Widget get view => const SizedBox(key: Key('engine-view'));

  @override
  Future<void> load(Uri uri) async {
    loaded.add(uri);
    history.add(uri);
  }

  @override
  Future<bool> canGoBack() async => history.length > 1;

  @override
  Future<void> goBack() async {
    if (history.length > 1) history.removeLast();
  }

  @override
  Future<void> reload() async => reloads++;

  @override
  Future<String?> title() async => pageTitle;

  @override
  Future<void> runJavaScript(String script) async => scripts.add(script);
}

class FakeTokens implements SsoTokenService {
  final requested = <String>[];
  Object? failWith;
  int counter = 0;
  Completer<void>? gate;

  @override
  Future<Uri> link(String path) async {
    requested.add(path);
    await gate?.future;
    if (failWith != null) throw failWith!;
    counter++;
    return Uri.parse(
        'https://elimupepe.loholearning.co.ke/api/webview-auth?token=TOKEN-$counter&intended=$path');
  }
}

void main() {
  setUpAll(loadClayFonts);

  group('WebviewPolicy', () {
    NavDecision d(String url, {bool main = true}) =>
        policy.decide(Uri.parse(url), isMainFrame: main);

    test('our own hosts and the org domain load in the app', () {
      expect(d('https://elimupepe.loholearning.co.ke/dals'), NavDecision.allow);
      expect(d('https://staging.loholearning.co.ke/x'), NavDecision.allow);
      expect(d('https://leaderboard.loholearning.co.ke/embed'), NavDecision.allow);
      expect(d('https://loholearning.co.ke/'), NavDecision.allow);
    });

    test('the third parties from STUDENT_RESOURCE_MAP are allowed', () {
      for (final u in [
        'https://dalslearning.co.ke/api/Content/Player/Iframe?path=a',
        'https://www.esomakids.com/redirect/?src=loho',
        'https://phet.colorado.edu/sims/html/x.html',
        'https://api.e-limu.org/edtech/v1/games',
        'https://www.youtube.com/embed/abc',
        'https://player.vimeo.com/video/1',
        'https://docs.google.com/viewer?url=x',
        'https://view.officeapps.live.com/op/embed.aspx',
        'https://loho-stack.github.io/app-policies/',
      ]) {
        expect(d(u), NavDecision.allow, reason: u);
        expect(d(u, main: false), NavDecision.allow, reason: '$u (iframe)');
      }
    });

    test('look-alike hosts are not allowed', () {
      for (final u in [
        'https://loholearning.co.ke.evil.test/',
        'https://evilloholearning.co.ke/',
        'https://elimupepe.loholearning.co.ke.evil.test/',
        'https://phet.colorado.edu.evil.test/',
        'https://notdalslearning.co.ke/',
      ]) {
        expect(d(u), NavDecision.external, reason: u);
      }
    });

    test('other https links leave the app; iframes to them are blocked', () {
      expect(d('https://example.com/page'), NavDecision.external);
      expect(d('https://example.com/frame', main: false), NavDecision.block);
    });

    test('mail and phone links go to the phone, only from the main frame', () {
      expect(d('mailto:help@example.test'), NavDecision.external);
      expect(d('tel:+254700000000'), NavDecision.external);
      expect(d('mailto:x@y.test', main: false), NavDecision.block);
    });

    test('dangerous schemes and plain http are blocked', () {
      for (final u in [
        'http://elimupepe.loholearning.co.ke/',
        'javascript:alert(1)',
        'data:text/html,hi',
        'file:///sdcard/x',
        'intent://scan/#Intent;scheme=zxing;end',
        'content://media/1',
        'blob:https://elimupepe.loholearning.co.ke/abc',
        'market://details?id=x',
      ]) {
        expect(d(u), NavDecision.block, reason: u);
      }
      expect(d('about:blank'), NavDecision.allow);
    });

    test('download detection by extension and export paths', () {
      for (final u in [
        'https://elimupepe.loholearning.co.ke/a/report.pdf',
        'https://elimupepe.loholearning.co.ke/a/Sheet.XLSX',
        'https://elimupepe.loholearning.co.ke/student/gradebook/export',
        'https://elimupepe.loholearning.co.ke/files/download/12',
      ]) {
        expect(policy.looksLikeDownload(Uri.parse(u)), isTrue, reason: u);
      }
      for (final u in [
        'https://elimupepe.loholearning.co.ke/dals',
        'https://elimupepe.loholearning.co.ke/student/gradebook',
        'https://elimupepe.loholearning.co.ke/my-courses?x=report.pdf',
      ]) {
        expect(policy.looksLikeDownload(Uri.parse(u)), isFalse, reason: u);
      }
    });

    test('intended path must be a safe relative path', () {
      for (final ok in ['/dals', '/my-qa', '/phet/simulations/12', '/a?b=c']) {
        expect(WebviewPolicy.isSafeIntendedPath(ok), isTrue, reason: ok);
      }
      for (final bad in [
        'dals',
        '//evil.test/x',
        'https://evil.test/',
        '/a/../b',
        '/a\\b',
        '/a\nb',
        '',
        'javascript:alert(1)',
      ]) {
        expect(WebviewPolicy.isSafeIntendedPath(bad), isFalse, reason: bad);
      }
    });
  });

  group('LegacySsoTokenService', () {
    late ScriptedAdapter adapter;
    late LegacySsoTokenService service;

    setUp(() {
      var n = 0;
      adapter = ScriptedAdapter(
          (o) => jsonBody({'success': true, 'token': 'tok-${++n}'}));
      final dio = Dio(BaseOptions(baseUrl: 'https://elimupepe.loholearning.co.ke/api'))
        ..httpClientAdapter = adapter;
      service = LegacySsoTokenService(
          api: dio, config: AppConfig.resolve(envDefine: 'prod'));
    });

    test('requests a token and builds the webview-auth URL', () async {
      final uri = await service.link('/dals');
      expect(adapter.seen.single.method, 'POST');
      expect(adapter.seen.single.path, '/student/generate-webview-token');
      expect(uri.scheme, 'https');
      expect(uri.host, 'elimupepe.loholearning.co.ke');
      expect(uri.path, '/api/webview-auth');
      expect(uri.queryParameters, {'token': 'tok-1', 'intended': '/dals'});
    });

    test('every call asks for a new token (single use, never cached)',
        () async {
      final a = await service.link('/dals');
      final b = await service.link('/dals');
      expect(adapter.seen, hasLength(2));
      expect(a.queryParameters['token'], isNot(b.queryParameters['token']));
    });

    test('uses the staging host on staging', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://staging.loholearning.co.ke/api'))
        ..httpClientAdapter = adapter;
      final s = LegacySsoTokenService(
          api: dio, config: AppConfig.resolve(envDefine: 'staging'));
      expect((await s.link('/dals')).host, 'staging.loholearning.co.ke');
    });

    test('never uses the deprecated password endpoint', () async {
      await service.link('/my-qa');
      expect(adapter.seen.map((o) => o.path),
          everyElement(isNot('/student/webview-token')));
      expect(adapter.seen.single.path, '/student/generate-webview-token');
    });

    test('unsafe paths are refused before any request', () async {
      for (final bad in ['//evil.test', 'https://evil.test', '/a/../b']) {
        await expectLater(
            service.link(bad),
            throwsA(isA<SsoException>()
                .having((e) => e.kind, 'kind', SsoFailure.invalidPath)));
      }
      expect(adapter.seen, isEmpty);
    });

    test('maps failures: 401, offline, server error, missing token', () async {
      Future<SsoFailure> kindFor(ResponseBody Function(RequestOptions) h) async {
        adapter.handler = h;
        try {
          await service.link('/dals');
        } on SsoException catch (e) {
          return e.kind;
        }
        fail('expected SsoException');
      }

      expect(await kindFor((o) => status(401)), SsoFailure.unauthorized);
      expect(await kindFor((o) => status(500)), SsoFailure.unavailable);
      expect(await kindFor((o) => jsonBody({'success': true})),
          SsoFailure.unavailable);
      expect(
          await kindFor((o) => throw DioException(
              requestOptions: o, type: DioExceptionType.connectionError)),
          SsoFailure.offline);
    });
  });

  group('SsoWebViewScreen', () {
    late FakeTokens tokens;
    late FakeEngine engine;
    late List<Uri> opened;
    late FakeConnectivity net;
    late bool gateAnswer;
    late int gateCalls;

    Widget app({String? path = '/dals', String? publicUrl, double scale = 1.0}) {
      tokens = FakeTokens();
      opened = [];
      net = FakeConnectivity();
      gateAnswer = true;
      gateCalls = 0;
      return MaterialApp(
        theme: ClayTheme.build(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: SsoWebViewScreen(
          title: 'Dals Learning',
          path: publicUrl == null ? path : null,
          publicUrl: publicUrl,
          tokenService: tokens,
          policy: policy,
          connectivity: net,
          engineFactory: (events) => engine = FakeEngine(events),
          openExternal: (u) async {
            opened.add(u);
            return true;
          },
          parentalGate: (_) async {
            gateCalls++;
            return gateAnswer;
          },
        ),
      );
    }

    setUp(() {
      AppServices.override(AppServices.create(
        AppConfig.resolve(envDefine: 'prod'),
        kv: MemoryKv(),
        connectivity: FakeConnectivity(),
      ));
    });
    tearDown(() => AppServices.override(null));

    testWidgets('requests a fresh token and loads webview-auth', (tester) async {
      setPhone(tester);
      await tester.pumpWidget(app());
      await tester.pump();
      expect(tokens.requested, ['/dals']);
      expect(engine.loaded.single.path, '/api/webview-auth');
      expect(engine.loaded.single.queryParameters['intended'], '/dals');
      expect(find.byKey(const Key('engine-view')), findsOneWidget);
    });

    testWidgets('each open uses a different single-use token', (tester) async {
      setPhone(tester);
      await tester.pumpWidget(app());
      await tester.pump();
      final first = engine.loaded.single.queryParameters['token'];
      await tester.pumpWidget(const SizedBox());
      // Opening the same item again builds a new screen and a new request.
      final shared = tokens;
      await tester.pumpWidget(MaterialApp(
        theme: ClayTheme.build(),
        home: SsoWebViewScreen(
          title: 'Dals Learning',
          path: '/dals',
          tokenService: shared,
          policy: policy,
          connectivity: net,
          engineFactory: (e) => engine = FakeEngine(e),
          parentalGate: (_) async => true,
          openExternal: (_) async => true,
        ),
      ));
      await tester.pump();
      expect(shared.requested, ['/dals', '/dals']);
      expect(engine.loaded.single.queryParameters['token'], isNot(first));
    });

    testWidgets('shows a Clay loading state while the token is fetched',
        (tester) async {
      setPhone(tester);
      final w = app();
      tokens.gate = Completer<void>(); // the token request stays pending
      await tester.pumpWidget(w);
      await tester.pump();
      expect(find.byType(ClaySkeleton), findsWidgets);
      expect(find.bySemanticsLabel('Opening securely'), findsOneWidget);
    });

    testWidgets('offline: no token is requested and a retry state is shown',
        (tester) async {
      setPhone(tester);
      final w = app();
      net.online = false;
      await tester.pumpWidget(w);
      await tester.pump();
      expect(tokens.requested, isEmpty);
      expect(find.text('You are offline'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      net.online = true;
      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(tokens.requested, ['/dals']);
      expect(find.text('You are offline'), findsNothing);
    });

    testWidgets('session ended (401) says so and offers no retry loop',
        (tester) async {
      setPhone(tester);
      final w = app();
      tokens.failWith = const SsoException(SsoFailure.unauthorized);
      await tester.pumpWidget(w);
      await tester.pump();
      expect(find.text('Please sign in again'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('server failure shows a retryable error', (tester) async {
      setPhone(tester);
      final w = app();
      tokens.failWith = const SsoException(SsoFailure.unavailable);
      await tester.pumpWidget(w);
      await tester.pump();
      expect(find.text('Could not open this page'), findsOneWidget);
      tokens.failWith = null;
      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(find.text('Could not open this page'), findsNothing);
      expect(tokens.requested, hasLength(2));
    });

    testWidgets('a 403 on webview-auth asks for a new token once, then stops',
        (tester) async {
      setPhone(tester);
      await tester.pumpWidget(app());
      await tester.pump();
      final first = engine.loaded.single;

      engine.events.onHttpError(first, 403);
      await tester.pump();
      expect(tokens.requested, hasLength(2));
      expect(engine.loaded.last.queryParameters['token'],
          isNot(first.queryParameters['token']));

      engine.events.onHttpError(engine.loaded.last, 403);
      await tester.pump();
      expect(tokens.requested, hasLength(2));
      expect(find.text('Could not open this page'), findsOneWidget);
    });

    testWidgets('other HTTP errors do not trigger a token request',
        (tester) async {
      setPhone(tester);
      await tester.pumpWidget(app());
      await tester.pump();
      engine.events.onHttpError(
          Uri.parse('https://elimupepe.loholearning.co.ke/dals'), 403);
      engine.events.onHttpError(
          Uri.parse('https://elimupepe.loholearning.co.ke/api/webview-auth'), 500);
      await tester.pump();
      expect(tokens.requested, hasLength(1));
    });

    testWidgets('main-frame network error shows the offline state',
        (tester) async {
      setPhone(tester);
      await tester.pumpWidget(app());
      await tester.pump();
      engine.events.onError(const WebLoadError(isMainFrame: false, isNetwork: true));
      await tester.pump();
      expect(find.text('You are offline'), findsNothing);
      engine.events.onError(const WebLoadError(isMainFrame: true, isNetwork: true));
      await tester.pump();
      expect(find.text('You are offline'), findsOneWidget);
    });

    group('navigation', () {
      testWidgets('allowed hosts load, external links ask the gate then open '
          'the browser', (tester) async {
        setPhone(tester);
        await tester.pumpWidget(app());
        await tester.pump();

        expect(
            engine.events.onNavigationRequest(
                Uri.parse('https://phet.colorado.edu/sims/x.html'), true),
            isTrue);

        final allowed = engine.events.onNavigationRequest(
            Uri.parse('https://example.com/offer'), true);
        expect(allowed, isFalse);
        await tester.pump();
        expect(gateCalls, 1);
        expect(opened.single.toString(), 'https://example.com/offer');
      });

      testWidgets('a wrong parental gate answer opens nothing', (tester) async {
        setPhone(tester);
        await tester.pumpWidget(app());
        await tester.pump();
        gateAnswer = false;
        engine.events.onNavigationRequest(Uri.parse('https://example.com/'), true);
        await tester.pump();
        expect(gateCalls, 1);
        expect(opened, isEmpty);
      });

      testWidgets('iframes to unknown hosts and dangerous schemes are blocked '
          'without leaving the app', (tester) async {
        setPhone(tester);
        await tester.pumpWidget(app());
        await tester.pump();
        // An iframe to an unknown host is blocked, never sent to the browser.
        expect(
            engine.events.onNavigationRequest(
                Uri.parse('https://ads.example.com/frame'), false),
            isFalse);
        for (final u in [
          'javascript:alert(1)',
          'http://elimupepe.loholearning.co.ke/',
          'intent://x#Intent;end',
        ]) {
          expect(engine.events.onNavigationRequest(Uri.parse(u), false), isFalse,
              reason: u);
          expect(engine.events.onNavigationRequest(Uri.parse(u), true), isFalse,
              reason: '$u main');
        }
        await tester.pump();
        expect(opened, isEmpty);
        expect(gateCalls, 0);
      });

      testWidgets('file downloads go to the phone, not into the page',
          (tester) async {
        setPhone(tester);
        await tester.pumpWidget(app());
        await tester.pump();
        final u = Uri.parse('https://elimupepe.loholearning.co.ke/student/gradebook/export');
        expect(engine.events.onNavigationRequest(u, true), isFalse);
        await tester.pump();
        expect(opened.single, u);
      });

      testWidgets('target=_blank and window.open arrive as script messages '
          'and open the external browser', (tester) async {
        setPhone(tester);
        await tester.pumpWidget(app());
        await tester.pump();
        engine.events.onScriptMessage('https://example.com/new-tab');
        await tester.pump();
        expect(opened.single.toString(), 'https://example.com/new-tab');

        // Only https and phone/mail schemes are handed over.
        opened.clear();
        engine.events.onScriptMessage('javascript:alert(1)');
        engine.events.onScriptMessage('intent://x#Intent;end');
        engine.events.onScriptMessage('not a url');
        await tester.pump();
        expect(opened, isEmpty);
      });

      testWidgets('a popup that slipped into the main frame is sent back out',
          (tester) async {
        setPhone(tester);
        await tester.pumpWidget(app());
        await tester.pump();
        engine.history.add(Uri.parse('https://elimupepe.loholearning.co.ke/a'));
        engine.history.add(Uri.parse('https://example.com/popup'));
        engine.events.onUrlChange(Uri.parse('https://example.com/popup'));
        await tester.pump();
        expect(engine.history.last.path, '/a');
        expect(opened.single.host, 'example.com');
      });

      testWidgets('the page bridge script is installed on page events',
          (tester) async {
        expect(ssoBridgeScript, contains('SsoBridge'));
        expect(ssoBridgeScript, contains('a[target="_blank"]'));
        expect(ssoBridgeScript, contains('window.open'));
      });
    });

    group('back button', () {
      testWidgets('goes through webview history first, then leaves',
          (tester) async {
        setPhone(tester);
        await tester.pumpWidget(MaterialApp(
          theme: ClayTheme.build(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => SsoWebViewScreen(
                      title: 'Dals',
                      path: '/dals',
                      tokenService: tokens = FakeTokens(),
                      policy: policy,
                      connectivity: FakeConnectivity(),
                      engineFactory: (e) => engine = FakeEngine(e),
                      parentalGate: (_) async => true,
                      openExternal: (_) async => true,
                    ),
                  )),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        engine.history.add(Uri.parse('https://elimupepe.loholearning.co.ke/page-2'));
        expect(engine.history, hasLength(2));

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(engine.history, hasLength(1));
        expect(find.byType(SsoWebViewScreen), findsOneWidget);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(SsoWebViewScreen), findsNothing);
        expect(find.text('open'), findsOneWidget);
      });
    });

    testWidgets('fullscreen video covers the page and back closes it first',
        (tester) async {
      setPhone(tester);
      await tester.pumpWidget(app());
      await tester.pump();
      engine.events.onShowFullscreen(const Text('VIDEO'));
      await tester.pump();
      expect(find.text('VIDEO'), findsOneWidget);
      expect(find.byType(ClayAppBar), findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('VIDEO'), findsNothing);
      expect(find.byType(ClayAppBar), findsOneWidget);
    });

    testWidgets('the page title replaces the item title when available',
        (tester) async {
      setPhone(tester);
      await tester.pumpWidget(app());
      await tester.pump();
      expect(find.text('Dals Learning'), findsOneWidget);
      engine.pageTitle = 'Grade 6 Maths';
      engine.events.onPageFinished(engine.loaded.single);
      await tester.pump();
      await tester.pump();
      expect(find.text('Grade 6 Maths'), findsOneWidget);
    });

    testWidgets('public pages load directly and never request a token',
        (tester) async {
      setPhone(tester);
      await tester.pumpWidget(
          app(publicUrl: 'https://loho-stack.github.io/app-policies/'));
      await tester.pump();
      expect(tokens.requested, isEmpty);
      expect(engine.loaded.single.toString(),
          'https://loho-stack.github.io/app-policies/');
    });

    testWidgets('reload button reloads the page', (tester) async {
      setPhone(tester);
      await tester.pumpWidget(app());
      await tester.pump();
      await tester.tap(find.byTooltip('Reload page'));
      expect(engine.reloads, 1);
    });

    for (final scale in clayScales) {
      testWidgets('error and loading states fit at text scale $scale',
          (tester) async {
        setPhone(tester);
        final w = app(scale: scale);
        net.online = false;
        await tester.pumpWidget(w);
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the screen is accessible: labelled 48 dp controls',
        (tester) async {
      final semantics = tester.ensureSemantics();
      setPhone(tester);
      final w = app();
      net.online = false;
      await tester.pumpWidget(w);
      await tester.pump();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });
  });

  group('secrets never reach logs or UI', () {
    test('the SSO code never prints or logs', () {
      for (final f in [
        'lib/core/webview/sso_token_service.dart',
        'lib/core/webview/sso_webview.dart',
        'lib/core/webview/web_engine.dart',
      ]) {
        final src = _read(f);
        expect(RegExp(r'\b(print|debugPrint|log)\(').hasMatch(src), isFalse,
            reason: f);
      }
    });

    test('no code sends a bearer token to a webview', () {
      final src = _read('lib/core/webview/web_engine.dart') +
          _read('lib/core/webview/sso_webview.dart');
      expect(src.contains('Authorization'), isFalse);
      expect(src.contains('loadRequest(uri, headers'), isFalse);
    });

    test('the old webview screen and password endpoint are gone', () {
      expect(
          () => _read('lib/features/settings/webview_content_screen.dart'),
          throwsA(isA<Exception>()));
    });
  });
}

String _read(String path) {
  final f = File(path);
  if (!f.existsSync()) throw Exception('missing $path');
  return f.readAsStringSync();
}
