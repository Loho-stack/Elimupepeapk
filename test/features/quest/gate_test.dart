import 'package:dio/dio.dart';
import 'package:elimupepe/core/network/api_exception.dart';
import 'package:elimupepe/core/webview/webview_policy.dart';
import 'package:elimupepe/data/api_error.dart';
import 'package:elimupepe/data/models/msafara.dart';
import 'package:elimupepe/features/quest/countdown_page.dart';
import 'package:elimupepe/features/quest/profile_page.dart';
import 'package:elimupepe/features/quest/quest_gate.dart';
import 'package:elimupepe/features/quest/quest_strings.dart';
import 'package:elimupepe/features/quest/terms_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import 'support.dart';

void main() {
  setUpAll(loadClayFonts);

  group('copy', () {
    test('English and Kiswahili have the same keys', () {
      expect(QuestStrings.sw.ownKeys.toSet(), QuestStrings.en.ownKeys.toSet());
    });

    test('seat count uses the singular for one', () {
      expect(QuestStrings.en.seats(1), '1 learner has reserved a seat');
      expect(QuestStrings.en.seats(18423), '18,423 learners have reserved a seat');
      expect(QuestStrings.sw.seats(1), 'Mwanafunzi 1 amehifadhi kiti');
    });

    test('the device language picks sw, else en', () {
      expect(QuestStrings.fromLocale('sw'), 'sw');
      expect(QuestStrings.fromLocale('fr'), 'en');
      expect(QuestStrings.fromLocale(null), 'en');
    });
  });

  test('the web fallback path passes the webview policy', () {
    expect(WebviewPolicy.isSafeIntendedPath('/msafara'), isTrue);
  });

  group('MsafaraSession', () {
    test('the countdown runs on the server seconds and the monotonic clock', () async {
      final rig = QuestRig((o) => ok('state_countdown'));
      await rig.session.refresh();
      expect(rig.session.secondsToStart, 10549);
      rig.clock.elapsed = const Duration(seconds: 49);
      expect(rig.session.secondsToStart, 10500);
      rig.clock.elapsed = const Duration(hours: 5);
      expect(rig.session.secondsToStart, 0);
    });

    test('a 404 on state means the website', () async {
      final rig = QuestRig((o) => jsonBody({'success': false, 'message': 'x'}, status: 404));
      await rig.session.refresh();
      expect(rig.session.useWebFallback, isTrue);
      expect(rig.session.error, isNull);
    });

    test('stage disabled means the website', () async {
      final rig = QuestRig((o) => ok('state_disabled'));
      await rig.session.refresh();
      expect(rig.session.useWebFallback, isTrue);
    });

    test('remote config off means the website, without asking the API', () async {
      final rig = QuestRig((o) => ok('state_countdown'), remoteEnabled: () async => false);
      await rig.session.start();
      expect(rig.session.useWebFallback, isTrue);
      expect(rig.adapter.seen, isEmpty);
    });

    test('unknown remote config counts as enabled', () async {
      final rig = QuestRig((o) => ok('state_countdown'), remoteEnabled: () async => null);
      await rig.session.start();
      expect(rig.session.useWebFallback, isFalse);
      expect(rig.session.state!.stage, QuestStage.countdown);
    });

    test('an offline failure keeps the error for a retry', () async {
      final rig = QuestRig((o) => throw DioException(requestOptions: o, error: const OfflineException()));
      await rig.session.refresh();
      expect(rig.session.error, isNotNull);
      expect(rig.session.state, isNull);
    });

    test('every 409 gate routes back through a state refresh', () async {
      for (final code in ['not_started', 'terms_required', 'profile_required']) {
        final rig = QuestRig((o) => ok('state_active'));
        final handled = rig.session.handleError(MsafaraGateError(code: code));
        expect(handled, isTrue, reason: code);
        await rig.session.refreshing;
        expect(rig.calls('GET', '/msafara/state'), hasLength(1), reason: code);
      }
      final rig = QuestRig((o) => ok('state_active'));
      expect(rig.session.handleError(const OfflineError()), isFalse);
    });
  });

  group('QuestGate', () {
    Widget gateFor(QuestRig rig, {List<String>? log, double scale = 1.0}) => screenApp(
          QuestGate(
            session: rig.session,
            onReserve: () => log?.add('reserve'),
            onProfile: () => log?.add('profile'),
            activeBuilder: (_) => const Scaffold(body: Text('HOME')),
            fallbackBuilder: (_) => const Scaffold(body: Text('WEB')),
          ),
          textScale: scale,
        );

    testWidgets('countdown, seat open: reserve leads to the terms', (tester) async {
      setPhone(tester);
      final log = <String>[];
      final rig = QuestRig((o) => ok('state_terms'));
      await loadState(tester, rig);
      await tester.pumpWidget(gateFor(rig, log: log));
      await settle(tester);

      expect(find.byType(CountdownPage), findsOneWidget);
      expect(find.text('The matatu is at the stage'), findsOneWidget);
      expect(find.text('18,423 learners have reserved a seat'), findsOneWidget);
      expect(find.text('Leaves 19 Oct 2026 at midnight'), findsOneWidget);
      await tester.tap(find.text('Reserve your seat').last);
      expect(log, ['reserve']);
    });

    testWidgets('countdown with the terms accepted asks for the profile', (tester) async {
      setPhone(tester);
      final log = <String>[];
      final j = data('state_countdown')..['seat'] = 'profile';
      final rig = QuestRig((o) => jsonBody({'success': true, 'data': j}));
      await loadState(tester, rig);
      await tester.pumpWidget(gateFor(rig, log: log));
      await settle(tester);

      await tester.tap(find.text('Choose grade and county'));
      expect(log, ['profile']);
    });

    testWidgets('countdown, seat reserved: no button, the date is shown', (tester) async {
      setPhone(tester);
      final rig = QuestRig((o) => ok('state_countdown'));
      await loadState(tester, rig);
      await tester.pumpWidget(gateFor(rig));
      await settle(tester);

      expect(find.text('Seat reserved'), findsOneWidget);
      expect(find.text('Your seat is waiting. Come back on 19 Oct 2026 to unlock your first town.'), findsOneWidget);
      expect(find.text('Reserve your seat'), findsNothing);
    });

    testWidgets('the clock ticks and says it once a minute to a screen reader', (tester) async {
      setPhone(tester);
      final semantics = tester.ensureSemantics();
      final rig = QuestRig((o) => ok('state_countdown'));
      await loadState(tester, rig);
      await tester.pumpWidget(gateFor(rig));
      await settle(tester);

      // 10549 s = 0 days 02:55:49
      expect(find.text('55'), findsOneWidget);
      expect(find.text('49'), findsOneWidget);
      expect(find.bySemanticsLabel('0 days, 2 hours and 55 minutes to go'), findsOneWidget);

      rig.clock.elapsed = const Duration(seconds: 5);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('44'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('at zero it asks the server what the learner sees now', (tester) async {
      setPhone(tester);
      var calls = 0;
      final rig = QuestRig((o) {
        calls++;
        return calls == 1 ? ok('state_countdown') : ok('state_active');
      });
      await loadState(tester, rig);
      await tester.pumpWidget(gateFor(rig));
      await settle(tester);

      rig.clock.elapsed = const Duration(hours: 3);
      await tester.pump(const Duration(seconds: 1));
      await settle(tester);
      expect(find.text('HOME'), findsOneWidget);
      expect(calls, 2);
    });

    testWidgets('a 404 shows the website', (tester) async {
      setPhone(tester);
      final rig = QuestRig((o) => jsonBody({'success': false, 'message': 'x'}, status: 404));
      await loadState(tester, rig);
      await tester.pumpWidget(gateFor(rig));
      expect(find.text('WEB'), findsOneWidget);
    });

    testWidgets('offline on the first load shows a retry', (tester) async {
      setPhone(tester);
      var offline = true;
      final rig = QuestRig((o) => offline ? throw DioException(requestOptions: o, error: const OfflineException()) : ok('state_active'));
      await loadState(tester, rig);
      await tester.pumpWidget(gateFor(rig));
      await settle(tester);
      expect(find.text('You are offline'), findsOneWidget);

      offline = false;
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('stage terms and profile show their forms inside the gate', (tester) async {
      setPhone(tester);
      var stage = 'terms';
      final rig = QuestRig((o) => switch (o.path) {
            '/msafara/state' => jsonBody({'success': true, 'data': data('state_active')..['stage'] = stage}),
            '/msafara/terms' => ok('terms'),
            _ => ok('profile'),
          });
      await loadState(tester, rig);
      await tester.pumpWidget(gateFor(rig));
      await settle(tester);
      expect(find.byType(TermsPage), findsOneWidget);

      stage = 'profile';
      await loadState(tester, rig);
      await settle(tester); // builds the page, which starts its request
      await settle(tester); // lets that request finish
      expect(find.byType(ProfilePage), findsOneWidget);
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('countdown at 360 dp, text x$scale, has no overflow and 48 dp targets', (tester) async {
        final semantics = tester.ensureSemantics();
        setPhone(tester);
        final rig = QuestRig((o) => ok('state_terms'));
        await loadState(tester, rig);
        await tester.pumpWidget(gateFor(rig, scale: scale));
        await settle(tester);
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
      });
    }

    testWidgets('reduced motion: no entrance animation is built', (tester) async {
      setPhone(tester);
      final rig = QuestRig((o) => ok('state_terms'));
      await loadState(tester, rig);
      await tester.pumpWidget(Builder(
        builder: (context) => MediaQuery(
          data: MediaQueryData(disableAnimations: true, size: tester.view.physicalSize),
          child: gateFor(rig),
        ),
      ));
      await tester.pump();
      expect(find.text('The matatu is at the stage'), findsOneWidget);
      expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
    });

    testWidgets('with motion allowed the cards rise in', (tester) async {
      setPhone(tester);
      final rig = QuestRig((o) => ok('state_terms'));
      await loadState(tester, rig);
      await tester.pumpWidget(gateFor(rig));
      await tester.pump();
      expect(find.byType(TweenAnimationBuilder<double>), findsWidgets);
    });
  });
}
