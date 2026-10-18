import 'dart:ui' as ui;

import 'package:elimupepe/data/api_error.dart';
import 'package:elimupepe/data/models/msafara_journey.dart';
import 'package:elimupepe/features/quest/journey_map.dart';
import 'package:elimupepe/features/quest/journey_page.dart';
import 'package:elimupepe/features/student/load_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

/// 92 towns spread over Kenya's box, in day order; [today] is the current day. Every 10th town has no
/// coordinates, like the real data.
Journey journeyOf({int today = 12, bool coordinates = true}) {
  final towns = <Map<String, dynamic>>[
    for (var d = 1; d <= 92; d++)
      {
        'day': d,
        'plan_day': d,
        'date': '2026-10-${(18 + d).clamp(1, 31).toString().padLeft(2, '0')}',
        'town': 'Town $d',
        'county': 'County $d',
        'lat': coordinates && d % 10 != 0 ? -4.0 + (d % 9) * 1.0 : null,
        'lng': coordinates && d % 10 != 0 ? 34.5 + (d % 7) * 1.0 : null,
        'leg': 1,
        'special': null,
        'reached': d <= today,
        'current': d == today,
        'state': d == today ? 'today' : (d < today ? (d % 5 == 0 ? 'passed' : 'visited') : 'future'),
      },
  ];
  return Journey.fromJson({
    'today': today,
    'km': {'total': 182.5, 'today': 30.0, 'daily_cap': 360.0},
    'towns': towns,
    'legs': [
      {'no': 1, 'name': 'Pwani to the Peaks', 'from': 1, 'to': 31}
    ],
  });
}

JourneyTown town(double? lat, double? lng, {String state = 'future', int day = 1, bool current = false}) =>
    JourneyTown.fromJson({
      'day': day,
      'plan_day': day,
      'date': '2026-10-19',
      'town': 'T$day',
      'county': null,
      'lat': lat,
      'lng': lng,
      'leg': 1,
      'special': null,
      'reached': state != 'future',
      'current': current,
      'state': state,
    });

