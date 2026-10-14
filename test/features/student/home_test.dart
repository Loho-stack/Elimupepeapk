import 'dart:async';

import 'package:elimupepe/core/design/clay.dart';
import 'package:elimupepe/data/api_error.dart';
import 'package:elimupepe/data/models/home.dart';
import 'package:elimupepe/features/student/home/home_page.dart';
import 'package:elimupepe/features/student/load_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

HomeData home(String fixture) => HomeData.fromJson(fixtureData(fixture));

class Taps {
  final lessons = <(int, int)>[];
  final areas = <int>[];
  final paths = <(String, String)>[];

  HomeActions get actions => HomeActions(
        openLesson: (c, l) => lessons.add((c, l)),
        openArea: areas.add,
        openPath: (t, p) => paths.add((t, p)),
      );
}

Future<LoadController<HomeData>> loaded(Future<HomeData> Function() fetch) async {
  final c = LoadController<HomeData>(fetch);
  await c.load();
  return c;
}

void main() {
  setUpAll(loadClayFonts);

  group('Home content, in the order of the web dashboard', () {
    testWidgets('shows every section from the fixture', (tester) async {
      setTallPhone(tester);
      final c = await loaded(() async => home('home'));
      await tester.pumpWidget(screenApp(StudentHomePage(controller: c, actions: Taps().actions)));
      await tester.pump(const Duration(milliseconds: 50));

      for (final text in [
        'Home',
        'Continue learning',
        'Mathematics Grade 5',
        'Next: Adding fractions',
        '4 of 10 lessons done',
        'Live classes today',
        'Maths live',
        'Keep reading',
        'Simple Stories',
        'Assignments',
        'Fractions worksheet',
        'Numbers test',
        'Recent quizzes',
        'Fractions quiz',
        'Latest grades',
        'Term 2 Maths',
        'Learning time this week',
        'Msafara today',
        'Nakuru',
        'Videos',
        'Counting song',
      ]) {
        expect(find.text(text), findsWidgets, reason: text);
      }
      expect(find.text('Soon'), findsOneWidget); // the urgent assignment
      expect(tester.takeException(), isNull);

      // Order: continue, live classes, reading, assignments, quizzes, grades, week, Msafara, videos.
      double y(String t) => tester.getTopLeft(find.text(t).first).dy;
      final order = ['Continue learning', 'Live classes today', 'Keep reading', 'Assignments', 'Recent quizzes', 'Latest grades', 'Learning time this week', 'Msafara today', 'Videos'];
      for (var i = 1; i < order.length; i++) {
        expect(y(order[i]), greaterThan(y(order[i - 1])), reason: '${order[i]} after ${order[i - 1]}');
      }
    });

    testWidgets('streak and coins are chips with spoken values', (tester) async {
      final semantics = tester.ensureSemantics();
      setTallPhone(tester);
      final c = await loaded(() async => home('home'));
      await tester.pumpWidget(screenApp(StudentHomePage(controller: c, actions: Taps().actions)));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.bySemanticsLabel(RegExp('Streak, 4 days')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Coins, 120.5')), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('nothing yet: every section says so, and a welcome appears', (tester) async {
      setTallPhone(tester);
      final c = await loaded(() async => home('home_empty'));
      await tester.pumpWidget(screenApp(StudentHomePage(controller: c, actions: Taps().actions)));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('Nothing to continue yet'), findsOneWidget);
      expect(find.text('No live classes today.'), findsOneWidget);
      expect(find.text('No books in progress.'), findsOneWidget);
      expect(find.textContaining('No assignments due'), findsOneWidget);
      expect(find.text('Welcome'), findsOneWidget);
      expect(find.text('Msafara today'), findsNothing);
      expect(find.text('Coins'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Continue opens the next lesson of the area', (tester) async {
      setTallPhone(tester);
      final taps = Taps();
      final c = await loaded(() async => home('home'));
      await tester.pumpWidget(screenApp(StudentHomePage(controller: c, actions: taps.actions)));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('Continue'));
      expect(taps.lessons, [(41, 512)]);
    });

    testWidgets('a finished area opens the area instead of a lesson', (tester) async {
      setTallPhone(tester);
      final taps = Taps();
      final data = fixtureData('home');
      (data['widgets'] as Map)['continue'] = {...(data['widgets'] as Map)['continue'] as Map, 'lesson_id': null, 'lesson': null, 'percent': 100};
      final c = await loaded(() async => HomeData.fromJson(data));
      await tester.pumpWidget(screenApp(StudentHomePage(controller: c, actions: taps.actions)));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('Open learning area'));
      expect(taps.areas, [41]);
      expect(taps.lessons, isEmpty);
    });
  });

  group('Home states', () {
    testWidgets('skeleton while loading, with one spoken label', (tester) async {
      final semantics = tester.ensureSemantics();
      setPhone(tester);
      final gate = Completer<HomeData>();
      final c = LoadController<HomeData>(() => gate.future);
      c.load(); // not awaited: stays loading until the completer is done
      await tester.pumpWidget(screenApp(StudentHomePage(controller: c, actions: Taps().actions)));

      expect(find.byType(ClaySkeleton), findsWidgets);
      expect(find.bySemanticsLabel('Loading your home'), findsOneWidget);
      gate.complete(home('home'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(ClaySkeleton), findsNothing);
      semantics.dispose();
    });

    testWidgets('offline with nothing saved: friendly message and Try again', (tester) async {
      setPhone(tester);
      var calls = 0;
      final c = await loaded(() async {
        calls++;
        throw const OfflineError();
      });
      await tester.pumpWidget(screenApp(StudentHomePage(controller: c, actions: Taps().actions)));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('You are offline'), findsOneWidget);
      expect(find.text('No internet connection. Check it and try again.'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(calls, 2);
    });

    testWidgets('subscription required shows the locked state, never server text', (tester) async {
      setPhone(tester);
      final c = await loaded(() async => throw const SubscriptionRequiredError());
      await tester.pumpWidget(screenApp(StudentHomePage(controller: c, actions: Taps().actions)));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('A subscription is needed'), findsOneWidget);
      expect(find.text('Subscription required'), findsNothing);
    });

    testWidgets('a failed refresh keeps the data and shows the offline banner', (tester) async {
      setTallPhone(tester);
      var fail = false;
      final c = await loaded(() async => fail ? throw const OfflineError() : home('home'));
      await tester.pumpWidget(screenApp(StudentHomePage(controller: c, actions: Taps().actions)));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('You are offline'), findsNothing);

      fail = true;
      await c.refresh();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('You are offline. Showing what you saw last.'), findsOneWidget);
      expect(find.text('Mathematics Grade 5'), findsOneWidget);
    });

    testWidgets('pull to refresh asks again', (tester) async {
      setPhone(tester);
      var calls = 0;
      final c = await loaded(() async {
        calls++;
        return home('home');
      });
      await tester.pumpWidget(screenApp(StudentHomePage(controller: c, actions: Taps().actions)));
      await tester.pump(const Duration(milliseconds: 50));
      expect(calls, 1);

      await tester.fling(find.byType(ListView).first, const Offset(0, 400), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(calls, 2);
    });
  });

  group('Home accessibility matrix (theme x text scale, tap targets and labels)', () {
    for (final mode in clayModes) {
      for (final scale in clayScales) {
        testWidgets('data [${mode.name} x$scale]', (tester) async {
          final semantics = tester.ensureSemantics();
          setPhone(tester);
          final c = await loaded(() async => home('home'));
          await tester.pumpWidget(screenApp(StudentHomePage(controller: c, actions: Taps().actions), mode: mode, textScale: scale));
          await tester.pump(const Duration(milliseconds: 50));

          expect(tester.takeException(), isNull);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          semantics.dispose();
        });
      }
    }
  });
}
