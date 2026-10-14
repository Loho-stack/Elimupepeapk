import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:elimupepe/core/design/clay.dart';
import 'package:elimupepe/data/api_call.dart';
import 'package:elimupepe/data/repositories/repositories.dart';
import 'package:elimupepe/features/student/learning/learning_areas_controller.dart';
import 'package:elimupepe/features/student/learning/learning_areas_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import 'support.dart';

String raw(String name) => File('test/fixtures/app_api/$name.json').readAsStringSync();

ResponseBody ok(String body) => ResponseBody.fromString(body, 200, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });

class Taps {
  final lessons = <(int, int)>[];
  final areas = <int>[];
  final paths = <(String, String)>[];

  LearningActions get actions => LearningActions(
        openArea: areas.add,
        openLesson: (c, l) => lessons.add((c, l)),
        openPath: (t, p) => paths.add((t, p)),
      );
}

typedef Setup = ({LearningAreasController controller, ScriptedAdapter adapter});

Setup setup({Responder? override, Duration searchDelay = const Duration(milliseconds: 10)}) {
  final adapter = ScriptedAdapter(override ??
      (o) => switch (o.path) {
            '/student/saved-lessons' => ok(raw('saved_lessons')),
            '/student/learning-areas/quizzes' => ok(raw('quizzes')),
            _ => ok(raw('learning_areas')),
          });
  final dio = Dio(BaseOptions(baseUrl: 'https://staging.loholearning.co.ke/api/app/v1'))..httpClientAdapter = adapter;
  final controller = LearningAreasController(LearningRepository(ApiCall(dio)), searchDelay: searchDelay);
  return (controller: controller, adapter: adapter);
}

Future<void> show(WidgetTester tester, Setup s, Taps taps, {ClayThemeMode mode = ClayThemeMode.light, double scale = 1.0}) async {
  await tester.runAsync(s.controller.start);
  await tester.pumpWidget(screenApp(LearningAreasPage(controller: s.controller, actions: taps.actions), mode: mode, textScale: scale));
  await settle(tester);
}

