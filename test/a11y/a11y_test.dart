import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:elimupepe/core/a11y/a11y_controller.dart';
import 'package:elimupepe/core/a11y/a11y_host.dart';
import 'package:elimupepe/core/a11y/a11y_settings.dart';
import 'package:elimupepe/core/a11y/a11y_store.dart';
import 'package:elimupepe/core/a11y/a11y_sync.dart';
import 'package:elimupepe/core/a11y/speech_service.dart';
import 'package:elimupepe/core/design/clay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design/harness.dart';

class MemoryStore implements A11yStore {
  A11ySettings? settings;
  Map<String, dynamic> pending = {};
  String? etag;

  @override
  Future<A11ySettings?> load() async => settings;
  @override
  Future<void> save(A11ySettings s) async => settings = s;
  @override
  Future<Map<String, dynamic>> loadPending() async => {...pending};
  @override
  Future<void> savePending(Map<String, dynamic> p) async => pending = {...p};
  @override
  Future<String?> loadEtag() async => etag;
  @override
  Future<void> saveEtag(String? e) async => etag = e;
  @override
  Future<void> clearAccountState() async {
    pending = {};
    etag = null;
  }
}

class FakeSync implements A11ySync {
  FakeSync({this.updatedAt, A11ySettings? remote})
      : remote = remote ?? A11ySettings.defaults;

  A11ySettings remote;
  DateTime? updatedAt;
  bool online = true;
  bool forbidden = false;
  final pushes = <Map<String, dynamic>>[];

  @override
  bool get enabled => true;

  @override
  Future<A11yPull> pull({String? etag}) async {
    if (forbidden) throw const A11ySyncForbidden();
    if (!online) throw DioException(requestOptions: RequestOptions());
    return A11yPull(settings: remote, updatedAt: updatedAt, etag: 'W/"1"');
  }

  @override
  Future<A11ySettings> push(Map<String, dynamic> changes) async {
    if (forbidden) throw const A11ySyncForbidden();
    if (!online) throw DioException(requestOptions: RequestOptions());
    pushes.add(changes);
    remote = A11ySettings.fromJson({...remote.toJson(), ...changes});
    updatedAt = DateTime(2026, 10, 13);
    return remote;
  }
}

class FakeSpeech implements SpeechService {
  final spoken = <String>[];
  SpeakResult result = SpeakResult.spoken;
  @override
  Future<SpeakResult> speak(String text, A11ySettings settings,
      {Locale? appLocale}) async {
    spoken.add(text);
    return result;
  }

  @override
  Future<void> stop() async {}
}

/// Dio adapter that answers from a function, to test RemoteA11ySync against
/// the documented contract without a network.
class ScriptedAdapter implements HttpClientAdapter {
  ScriptedAdapter(this.handler);
  final ResponseBody Function(RequestOptions o) handler;
  final seen = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    seen.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody json(Object body, {int status = 200, Map<String, List<String>>? h}) =>
    ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: ['application/json'],
      ...?h,
    });

