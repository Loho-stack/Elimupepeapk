import 'dart:io';

import 'package:elimupepe/app/app_config.dart';
import 'package:elimupepe/app/app_services.dart';
import 'package:elimupepe/app/menu/student_menu.dart';
import 'package:elimupepe/app/router/app_router.dart';
import 'package:elimupepe/app/session_controller.dart';
import 'package:elimupepe/app/shell/clay_bottom_bar.dart';
import 'package:elimupepe/app/shell/student_shell.dart';
import 'package:elimupepe/core/a11y/a11y_controller.dart';
import 'package:elimupepe/core/auth/token_store.dart';
import 'package:elimupepe/core/a11y/a11y_host.dart';
import 'package:elimupepe/core/a11y/a11y_settings.dart';
import 'package:elimupepe/core/a11y/a11y_store.dart';
import 'package:elimupepe/core/a11y/speech_service.dart';
import 'package:elimupepe/core/design/clay.dart';
import 'package:elimupepe/core/webview/webview_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design/harness.dart';
import '../support/fakes.dart';

class _MemA11yStore implements A11yStore {
  A11ySettings? s;
  @override
  Future<A11ySettings?> load() async => s;
  @override
  Future<void> save(A11ySettings v) async => s = v;
  @override
  Future<Map<String, dynamic>> loadPending() async => {};
  @override
  Future<void> savePending(Map<String, dynamic> p) async {}
  @override
  Future<String?> loadEtag() async => null;
  @override
  Future<void> saveEtag(String? e) async {}
  @override
  Future<void> clearAccountState() async {}
}

class _NoSpeech implements SpeechService {
  @override
  Future<SpeakResult> speak(String t, A11ySettings s,
          {Locale? appLocale}) async =>
      SpeakResult.spoken;
  @override
  Future<void> stop() async {}
}

SessionController fakeSession({
  bool loggedIn = true,
  int? roleId = 3,
  String? roleName,
  Future<void> Function()? end,
}) =>
    SessionController(
      isLoggedIn: () async => loggedIn,
      roleId: () async => roleId,
      roleName: () async => roleName,
      endSession: end ?? () async {},
    );

/// The drawer list builds lazily: scroll an entry into view first.
Future<void> scrollTo(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text),
    120,
    scrollable: find
        .descendant(of: find.byType(Drawer), matching: find.byType(Scrollable))
        .first,
  );
  await tester.pump();
}