void main() {
  setUpAll(loadClayFonts);

  group('model', () {
    test('from the contract example', () {
      final j = Journey.fromJson(data('journey'));
      expect(j.today, 12);
      expect(j.km.total, 182.5);
      expect(j.towns, hasLength(2));
      expect(j.towns.first.onMap, isTrue);
      expect(j.towns.last.onMap, isFalse, reason: 'Voi has no coordinates');
      expect(j.mapped, hasLength(1));
      expect(j.unmapped, 1);
      expect(j.towns.last.current, isTrue);
      expect(j.legs.single.name, 'Pwani to the Peaks');
    });
  });

  group('map geometry', () {
    test('the corners of Kenya land on the corners of the box', () {
      const size = Size(400, 485);
      expect(KenyaBounds.project(KenyaBounds.north, KenyaBounds.west, size), Offset.zero);
      final se = KenyaBounds.project(KenyaBounds.south, KenyaBounds.east, size);
      expect(se.dx, closeTo(400, 0.001));
      expect(se.dy, closeTo(485, 0.001));
    });

    test('Mombasa is south and east, Kisumu west', () {
      const size = Size(400, 485);
      final mombasa = KenyaBounds.project(-4.0435, 39.6682, size);
      final kisumu = KenyaBounds.project(-0.1, 34.75, size);
      expect(mombasa.dy, greaterThan(kisumu.dy));
      expect(mombasa.dx, greaterThan(kisumu.dx));
    });

    test('nearest finds a town inside the hit radius and ignores far taps and unmapped towns', () {
      const size = Size(400, 485);
      final a = town(-4.0, 39.0, day: 1);
      final b = town(null, null, day: 2);
      final at = KenyaBounds.project(-4.0, 39.0, size);
      expect(JourneyMapPainter.nearest([a, b], size, at + const Offset(5, 5))?.day, 1);
      expect(JourneyMapPainter.nearest([a, b], size, at + const Offset(60, 0)), isNull);
    });

    test('the painter draws all states without error', () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const colors = JourneyMapColors(
        land: Colors.green, grid: Colors.grey, route: Colors.blue, ahead: Colors.black26,
        visited: Colors.blue, missed: Colors.red, today: Colors.green, halo: Colors.greenAccent,
      );
      final towns = [
        town(-4.0, 39.6, state: 'visited', day: 1),
        town(-3.0, 38.0, state: 'passed', day: 2),
        town(-1.0, 37.0, state: 'today', day: 3, current: true),
        town(0.5, 36.0, state: 'future', day: 4),
      ];
      JourneyMapPainter(towns: towns, colors: colors).paint(canvas, const Size(400, 485));
      recorder.endRecording();
    });
  });

  group('MsafaraRepository.journey', () {
    test('GET /msafara/journey', () async {
      final rig = QuestRig((o) => ok('journey'));
      final j = await rig.repo.journey();
      expect(rig.adapter.seen.single.path, '/msafara/journey');
      expect(j.towns, hasLength(2));
    });

    test('409 not_started is a gate error', () async {
      final rig = QuestRig((o) => gate('not_started'));
      await expectLater(rig.repo.journey(), throwsA(isA<MsafaraGateError>()));
    });
  });

  group('JourneyPage', () {
    Future<(QuestRig, List<int>)> open(WidgetTester tester, Journey j, {double scale = 1.0, String lang = 'en'}) async {
      final rig = QuestRig((o) => ok('state_active'), lang: lang);
      final opened = <int>[];
      final c = LoadController<Journey>(() async => j);
      await c.load();
      await tester.pumpWidget(screenApp(
        JourneyPage(session: rig.session, controller: c, onOpenCheckpoint: opened.add),
        textScale: scale,
      ));
      await tester.pump();
      return (rig, opened);
    }

    testWidgets('shows the map, the unmapped note and every town in the list', (tester) async {
      setTallPhone(tester);
      await open(tester, journeyOf());
      expect(find.text('92 towns across Kenya'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.text('9 towns are not on the map yet. They are still part of the journey.'), findsOneWidget);
      expect(find.text('Town 1'), findsOneWidget);
      expect(find.text('Day 1 · 19 Oct 2026 · Visited'), findsOneWidget);
      expect(find.text('Town 12'), findsOneWidget);
      expect(find.textContaining('Today'), findsWidgets);
      expect(find.textContaining('GeoNames'), findsOneWidget);
    });

    testWidgets('a list tile opens the town sheet, which leads to its checkpoint', (tester) async {
      setTallPhone(tester);
      final (_, opened) = await open(tester, journeyOf());
      await tester.tap(find.text('Town 3'));
      await tester.pumpAndSettle();
      expect(find.text('County 3 County'), findsOneWidget);
      await tester.tap(find.text('Did you know?'));
      await tester.pumpAndSettle();
      expect(opened, [3]);
    });

    testWidgets('a town ahead says when it unlocks and has no checkpoint button', (tester) async {
      setTallPhone(tester);
      await open(tester, journeyOf());
      await tester.tap(find.text('Town 20'));
      await tester.pumpAndSettle();
      expect(find.textContaining('You unlock this town on'), findsOneWidget);
      expect(find.text('Did you know?'), findsNothing);
    });

    testWidgets('tapping the map near a town opens its sheet', (tester) async {
      setTallPhone(tester);
      final j = Journey.fromJson({
        ...data('journey'),
        'towns': [
          {...(data('journey')['towns'] as List).first as Map<String, dynamic>},
        ],
      });
      await open(tester, j);
      final painter = find.byType(CustomPaint).evaluate().map((e) => e.widget as CustomPaint).firstWhere((c) => c.painter is JourneyMapPainter);
      final box = tester.getRect(find.byWidget(painter));
      final p = KenyaBounds.project(-4.0435, 39.6682, box.size);
      await tester.tapAt(box.topLeft + p);
      await tester.pumpAndSettle();
      expect(find.text('Mombasa County'), findsOneWidget);
    });

    testWidgets('no coordinates at all: the empty card, and the list still works', (tester) async {
      setTallPhone(tester);
      await open(tester, journeyOf(coordinates: false));
      expect(find.text('The map has no towns yet'), findsOneWidget);
      expect(find.text('Town 5'), findsOneWidget);
    });

    testWidgets('the map is hidden from TalkBack and the list is the way in', (tester) async {
      final semantics = tester.ensureSemantics();
      setTallPhone(tester);
      await open(tester, journeyOf());
      expect(find.bySemanticsLabel(RegExp(r'^Map of Kenya with the Elimu Quest route\. Town 12, day 12, Today')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Town 7, Day 7')), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('Kiswahili copy', (tester) async {
      setTallPhone(tester);
      await open(tester, journeyOf(), lang: 'sw');
      expect(find.text('Miji 92 kote Kenya'), findsOneWidget);
      expect(find.text('Siku 1 · 19 Okt 2026 · Umetembelea'), findsOneWidget);
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('360 dp, text x$scale: no overflow, 48 dp and labelled targets', (tester) async {
        final semantics = tester.ensureSemantics();
        setPhone(tester);
        await open(tester, journeyOf(), scale: scale);
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
      });
    }
  });
}