void main() {
  setUpAll(loadClayFonts);

  group('A11ySettings (parity with PHP AccessibilitySettings)', () {
    test('defaults match DEFAULTS', () {
      expect(A11ySettings.defaults.toJson(), {
        'text_size': 0,
        'line_spacing': 0,
        'letter_spacing': 0,
        'dyslexia_font': false,
        'theme': 'light',
        'colour_blind': false,
        'reduce_motion': false,
        'mute_sounds': false,
        'simple_view': false,
        'read_speed': 1.0,
        'read_lang': 'auto',
      });
    });

    test('sanitize clamps ranges like PHP', () {
      final s = A11ySettings.fromJson({
        'text_size': 9,
        'line_spacing': -3,
        'letter_spacing': 7,
        'read_speed': 5,
      });
      expect(s.textSize, 3);
      expect(s.lineSpacing, 0);
      expect(s.letterSpacing, 2);
      expect(s.readSpeed, 1.5);
      expect(A11ySettings.fromJson({'read_speed': 0.1}).readSpeed, 0.7);
      expect(A11ySettings.fromJson({'read_speed': 1.26}).readSpeed, 1.3);
    });

    test('invalid enums fall back to the default, strings are coerced', () {
      final s = A11ySettings.fromJson({
        'theme': 'neon',
        'read_lang': 'fr',
        'text_size': '2',
      });
      expect(s.theme, ClayThemeMode.light);
      expect(s.readLang, A11yReadLang.auto);
      expect(s.textSize, 2);
    });

    test('booleans follow FILTER_VALIDATE_BOOLEAN', () {
      for (final v in [true, 1, '1', 'true', 'on', 'yes', 'TRUE']) {
        expect(A11ySettings.fromJson({'reduce_motion': v}).reduceMotion, isTrue,
            reason: '$v');
      }
      for (final v in [false, 0, '0', 'false', 'off', 'no', '', null, 'x']) {
        expect(A11ySettings.fromJson({'reduce_motion': v}).reduceMotion, isFalse,
            reason: '$v');
      }
    });

    test('unknown keys are ignored and null map gives defaults', () {
      expect(A11ySettings.fromJson({'user_id': 5, 'x': 1}),
          A11ySettings.defaults);
      expect(A11ySettings.fromJson(null), A11ySettings.defaults);
    });

    test('text scale steps are 100, 115, 130 and 150 percent', () {
      expect(A11ySettings.textScales, [1.0, 1.15, 1.30, 1.50]);
      expect(const A11ySettings(textSize: 3).textScale, 1.5);
    });

    test('diff returns only changed keys and maps to theme options', () {
      final a = A11ySettings.defaults.copyWith(
          theme: ClayThemeMode.contrast, dyslexiaFont: true, lineSpacing: 2);
      expect(a.diff(A11ySettings.defaults),
          {'theme': 'contrast', 'dyslexia_font': true, 'line_spacing': 2});
      final o = a.toThemeOptions();
      expect(o.mode, ClayThemeMode.contrast);
      expect(o.dyslexia, isTrue);
      expect(o.lineSpacing, 2);
    });
  });

  group('SharedPreferencesA11yStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('round trips settings, pending and etag; keeps settings on clear',
        () async {
      final store = SharedPreferencesA11yStore();
      expect(await store.load(), isNull);
      final s = A11ySettings.defaults.copyWith(textSize: 2, muteSounds: true);
      await store.save(s);
      await store.savePending({'text_size': 2});
      await store.saveEtag('W/"x"');
      expect(await store.load(), s);
      expect(await store.loadPending(), {'text_size': 2});
      expect(await store.loadEtag(), 'W/"x"');

      await store.clearAccountState();
      expect(await store.loadPending(), isEmpty);
      expect(await store.loadEtag(), isNull);
      expect(await store.load(), s);
    });

    test('corrupt data does not throw', () async {
      SharedPreferences.setMockInitialValues(
          {'a11y.settings': '{not json', 'a11y.pending': '[1,2'});
      final store = SharedPreferencesA11yStore();
      expect(await store.load(), isNull);
      expect(await store.loadPending(), isEmpty);
    });

    test('stores only a11y keys (no PII)', () async {
      final store = SharedPreferencesA11yStore();
      await store.save(A11ySettings.defaults);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().every((k) => k.startsWith('a11y.')), isTrue);
    });
  });

  group('A11yController', () {
    test('local only: saves and applies, never pushes', () async {
      final store = MemoryStore();
      final c = A11yController(store: store);
      await c.load();
      await c.update(c.settings.copyWith(textSize: 3));
      expect(c.settings.textSize, 3);
      expect(store.settings?.textSize, 3);
      expect(c.syncState, A11ySyncState.localOnly);
    });

    test('restores from the store on load', () async {
      final store = MemoryStore()
        ..settings = A11ySettings.defaults.copyWith(theme: ClayThemeMode.dark);
      final c = A11yController(store: store);
      await c.load();
      expect(c.settings.theme, ClayThemeMode.dark);
    });

    test('sync on: pushes only the changed keys and ends synced', () async {
      final sync = FakeSync();
      final c = A11yController(store: MemoryStore(), sync: sync);
      await c.load();
      await c.update(c.settings.copyWith(dyslexiaFont: true));
      expect(sync.pushes, [
        {'dyslexia_font': true}
      ]);
      expect(c.syncState, A11ySyncState.synced);
    });

    test('offline changes queue, survive a restart and replay', () async {
      final store = MemoryStore();
      final sync = FakeSync()..online = false;
      var c = A11yController(store: store, sync: sync);
      await c.load();
      await c.update(c.settings.copyWith(textSize: 2));
      await c.update(c.settings.copyWith(reduceMotion: true));
      expect(c.syncState, A11ySyncState.failed);
      expect(store.pending, {'text_size': 2, 'reduce_motion': true});

      // New controller (app restart) with the connection back.
      sync.online = true;
      c = A11yController(store: store, sync: sync);
      await c.load();
      expect(c.settings.textSize, 2);
      await c.onSignedIn();
      expect(sync.pushes.single, {'text_size': 2, 'reduce_motion': true});
      expect(store.pending, isEmpty);
      expect(c.syncState, A11ySyncState.synced);
    });

    test('last write wins: the stored row from the server is applied',
        () async {
      final sync = FakeSync();
      final c = A11yController(store: MemoryStore(), sync: sync);
      await c.load();
      await c.update(c.settings.copyWith(textSize: 1));
      sync.remote = sync.remote.copyWith(textSize: 3);
      await c.update(c.settings.copyWith(lineSpacing: 1));
      expect(c.settings.textSize, 3);
      expect(c.settings.lineSpacing, 1);
    });

    test('sign in: account settings replace local ones', () async {
      final store = MemoryStore();
      final sync = FakeSync(
        updatedAt: DateTime(2026, 10, 1),
        remote: A11ySettings.defaults.copyWith(theme: ClayThemeMode.contrast),
      );
      var signedIn = false;
      final c = A11yController(
          store: store, sync: sync, canSync: () => signedIn);
      await c.load();
      await c.update(c.settings.copyWith(textSize: 1)); // before login
      expect(sync.pushes, isEmpty);
      signedIn = true;
      await c.onSignedIn();
      expect(c.settings.theme, ClayThemeMode.contrast);
      expect(c.settings.textSize, 0);
      expect(store.etag, 'W/"1"');
    });

    test('sign in: account with no saved row gets this device choices',
        () async {
      final store = MemoryStore()
        ..settings = A11ySettings.defaults.copyWith(simpleView: true);
      final sync = FakeSync(updatedAt: null);
      final c = A11yController(store: store, sync: sync);
      await c.load();
      await c.onSignedIn();
      expect(sync.pushes.single, {'simple_view': true});
    });

    test('403 (parent or teacher) turns server sync off quietly', () async {
      final sync = FakeSync()..forbidden = true;
      final c = A11yController(store: MemoryStore(), sync: sync);
      await c.load();
      await c.onSignedIn();
      await c.update(c.settings.copyWith(textSize: 1));
      expect(c.syncState, A11ySyncState.localOnly);
      expect(c.settings.textSize, 1);
    });

    test('canSync false (not a student) never calls the server', () async {
      final sync = FakeSync();
      final c =
          A11yController(store: MemoryStore(), sync: sync, canSync: () => false);
      await c.load();
      await c.update(c.settings.copyWith(textSize: 1));
      expect(sync.pushes, isEmpty);
    });

    test('sign out drops the queue and etag but keeps the settings',
        () async {
      final store = MemoryStore();
      final sync = FakeSync()..online = false;
      final c = A11yController(store: store, sync: sync);
      await c.load();
      await c.update(c.settings.copyWith(textSize: 2));
      store.etag = 'x';
      await c.onSignedOut();
      expect(store.pending, isEmpty);
      expect(store.etag, isNull);
      expect(c.settings.textSize, 2);
    });

    test('soundsAllowed follows mute_sounds', () async {
      final c = A11yController(store: MemoryStore());
      await c.load();
      expect(c.soundsAllowed, isTrue);
      await c.update(c.settings.copyWith(muteSounds: true));
      expect(c.soundsAllowed, isFalse);
    });
  });

  group('RemoteA11ySync against the App API v1 contract', () {
    Dio dioWith(ScriptedAdapter a) =>
        Dio(BaseOptions(baseUrl: 'https://x.test/api/app/v1'))
          ..httpClientAdapter = a;

    test('GET parses data.settings and updated_at, returns the ETag',
        () async {
      final a = ScriptedAdapter((o) => json({
            'success': true,
            'data': {
              'settings': {'text_size': 2, 'theme': 'dark', 'read_lang': 'sw'},
              'updated_at': '2026-10-13T10:00:00+03:00',
            }
          }, h: {
            'etag': ['W/"abc"']
          }));
      final pull = await RemoteA11ySync(dioWith(a)).pull();
      expect(a.seen.single.method, 'GET');
      expect(a.seen.single.path, '/me/accessibility');
      expect(pull.settings!.textSize, 2);
      expect(pull.settings!.theme, ClayThemeMode.dark);
      expect(pull.settings!.readLang, A11yReadLang.sw);
      expect(pull.updatedAt, isNotNull);
      expect(pull.etag, 'W/"abc"');
    });

    test('GET sends If-None-Match and treats 304 as not modified', () async {
      final a = ScriptedAdapter((o) => ResponseBody.fromString('', 304));
      final pull = await RemoteA11ySync(dioWith(a)).pull(etag: 'W/"abc"');
      expect(a.seen.single.headers['If-None-Match'], 'W/"abc"');
      expect(pull.notModified, isTrue);
    });

    test('updated_at null means the account never saved', () async {
      final a = ScriptedAdapter((o) => json({
            'success': true,
            'data': {'settings': {}, 'updated_at': null}
          }));
      final pull = await RemoteA11ySync(dioWith(a)).pull();
      expect(pull.updatedAt, isNull);
      expect(pull.settings, A11ySettings.defaults);
    });

    test('PUT sends the partial body and returns the full stored settings',
        () async {
      final a = ScriptedAdapter((o) => json({
            'success': true,
            'data': {
              'settings': {'text_size': 1, 'mute_sounds': true},
              'updated_at': '2026-10-13T10:00:00+03:00',
            }
          }));
      final stored =
          await RemoteA11ySync(dioWith(a)).push({'mute_sounds': true});
      expect(a.seen.single.method, 'PUT');
      expect(a.seen.single.data, {'mute_sounds': true});
      expect(stored.muteSounds, isTrue);
      expect(stored.textSize, 1);
    });

    test('403 maps to A11ySyncForbidden, other errors rethrow', () async {
      final forbidden = ScriptedAdapter((o) =>
          json({'success': false, 'message': 'Forbidden'}, status: 403));
      await expectLater(RemoteA11ySync(dioWith(forbidden)).pull(),
          throwsA(isA<A11ySyncForbidden>()));
      await expectLater(RemoteA11ySync(dioWith(forbidden)).push({'x': 1}),
          throwsA(isA<A11ySyncForbidden>()));

      final limited = ScriptedAdapter((o) =>
          json({'success': false, 'message': 'Too many'}, status: 429));
      await expectLater(
          RemoteA11ySync(dioWith(limited)).push({}), throwsA(isA<DioException>()));
    });
  });

  group('speech', () {
    test('language candidates: en-KE and sw-KE first, fallbacks after', () {
      final en = A11ySettings.defaults.copyWith(readLang: A11yReadLang.en);
      final sw = A11ySettings.defaults.copyWith(readLang: A11yReadLang.sw);
      expect(speechLanguageCandidates(en, null).first, 'en-KE');
      expect(speechLanguageCandidates(sw, null).first, 'sw-KE');
      expect(speechLanguageCandidates(sw, null).last, 'sw');
    });

    test('auto follows the app locale', () {
      const auto = A11ySettings.defaults;
      expect(speechLanguageCandidates(auto, const Locale('sw')).first, 'sw-KE');
      expect(speechLanguageCandidates(auto, const Locale('en')).first, 'en-KE');
      expect(speechLanguageCandidates(auto, null).first, 'en-KE');
    });

    test('web speed maps onto the engine rate', () {
      expect(speechRateFor(1.0), 0.5);
      expect(speechRateFor(0.7), closeTo(0.35, 0.001));
      expect(speechRateFor(1.5), closeTo(0.75, 0.001));
    });
  });

  group('A11yPanel', () {
    Widget host(A11yController c, FakeSpeech speech, {double scale = 1.0}) {
      final nav = GlobalKey<NavigatorState>();
      return MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: c),
          Provider<SpeechService>.value(value: speech),
        ],
        child: Consumer<A11yController>(
          builder: (context, ctl, _) => MaterialApp(
            navigatorKey: nav,
            theme: ClayTheme.build(ctl.settings.toThemeOptions()),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: A11yHost(navigatorKey: nav, child: child!),
            ),
            home: Scaffold(
              appBar: const ClayAppBar(title: 'Home'),
              body: const SizedBox(),
            ),
          ),
        ),
      );
    }

    testWidgets('app bar action opens the panel; toggles change the theme',
        (tester) async {
      final semantics = tester.ensureSemantics();
      setPhone(tester);
      final c = A11yController(store: MemoryStore());
      await c.load();
      await tester.pumpWidget(host(c, FakeSpeech()));
      await tester.tap(find.bySemanticsLabel('Accessibility settings'));
      await tester.pumpAndSettle();
      expect(find.text('Read aloud'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Dark, tab 2 of 3'));
      await tester.pumpAndSettle();
      expect(c.settings.theme, ClayThemeMode.dark);

      await tester.ensureVisible(find.bySemanticsLabel('Reduce motion, off'));
      await tester.tap(find.bySemanticsLabel('Reduce motion, off'));
      await tester.pumpAndSettle();
      expect(c.settings.reduceMotion, isTrue);
      expect(find.bySemanticsLabel('Reduce motion, on'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('every control is labelled and 48 dp', (tester) async {
      final semantics = tester.ensureSemantics();
      setPhone(tester);
      final c = A11yController(store: MemoryStore());
      await c.load();
      await tester.pumpWidget(host(c, FakeSpeech()));
      await tester.tap(find.bySemanticsLabel('Accessibility settings'));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });

    testWidgets('test voice speaks and shows a notice when no voice exists',
        (tester) async {
      setPhone(tester);
      final c = A11yController(store: MemoryStore());
      await c.load();
      final speech = FakeSpeech()..result = SpeakResult.noVoice;
      await tester.pumpWidget(host(c, speech));
      await tester.tap(find.bySemanticsLabel('Accessibility settings'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Test voice'));
      await tester.tap(find.text('Test voice'));
      await tester.pumpAndSettle();
      expect(speech.spoken, hasLength(1));
      expect(find.textContaining('No voice'), findsOneWidget);
    });

    testWidgets('reset to defaults is disabled until something changed',
        (tester) async {
      setPhone(tester);
      final c = A11yController(store: MemoryStore());
      await c.load();
      await tester.pumpWidget(host(c, FakeSpeech()));
      await tester.tap(find.bySemanticsLabel('Accessibility settings'));
      await tester.pumpAndSettle();
      await c.update(c.settings.copyWith(textSize: 2));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Reset to defaults'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset to defaults'));
      await tester.pumpAndSettle();
      expect(c.settings, A11ySettings.defaults);
    });

    for (final scale in clayScales) {
      testWidgets('panel does not overflow at text scale $scale',
          (tester) async {
        setPhone(tester);
        final c = A11yController(store: MemoryStore());
        await c.load();
        await tester.pumpWidget(host(c, FakeSpeech(), scale: scale));
        await tester.tap(find.bySemanticsLabel('Accessibility settings'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('A11yHost', () {
    testWidgets('multiplies the OS text scale by the user step, capped at 2.0',
        (tester) async {
      setPhone(tester);
      final c = A11yController(store: MemoryStore());
      await c.load();
      double? seen;
      final nav = GlobalKey<NavigatorState>();

      Future<void> pump(double os) => tester.pumpWidget(
            ChangeNotifierProvider.value(
              value: c,
              child: MaterialApp(
                navigatorKey: nav,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(os)),
                  child: A11yHost(navigatorKey: nav, child: child!),
                ),
                home: Builder(builder: (context) {
                  seen = MediaQuery.textScalerOf(context).scale(1);
                  return const SizedBox();
                }),
              ),
            ),
          );

      await pump(1.0);
      expect(seen, 1.0);
      await c.update(c.settings.copyWith(textSize: 2));
      await pump(1.0);
      expect(seen, closeTo(1.3, 0.001));
      await pump(1.5);
      expect(seen, closeTo(1.95, 0.001));
      await c.update(c.settings.copyWith(textSize: 3));
      await pump(1.5);
      expect(seen, 2.0);
    });

    testWidgets('SimpleView reflects the setting', (tester) async {
      setPhone(tester);
      final c = A11yController(store: MemoryStore());
      await c.load();
      await c.update(c.settings.copyWith(simpleView: true));
      final nav = GlobalKey<NavigatorState>();
      bool? simple;
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: c,
        child: MaterialApp(
          navigatorKey: nav,
          builder: (context, child) =>
              A11yHost(navigatorKey: nav, child: child!),
          home: Builder(builder: (context) {
            simple = SimpleView.of(context);
            return const SizedBox();
          }),
        ),
      ));
      expect(simple, isTrue);
    });
  });

  group('ReadAloud', () {
    testWidgets('Listen reads the given text with the user settings',
        (tester) async {
      setPhone(tester);
      final c = A11yController(store: MemoryStore());
      await c.load();
      final speech = FakeSpeech();
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: c),
          Provider<SpeechService>.value(value: speech),
        ],
        child: MaterialApp(
          theme: ClayTheme.build(),
          home: const Scaffold(
            body: ReadAloud(text: 'Lesson one', child: Text('Lesson one')),
          ),
        ),
      ));
      await tester.tap(find.byTooltip('Listen'));
      await tester.pump();
      expect(speech.spoken, ['Lesson one']);
    });
  });
}