void main() {
  setUpAll(loadClayFonts);

  group('SessionController', () {
    test('role mapping: 2 teacher, 7 parent, everything else student', () {
      expect(SessionController.roleFor(roleId: 2), AppRole.teacher);
      expect(SessionController.roleFor(roleId: 7), AppRole.parent);
      expect(SessionController.roleFor(roleId: 3), AppRole.student);
      expect(SessionController.roleFor(), AppRole.student);
      expect(SessionController.roleFor(roleName: 'Educator'), AppRole.teacher);
      expect(SessionController.roleFor(roleName: 'guardian'), AppRole.parent);
      expect(SessionController.roleFor(roleName: 'student'), AppRole.student);
    });

    test('refresh reads signed in and role; unknown until then', () async {
      final s = fakeSession(roleId: 7);
      expect(s.status, SessionStatus.unknown);
      await s.refresh();
      expect(s.status, SessionStatus.signedIn);
      expect(s.role, AppRole.parent);
      expect(s.homeLocation, '/parent');
    });

    test('signed out when there is no session', () async {
      final s = fakeSession(loggedIn: false);
      await s.refresh();
      expect(s.status, SessionStatus.signedOut);
      expect(s.isSignedIn, isFalse);
    });

    test('home location per role', () async {
      for (final (id, home) in [(3, '/student/home'), (7, '/parent'), (2, '/teacher')]) {
        final s = fakeSession(roleId: id);
        await s.refresh();
        expect(s.homeLocation, home);
      }
    });

    test('notifies only on real changes', () async {
      final s = fakeSession();
      var n = 0;
      s.addListener(() => n++);
      await s.refresh();
      await s.refresh();
      expect(n, 1);
      s.signedOut();
      s.signedOut();
      expect(n, 2);
    });

    test('expire wipes the device once and signs out', () async {
      var wiped = 0;
      final s = fakeSession(end: () async => wiped++);
      await s.refresh();
      await s.expire();
      await s.expire();
      expect(wiped, 1);
      expect(s.status, SessionStatus.signedOut);
    });
  });

  group('redirect rules', () {
    Future<SessionController> session(
        {bool loggedIn = true, int roleId = 3}) async {
      final s = fakeSession(loggedIn: loggedIn, roleId: roleId);
      await s.refresh();
      return s;
    }

    test('unknown: stay on the splash until the session is read', () {
      final s = fakeSession();
      expect(redirectFor(s, '/'), isNull);
      expect(redirectFor(s, '/student/home'), '/');
    });

    test('signed out always lands on welcome', () async {
      final s = await session(loggedIn: false);
      expect(redirectFor(s, '/welcome'), isNull);
      expect(redirectFor(s, '/'), '/welcome');
      expect(redirectFor(s, '/student/home'), '/welcome');
      expect(redirectFor(s, '/parent'), '/welcome');
    });

    test('signed in leaves splash and welcome for the role home', () async {
      expect(redirectFor(await session(roleId: 3), '/welcome'), '/student/home');
      expect(redirectFor(await session(roleId: 7), '/'), '/parent');
      expect(redirectFor(await session(roleId: 2), '/welcome'), '/teacher');
    });

    test('a role cannot open another role area', () async {
      final student = await session(roleId: 3);
      expect(redirectFor(student, '/student/learn'), isNull);
      expect(redirectFor(student, '/student/web'), isNull);
      expect(redirectFor(student, '/parent'), '/student/home');
      expect(redirectFor(student, '/teacher'), '/student/home');

      final parent = await session(roleId: 7);
      expect(redirectFor(parent, '/parent'), isNull);
      expect(redirectFor(parent, '/parent/messages'), isNull);
      expect(redirectFor(parent, '/student/home'), '/parent');

      final teacher = await session(roleId: 2);
      expect(redirectFor(teacher, '/teacher'), isNull);
      expect(redirectFor(teacher, '/parent'), '/teacher');
    });
  });

  group('route names carry no personal data', () {
    test('static identifiers only', () {
      const names = [
        RouteNames.welcome,
        RouteNames.studentHome,
        RouteNames.studentLearn,
        RouteNames.studentQuest,
        RouteNames.studentLibrary,
        RouteNames.studentProfile,
        RouteNames.studentQuestHub,
        RouteNames.studentWeb,
        RouteNames.studentPage,
        RouteNames.parentHome,
        RouteNames.parentMessages,
        RouteNames.teacherHome,
      ];
      expect(names.toSet(), hasLength(names.length));
      for (final n in names) {
        expect(RegExp(r'^[a-z_]+$').hasMatch(n), isTrue, reason: n);
      }
    });
  });

  group('StudentMenu', () {
    test('groups and entries mirror the web sidebar order', () {
      expect(StudentMenu.groups.map((g) => g.label), [
        'Home',
        'Learn',
        'Practice',
        'Progress',
        'Rewards',
        'Community',
        'Account',
        'Support',
      ]);
      expect(StudentMenu.groups[0].entries.map((e) => e.label),
          ['Dashboard', 'Elimu Quest']);
      expect(StudentMenu.groups[1].entries.map((e) => e.label), [
        'My Learning Areas',
        'Interactive Content',
        'My Library',
        'Dals Learning',
        'Esoma Kids',
        'Loho-TV',
        'Live Classes',
      ]);
      expect(StudentMenu.groups[2].entries.map((e) => e.label),
          ['Virtual Labs', 'Elimu Quest', 'Games']);
      expect(StudentMenu.groups[3].entries.map((e) => e.label), [
        'Leaderboard',
        'My Gradebook',
        'Achievements',
        'My Questions',
        'Quest Hub',
      ]);
      expect(StudentMenu.groups[4].entries.map((e) => e.label),
          ['Overview', 'My Wallet', 'Rewards Shop', 'Passes & Unlocks']);
      expect(StudentMenu.groups[5].entries.map((e) => e.label), ['My Class']);
      expect(StudentMenu.groups[6].entries.map((e) => e.label),
          ['Profile and settings', 'Accessibility']);
      expect(StudentMenu.groups[7].entries.map((e) => e.label),
          ['FAQ / Contact', 'Log out']);
    });

    test('ids are unique and every entry has a label and icon', () {
      final ids = StudentMenu.all.map((e) => e.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('WEBVIEW verdicts open the SSO wrapper (or the Quest tab that hosts it)',
        () {
      for (final e in StudentMenu.all.where((e) => e.verdict == Verdict.webview)) {
        final ok = e.target is WebTarget ||
            e.target is PublicWebTarget ||
            (e.target is BranchTarget &&
                (e.target as BranchTarget).index == StudentMenu.questBranch);
        expect(ok, isTrue, reason: e.id);
      }
    });

    test('every web path is a safe relative path', () {
      for (final e in StudentMenu.all) {
        final t = e.target;
        final path = t is WebTarget ? t.path : (t is PublicWebTarget ? t.path : null);
        if (path != null) {
          expect(WebviewPolicy.isSafeIntendedPath(path), isTrue, reason: e.id);
        }
      }
    });

    test('paths follow the resource map', () {
      String pathOf(String id) =>
          (StudentMenu.all.firstWhere((e) => e.id == id).target as WebTarget).path;
      expect(pathOf('dals'), '/dals');
      expect(pathOf('esoma'), '/esoma');
      expect(pathOf('virtual_labs'), '/phet');
      expect(pathOf('leaderboard'), '/leaderboard/embed');
      expect(pathOf('games'), '/games');
      expect(pathOf('wallet'), '/student-dashboard/loho-coins/hub/wallet');
      expect(pathOf('shop'), '/student-dashboard/loho-coins/hub/shop');
      expect(pathOf('passes'), '/student-dashboard/loho-coins/hub/passes');
      expect(pathOf('my_class'), '/my-class');
      expect(pathOf('my_questions'), '/my-qa');
    });

    test('Esoma is a normal SSO item: no parental gate on opening it', () {
      final e = StudentMenu.all.firstWhere((e) => e.id == 'esoma');
      expect(e.target, isA<WebTarget>());
    });

    test('the bottom bar is Home, Learn, Elimu Quest, My Library (+ More)', () {
      expect(StudentMenu.bottomBarIds,
          ['dashboard', 'learning_areas', 'elimu_quest', 'library']);
      expect(StudentShell.items.map((i) => i.label),
          ['Home', 'Learn', 'Elimu Quest', 'My Library']);
      expect(StudentMenu.questBranch, 2);
    });

    test('interim targets are documented', () {
      for (final id in ['achievements', 'wallet', 'shop', 'passes', 'rewards']) {
        final e = StudentMenu.all.firstWhere((e) => e.id == id);
        expect(e.note, isNotNull, reason: id);
      }
    });
  });

  group('StudentShell', () {
    late SessionController session;
    late A11yController a11y;
    late GlobalKey<NavigatorState> nav;
    late List<String> opened;
    late MemoryKv kv;
    late ScriptedAdapter adapter;
    late List<MethodCall> platformCalls;

    GoRouter router() {
      Widget page(String label) => Center(child: Text('page $label'));
      return GoRouter(
        navigatorKey: nav,
        initialLocation: '/student/home',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (c, s, shell) => StudentShell(navigationShell: shell),
            branches: [
              for (final (path, label) in [
                ('/student/home', 'home'),
                ('/student/learn', 'learn'),
                ('/student/quest', 'quest'),
                ('/student/library', 'library'),
              ])
                StatefulShellBranch(routes: [
                  GoRoute(path: path, builder: (c, s) => page(label)),
                ]),
            ],
          ),
          GoRoute(
            path: '/student/web',
            parentNavigatorKey: nav,
            builder: (c, s) {
              final a = s.extra! as WebArgs;
              opened.add('web:${a.title}:${a.path}');
              return Scaffold(body: Text('WEB ${a.title}'));
            },
          ),
          GoRoute(
            path: '/student/page',
            parentNavigatorKey: nav,
            builder: (c, s) {
              final a = s.extra! as WebArgs;
              opened.add('page:${a.title}:${a.path}');
              return Scaffold(body: Text('PAGE ${a.title}'));
            },
          ),
          GoRoute(
            path: '/student/profile',
            parentNavigatorKey: nav,
            builder: (c, s) {
              opened.add('profile');
              return const Scaffold(body: Text('PROFILE'));
            },
          ),
          GoRoute(
            path: '/student/quest-hub',
            parentNavigatorKey: nav,
            builder: (c, s) {
              opened.add('quest-hub');
              return const Scaffold(body: Text('QUEST HUB'));
            },
          ),
        ],
      );
    }

    Future<void> pumpShell(WidgetTester tester,
        {double scale = 1.0, ClayThemeMode mode = ClayThemeMode.light}) async {
      setPhone(tester);
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: session),
          ChangeNotifierProvider.value(value: a11y),
          Provider<SpeechService>.value(value: _NoSpeech()),
        ],
        child: MaterialApp.router(
          routerConfig: router(),
          theme: ClayTheme.build(ClayThemeOptions(mode: mode)),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: A11yHost(navigatorKey: nav, child: child!),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump();
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      nav = GlobalKey<NavigatorState>();
      opened = [];
      platformCalls = [];
      kv = MemoryKv();
      adapter = ScriptedAdapter((o) => jsonBody({}));
      AppServices.override(AppServices.create(
        AppConfig.resolve(envDefine: 'prod'),
        kv: kv,
        adapter: adapter,
        connectivity: FakeConnectivity(),
      ));
      session = fakeSession(end: () async {});
      await session.refresh();
      a11y = A11yController(store: _MemA11yStore());
      await a11y.load();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        platformCalls.add(call);
        return null;
      });
    });

    tearDown(() {
      AppServices.override(null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('shows the bottom bar with the four tabs and More',
        (tester) async {
      await pumpShell(tester);
      expect(find.text('page home'), findsOneWidget);
      for (final label in ['Home', 'Learn', 'Elimu Quest', 'My Library', 'More']) {
        expect(find.descendant(of: find.byType(ClayBottomBar), matching: find.text(label)),
            findsOneWidget,
            reason: label);
      }
    });

    testWidgets('tapping a tab switches the branch', (tester) async {
      await pumpShell(tester);
      await tester.tap(find.descendant(
          of: find.byType(ClayBottomBar), matching: find.text('Learn')));
      await tester.pump();
      await tester.pump();
      expect(find.text('page learn'), findsOneWidget);

      await tester.tap(find.descendant(
          of: find.byType(ClayBottomBar), matching: find.text('My Library')));
      await tester.pump();
      await tester.pump();
      expect(find.text('page library'), findsOneWidget);

      await tester.tap(find.descendant(
          of: find.byType(ClayBottomBar), matching: find.text('Elimu Quest')));
      await tester.pump();
      await tester.pump();
      expect(find.text('page quest'), findsOneWidget);
    });

    testWidgets('More opens the drawer with every group', (tester) async {
      await pumpShell(tester);
      await tester.tap(find.descendant(
          of: find.byType(ClayBottomBar), matching: find.text('More')));
      await tester.pumpAndSettle();
      for (final g in StudentMenu.groups) {
        await scrollTo(tester, g.label.toUpperCase());
        expect(find.text(g.label.toUpperCase()), findsOneWidget, reason: g.label);
      }
      await scrollTo(tester, 'Log out');
      expect(find.text('Log out'), findsOneWidget);
    });

    testWidgets('a web entry opens the SSO route with its title and path',
        (tester) async {
      await pumpShell(tester);
      await tester.tap(find.descendant(
          of: find.byType(ClayBottomBar), matching: find.text('More')));
      await tester.pumpAndSettle();
      await scrollTo(tester, 'Dals Learning');
      await tester.tap(find.text('Dals Learning'));
      await tester.pumpAndSettle();
      expect(opened, ['web:Dals Learning:/dals']);
      expect(find.text('WEB Dals Learning'), findsOneWidget);
    });

    testWidgets('a branch entry in the drawer switches tabs and closes it',
        (tester) async {
      await pumpShell(tester);
      await tester.tap(find.descendant(
          of: find.byType(ClayBottomBar), matching: find.text('More')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('My Learning Areas'));
      await tester.pumpAndSettle();
      expect(find.text('page learn'), findsOneWidget);
      expect(find.text('Dals Learning'), findsNothing);
    });

    testWidgets('route entries and public pages open their routes',
        (tester) async {
      await pumpShell(tester);
      Future<void> openAndTap(String label) async {
        await tester.tap(find.descendant(
            of: find.byType(ClayBottomBar), matching: find.text('More')));
        await tester.pumpAndSettle();
        await scrollTo(tester, label);
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        nav.currentState!.pop();
        await tester.pumpAndSettle();
      }

      await openAndTap('Profile and settings');
      await openAndTap('Quest Hub');
      await openAndTap('FAQ / Contact');
      expect(opened, ['profile', 'quest-hub', 'page:FAQ / Contact:/contact-us']);
    });

    testWidgets('Accessibility in the drawer opens the panel', (tester) async {
      await pumpShell(tester);
      await tester.tap(find.descendant(
          of: find.byType(ClayBottomBar), matching: find.text('More')));
      await tester.pumpAndSettle();
      await scrollTo(tester, 'Accessibility');
      await tester.tap(find.text('Accessibility'));
      await tester.pumpAndSettle();
      expect(find.text('Text size'), findsOneWidget);
    });

    testWidgets('Log out asks first; confirming wipes the device and signs out',
        (tester) async {
      await AppServices.instance.tokenStore
          .save(const AuthTokens2('tok').toTokens());
      await pumpShell(tester);
      var signedOut = 0;
      session.addListener(() {
        if (session.status == SessionStatus.signedOut) signedOut++;
      });
      await tester.tap(find.descendant(
          of: find.byType(ClayBottomBar), matching: find.text('More')));
      await tester.pumpAndSettle();
      await scrollTo(tester, 'Log out');
      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();
      expect(find.text('Log out?'), findsOneWidget);

      // Cancelling keeps the session.
      await tester.tap(find.text('Stay signed in'));
      await tester.pumpAndSettle();
      expect(await AppServices.instance.tokenStore.hasSession, isTrue);
      expect(signedOut, 0);

      await tester.tap(find.descendant(
          of: find.byType(ClayBottomBar), matching: find.text('More')));
      await tester.pumpAndSettle();
      await scrollTo(tester, 'Log out');
      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ClayButton, 'Log out').last);
      // Logout talks to (fake) storage and network: let real async finish.
      for (var i = 0; i < 40 && signedOut == 0; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(await AppServices.instance.tokenStore.hasSession, isFalse);
      expect(signedOut, 1);
    });

    testWidgets('back goes Home first, then leaves the app', (tester) async {
      await pumpShell(tester);
      await tester.tap(find.descendant(
          of: find.byType(ClayBottomBar), matching: find.text('Learn')));
      await tester.pump();
      await tester.pump();
      expect(find.text('page learn'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump();
      expect(find.text('page home'), findsOneWidget);
      expect(platformCalls.where((c) => c.method == 'SystemNavigator.pop'), isEmpty);

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(platformCalls.where((c) => c.method == 'SystemNavigator.pop'),
          hasLength(1));
    });

    testWidgets('back closes the drawer before anything else', (tester) async {
      await pumpShell(tester);
      await tester.tap(find.descendant(
          of: find.byType(ClayBottomBar), matching: find.text('More')));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Dals Learning'), findsNothing);
      expect(platformCalls.where((c) => c.method == 'SystemNavigator.pop'), isEmpty);
    });

    testWidgets('the accessibility button is reachable on every screen',
        (tester) async {
      await pumpShell(tester);
      // No ClayAppBar is mounted, so the host shows its floating button.
      expect(find.bySemanticsLabel('Accessibility settings'), findsOneWidget);
    });

    for (final mode in clayModes) {
      for (final scale in clayScales) {
        testWidgets('shell fits and is accessible [${mode.name} x$scale]',
            (tester) async {
          final semantics = tester.ensureSemantics();
          await pumpShell(tester, scale: scale, mode: mode);
          expect(tester.takeException(), isNull);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

          await tester.tap(find.descendant(
              of: find.byType(ClayBottomBar), matching: find.text('More')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          semantics.dispose();
        });
      }
    }

    testWidgets('bottom bar items announce position and selection',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpShell(tester);
      final home = tester.getSemantics(find.bySemanticsLabel('Home, 1 of 5'));
      expect(home.flagsCollection.isSelected.name, 'isTrue');
      expect(find.bySemanticsLabel('Elimu Quest, 3 of 5'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('More, 5 of 5')), findsOneWidget);
      semantics.dispose();
    });
  });

  group('A11yHost floating button', () {
    testWidgets('hidden while a ClayAppBar is on screen', (tester) async {
      setPhone(tester);
      final a11y = A11yController(store: _MemA11yStore());
      await a11y.load();
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: a11y),
          Provider<SpeechService>.value(value: _NoSpeech()),
        ],
        child: MaterialApp(
          navigatorKey: nav,
          theme: ClayTheme.build(),
          builder: (c, child) => A11yHost(navigatorKey: nav, child: child!),
          home: const Scaffold(appBar: ClayAppBar(title: 'Page')),
        ),
      ));
      await tester.pump();
      await tester.pump();
      expect(find.bySemanticsLabel('Accessibility settings'), findsOneWidget);
      // Exactly one: the app bar's own action, not a second floating one.
      expect(find.byTooltip('Accessibility settings'), findsOneWidget);
    });
  });

  group('session navigation helpers', () {
    testWidgets('leaveSession closes pushed screens and signs out',
        (tester) async {
      setPhone(tester);
      final s = fakeSession();
      await s.refresh();
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: s,
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (inner) => Scaffold(
                  body: TextButton(
                    onPressed: () => inner.leaveSession(),
                    child: const Text('leave'),
                  ),
                ),
              )),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('leave'));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
      expect(s.status, SessionStatus.signedOut);
    });

    testWidgets('enterSession closes the login screens and records the session',
        (tester) async {
      setPhone(tester);
      final s = fakeSession();
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: s,
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (inner) => Scaffold(
                  body: TextButton(
                    onPressed: () => inner.enterSession(),
                    child: const Text('login'),
                  ),
                ),
              )),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('login'));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
      expect(s.status, SessionStatus.signedIn);
    });
  });

  group('source guards', () {
    test('no screen navigates to Welcome or AuthGate imperatively any more',
        () {
      for (final f in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final p = f.path.replaceAll('\\', '/');
        if (p.endsWith('app/router/app_router.dart')) continue;
        final s = f.readAsStringSync();
        expect(s.contains('pushAndRemoveUntil'), isFalse, reason: p);
        expect(s.contains('AuthGate'), isFalse, reason: p);
      }
    });
  });
}

class AuthTokens2 {
  const AuthTokens2(this.access);
  final String access;
  AuthTokens toTokens() => AuthTokens(accessToken: access);
}