/// Lets the fake HTTP adapter answer (it needs the real event loop), then draws the result.
Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUpAll(loadClayFonts);

  group('Learning areas tab', () {
    testWidgets('hero, chips and one card per area with its state', (tester) async {
      setTallPhone(tester);
      final s = setup();
      await show(tester, s, Taps());

      expect(find.text('My Learning Areas'), findsOneWidget);
      expect(find.text('Continue where you stopped'), findsOneWidget);
      expect(find.text('Mathematics'), findsWidgets); // hero + card
      expect(find.text('Science'), findsOneWidget);
      expect(find.text('Kiswahili'), findsOneWidget);
      expect(find.text('Art'), findsOneWidget);
      expect(find.text('In progress'), findsWidgets);
      expect(find.text('Not started'), findsWidgets);
      expect(find.text('Done'), findsWidgets);
      expect(find.text('Coming soon'), findsOneWidget);
      expect(find.text('1 of 4 lessons done'), findsWidgets);
      expect(find.text('Next: Maths 2'), findsWidgets);
      expect(find.text('About 30 min left'), findsWidgets);
      expect(find.text('1 video, 1 slide deck, 2 readings'), findsOneWidget);
      expect(find.text('Lessons this week'), findsOneWidget);
      expect(tester.takeException(), isNull);
      s.controller.dispose();
    });

    testWidgets('tapping an area opens it; Coming soon cannot be opened', (tester) async {
      setTallPhone(tester);
      final taps = Taps();
      final s = setup();
      await show(tester, s, taps);

      await tester.tap(find.text('Science'));
      await tester.tap(find.text('Art'));
      expect(taps.areas, [42]);

      await tester.tap(find.text('Continue'));
      expect(taps.lessons, [(41, 512)]);
      s.controller.dispose();
    });

    testWidgets('a filter chip asks the server and the hero hides while filtering', (tester) async {
      setTallPhone(tester);
      final s = setup();
      await show(tester, s, Taps());
      expect(s.adapter.seen.single.queryParameters, isEmpty);

      await tester.tap(find.widgetWithText(ClayChip, 'Done'));
      await settle(tester);

      expect(s.adapter.seen.last.queryParameters, {'filter': 'done'});
      expect(find.text('Continue where you stopped'), findsNothing);
      s.controller.dispose();
    });

    testWidgets('sort goes to the server', (tester) async {
      setTallPhone(tester);
      final s = setup();
      await show(tester, s, Taps());

      await tester.tap(find.widgetWithText(ClayChip, 'Progress'));
      await settle(tester);
      expect(s.adapter.seen.last.queryParameters, {'sort': 'progress'});

      await tester.tap(find.widgetWithText(ClayChip, 'Name'));
      await settle(tester);
      expect(s.adapter.seen.last.queryParameters, {'sort': 'name'});
      s.controller.dispose();
    });

    testWidgets('search waits for a pause in typing, then asks once', (tester) async {
      setTallPhone(tester);
      final s = setup(searchDelay: const Duration(milliseconds: 300));
      await show(tester, s, Taps());

      await tester.enterText(find.byType(TextField), 's');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), 'sci');
      await tester.pump(const Duration(milliseconds: 100));
      expect(s.adapter.seen, hasLength(1)); // still typing

      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester);
      expect(s.adapter.seen, hasLength(2));
      expect(s.adapter.seen.last.queryParameters, {'q': 'sci'});
      s.controller.dispose();
    });

    testWidgets('no match says so; no areas at all says so', (tester) async {
      setTallPhone(tester);
      final empty = jsonEncode({
        'success': true,
        'data': {'hero': null, 'chips': {'in_progress': 0, 'lessons_week': 0, 'books_reading': 0}, 'areas': []}
      });
      final s = setup(override: (o) => ok(empty));
      await show(tester, s, Taps());
      expect(find.text('No learning areas yet'), findsOneWidget);

      await tester.tap(find.widgetWithText(ClayChip, 'Done'));
      await settle(tester);
      expect(find.text('Nothing matches'), findsOneWidget);
      s.controller.dispose();
    });
  });

  group('Saved and Quizzes tabs', () {
    testWidgets('they load only when opened', (tester) async {
      setTallPhone(tester);
      final s = setup();
      await show(tester, s, Taps());
      expect(s.adapter.seen.map((o) => o.path), ['/student/learning-areas']);

      await tester.tap(find.text('Saved'));
      await settle(tester);
      expect(s.adapter.seen.last.path, '/student/saved-lessons');
      await tester.tap(find.text('Quizzes'));
      await settle(tester);
      expect(s.adapter.seen.last.path, '/student/learning-areas/quizzes');

      await tester.tap(find.text('Saved'));
      await settle(tester);
      expect(s.adapter.seen, hasLength(3)); // not loaded a second time
      s.controller.dispose();
    });

    testWidgets('a saved lesson opens its lesson', (tester) async {
      setTallPhone(tester);
      final taps = Taps();
      final s = setup();
      await show(tester, s, taps);
      await tester.tap(find.text('Saved'));
      await settle(tester);

      expect(find.text('Adding fractions'), findsOneWidget);
      expect(find.text('Mathematics'), findsOneWidget);
      await tester.tap(find.text('Adding fractions'));
      expect(taps.lessons, [(41, 512)]);
      s.controller.dispose();
    });

    testWidgets('quizzes open in the webview with the server path, or the quiz list when there is none', (tester) async {
      setTallPhone(tester);
      final taps = Taps();
      final s = setup();
      await show(tester, s, taps);
      await tester.tap(find.text('Quizzes'));
      await settle(tester);

      expect(find.text('2 attempts, Best 8/10'), findsOneWidget);
      expect(find.text('No attempts yet'), findsOneWidget);
      await tester.tap(find.text('Fractions quiz'));
      await tester.tap(find.text('Numbers quiz'));
      expect(taps.paths, [('Fractions quiz', '/quiz-start/60/9/fractions-quiz'), ('Numbers quiz', '/my-quizzes')]);
      s.controller.dispose();
    });

    testWidgets('empty saved list explains how to save', (tester) async {
      setTallPhone(tester);
      final s = setup(override: (o) => o.path == '/student/saved-lessons'
          ? ok(jsonEncode({'success': true, 'data': [], 'meta': {'current_page': 1, 'per_page': 20, 'total': 0, 'last_page': 1}}))
          : ok(raw('learning_areas')));
      await show(tester, s, Taps());
      await tester.tap(find.text('Saved'));
      await settle(tester);

      expect(find.text('No saved lessons'), findsOneWidget);
      s.controller.dispose();
    });
  });

  group('Learning areas states', () {
    testWidgets('offline on the first load: friendly error, retry works', (tester) async {
      setTallPhone(tester);
      var offline = true;
      final s = setup(override: (o) => offline
          ? throw DioException(requestOptions: o, type: DioExceptionType.connectionError)
          : ok(raw('learning_areas')));
      await show(tester, s, Taps());
      expect(find.text('You are offline'), findsOneWidget);

      offline = false;
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(find.text('Science'), findsOneWidget);
      s.controller.dispose();
    });

    testWidgets('subscription required is the locked state', (tester) async {
      setPhone(tester);
      final s = setup(override: (o) => ResponseBody.fromString(raw('error_subscription'), 403, headers: {
            Headers.contentTypeHeader: ['application/json'],
          }));
      await show(tester, s, Taps());
      expect(find.text('A subscription is needed'), findsOneWidget);
      s.controller.dispose();
    });
  });

  group('Learning areas accessibility matrix', () {
    for (final mode in clayModes) {
      for (final scale in clayScales) {
        testWidgets('areas [${mode.name} x$scale]', (tester) async {
          final semantics = tester.ensureSemantics();
          setPhone(tester);
          final s = setup();
          await show(tester, s, Taps(), mode: mode, scale: scale);

          expect(tester.takeException(), isNull);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          s.controller.dispose();
          semantics.dispose();
        });
      }
    }
  });
}
