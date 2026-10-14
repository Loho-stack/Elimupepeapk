import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:elimupepe/core/design/clay.dart';
import 'package:elimupepe/data/api_call.dart';
import 'package:elimupepe/data/api_error.dart';
import 'package:elimupepe/data/models/home.dart';
import 'package:elimupepe/data/repositories/repositories.dart';
import 'package:elimupepe/features/student/home/home_page.dart';
import 'package:elimupepe/features/student/learning/learning_areas_controller.dart';
import 'package:elimupepe/features/student/learning/learning_areas_page.dart';
import 'package:elimupepe/features/student/load_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import 'support.dart';

/// Goldens of the Phase 4a screens at 360x780 dp (rendered at 2x), reduced motion on so skeletons and
/// rings are in their final state. The data state of every screen is captured in all three themes at
/// text scale 1.0, 1.5 and 2.0; the other states in all three themes at 1.0.
///
/// Regenerate with: flutter test --update-goldens test/features/student/goldens_test.dart
/// Goldens are generated and compared on Windows; other platforms render text slightly differently.
void main() {
  setUpAll(loadClayFonts);

  final homeActions = HomeActions(openLesson: (_, _) {}, openArea: (_) {}, openPath: (_, _) {});
  final learningActions = LearningActions(openArea: (_) {}, openLesson: (_, _) {}, openPath: (_, _) {});

  HomeData home(String f) => HomeData.fromJson(fixtureData(f));

  ResponseBody ok(String body) => ResponseBody.fromString(body, 200, headers: {
        Headers.contentTypeHeader: ['application/json'],
      });
  String raw(String n) => File('test/fixtures/app_api/$n.json').readAsStringSync();

  LearningAreasController areas({String? areasBody}) {
    final adapter = ScriptedAdapter((o) => switch (o.path) {
          '/student/saved-lessons' => ok(raw('saved_lessons')),
          '/student/learning-areas/quizzes' => ok(raw('quizzes')),
          _ => ok(areasBody ?? raw('learning_areas')),
        });
    final dio = Dio(BaseOptions(baseUrl: 'https://staging.loholearning.co.ke/api/app/v1'))..httpClientAdapter = adapter;
    return LearningAreasController(LearningRepository(ApiCall(dio)));
  }

  Future<void> golden(
    WidgetTester tester,
    String name,
    Widget Function() screen, {
    required ClayThemeMode mode,
    required double scale,
    Future<void> Function()? before,
  }) async {
    await withShadows(() async {
      setPhone(tester, dpr: 2.0);
      await before?.call();
      await tester.pumpWidget(screenApp(
        screen(),
        options: ClayThemeOptions(mode: mode, reduceMotion: true),
        textScale: scale,
      ));
      await tester.pump(const Duration(milliseconds: 100));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/${name}_${goldenKey(mode, scale)}.png'));
    });
  }

  // ----------------------------------------------------------------- the data states, 9 each
  for (final mode in clayModes) {
    for (final scale in clayScales) {
      testWidgets('home data [${mode.name} x$scale]', (tester) async {
        final c = LoadController<HomeData>(() async => home('home'));
        await c.load();
        await golden(tester, 'home_data', () => StudentHomePage(controller: c, actions: homeActions), mode: mode, scale: scale);
      });

      testWidgets('learning areas data [${mode.name} x$scale]', (tester) async {
        final c = areas();
        await golden(
          tester,
          'areas_data',
          () => LearningAreasPage(controller: c, actions: learningActions),
          mode: mode,
          scale: scale,
          before: () => tester.runAsync(c.start),
        );
        c.dispose();
      });
    }
  }

  // ------------------------------------------------------------ the other states, 1.0 only
  for (final mode in clayModes) {
    testWidgets('home empty [${mode.name}]', (tester) async {
      final c = LoadController<HomeData>(() async => home('home_empty'));
      await c.load();
      await golden(tester, 'home_empty', () => StudentHomePage(controller: c, actions: homeActions), mode: mode, scale: 1.0);
    });

    testWidgets('home loading [${mode.name}]', (tester) async {
      final gate = Completer<HomeData>();
      final c = LoadController<HomeData>(() => gate.future)..load();
      await golden(tester, 'home_loading', () => StudentHomePage(controller: c, actions: homeActions), mode: mode, scale: 1.0);
      gate.complete(home('home'));
    });

    testWidgets('home offline with old data [${mode.name}]', (tester) async {
      var fail = false;
      final c = LoadController<HomeData>(() async => fail ? throw const OfflineError() : home('home'));
      await c.load();
      fail = true;
      await c.load();
      await golden(tester, 'home_offline', () => StudentHomePage(controller: c, actions: homeActions), mode: mode, scale: 1.0);
    });

    testWidgets('home offline, nothing saved [${mode.name}]', (tester) async {
      final c = LoadController<HomeData>(() async => throw const OfflineError());
      await c.load();
      await golden(tester, 'home_error', () => StudentHomePage(controller: c, actions: homeActions), mode: mode, scale: 1.0);
    });

    testWidgets('learning areas empty [${mode.name}]', (tester) async {
      final c = areas(
        areasBody: jsonEncode({
          'success': true,
          'data': {'hero': null, 'chips': {'in_progress': 0, 'lessons_week': 0, 'books_reading': 0}, 'areas': []}
        }),
      );
      await golden(
        tester,
        'areas_empty',
        () => LearningAreasPage(controller: c, actions: learningActions),
        mode: mode,
        scale: 1.0,
        before: () => tester.runAsync(c.start),
      );
      c.dispose();
    });

    testWidgets('learning areas loading [${mode.name}]', (tester) async {
      final c = areas();
      c.areas.load(); // answered by the fake adapter only on the real event loop: still loading in this frame
      await golden(tester, 'areas_loading', () => LearningAreasPage(controller: c, actions: learningActions), mode: mode, scale: 1.0);
      c.dispose();
    });

    testWidgets('saved lessons [${mode.name}]', (tester) async {
      final c = areas();
      await golden(
        tester,
        'areas_saved',
        () => LearningAreasPage(controller: c, actions: learningActions),
        mode: mode,
        scale: 1.0,
        before: () async {
          await tester.runAsync(c.start);
          c.selectTab(1);
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        },
      );
      c.dispose();
    });

    testWidgets('quizzes [${mode.name}]', (tester) async {
      final c = areas();
      await golden(
        tester,
        'areas_quizzes',
        () => LearningAreasPage(controller: c, actions: learningActions),
        mode: mode,
        scale: 1.0,
        before: () async {
          await tester.runAsync(c.start);
          c.selectTab(2);
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        },
      );
      c.dispose();
    });
  }
}
