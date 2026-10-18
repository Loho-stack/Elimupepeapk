import 'package:elimupepe/data/api_error.dart';
import 'package:elimupepe/data/models/msafara_boards.dart';
import 'package:elimupepe/features/quest/boards_page.dart';
import 'package:elimupepe/features/quest/quest_session.dart';
import 'package:elimupepe/features/student/load_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

Board boardOf([Map<String, dynamic> over = const {}]) => Board.fromJson({...data('board'), ...over});

class BRig {
  BRig({Board? daily, Board? weekly, this.lang = 'en', Object? dailyError, Object? weeklyError}) {
    session = QuestRig((o) => ok('state_active'), lang: lang).session;
    this.daily = LoadController<Board>(() async {
      dailyCalls++;
      if (dailyError != null) throw dailyError;
      return daily ?? boardOf();
    });
    this.weekly = LoadController<Board>(() async {
      weeklyCalls++;
      if (weeklyError != null) throw weeklyError;
      return weekly ?? boardOf({'board': 'weekly', 'period_key': 'week-3', 'eligible_rule': 'weekly'});
    });
  }

  final String lang;
  late final MsafaraSession session;
  late final LoadController<Board> daily;
  late final LoadController<Board> weekly;
  var dailyCalls = 0;
  var weeklyCalls = 0;

  Widget build({double scale = 1.0}) => screenApp(
        BoardsPage(session: session, daily: daily, weekly: weekly),
        textScale: scale,
      );

  Future<void> open(WidgetTester tester, {double scale = 1.0}) async {
    await daily.load();
    await tester.pumpWidget(build(scale: scale));
    await tester.pump();
  }
}

void main() {
  setUpAll(loadClayFonts);

  group('model', () {
    test('from the contract example', () {
      final b = Board.fromJson(data('board'));
      expect((b.board, b.periodKey, b.open, b.gradeBand, b.top), ('daily', '2026-10-30', true, 'G4-6', 50));
      expect(b.rows, hasLength(2));
      expect(b.rows.first.displayName, 'Amina W.');
      expect((b.rows.first.km, b.rows.first.movement, b.rows.first.me), (60.0, 2, false));
      expect(b.rows.last.me, isTrue);
      expect(b.meInRows, isTrue);
      expect(b.me!.rank, 2);
      expect(b.me!.eligible, isTrue);
      expect(b.weekly, isFalse);
      expect(b.hideName, isFalse);
    });

    test('a learner who is hidden or not eligible has a me row with no rank', () {
      final b = boardOf({
        'rows': <dynamic>[],
        'me': {'rank': null, 'km': 12.5, 'eligible': false, 'hidden': true, 'display_name': 'B.', 'movement': null},
      });
      expect(b.meInRows, isFalse);
      expect(b.me!.rank, isNull);
      expect(b.me!.hidden, isTrue);
    });

    test('no me row at all', () {
      expect(boardOf({'me': null}).me, isNull);
    });
  });

  testWidgets('rows show the names exactly as sent, with place, grade, county, km and movement', (tester) async {
    setTallPhone(tester);
    final r = BRig(daily: boardOf({
      'rows': [
        {'rank': 1, 'display_name': 'A.', 'km': 60.0, 'county': 'Nairobi', 'grade': 'Grade 4', 'movement': 2, 'me': false},
        {'rank': 2, 'display_name': 'Brian O.', 'km': 50.0, 'county': 'Kisumu', 'grade': 'Grade 5', 'movement': -1, 'me': true},
        {'rank': 3, 'display_name': 'Cate M.', 'km': 40.5, 'county': null, 'grade': null, 'movement': 0, 'me': false},
        {'rank': 4, 'display_name': 'Dan K.', 'km': 30.0, 'county': 'Embu', 'grade': 'Grade 6', 'movement': null, 'me': false},
      ],
    }));
    await r.open(tester);

    expect(find.text('A.'), findsOneWidget, reason: 'a hidden-style name is shown as the API gives it');
    expect(find.text('Brian O.'), findsOneWidget);
    expect(find.text('Grade 4, Nairobi'), findsOneWidget);
    expect(find.text('60 km'), findsOneWidget);
    expect(find.text('40.5 km'), findsOneWidget);
    expect(find.text('Up 2 since yesterday'), findsOneWidget);
    expect(find.text('Down 1 since yesterday'), findsOneWidget);
    expect(find.text('Same place since yesterday'), findsOneWidget);
    expect(find.text('You'), findsOneWidget, reason: 'the me row is marked');
    expect(find.text('2026-10-30'), findsOneWidget);
    r.daily.dispose();
    r.weekly.dispose();
  });

  testWidgets('the week tab loads the weekly board once and says since last week', (tester) async {
    setTallPhone(tester);
    final r = BRig();
    await r.open(tester);
    expect(r.weeklyCalls, 0);

    await tester.tap(find.text('This week'));
    await tester.pump();
    await tester.pump();
    expect(r.weeklyCalls, 1);
    expect(find.text('week-3'), findsOneWidget);
    expect(find.text('Up 2 since last week'), findsOneWidget);

    await tester.tap(find.text('Today'));
    await tester.pump();
    await tester.tap(find.text('This week'));
    await tester.pump();
    expect(r.weeklyCalls, 1, reason: 'not loaded again');
    r.daily.dispose();
    r.weekly.dispose();
  });

  testWidgets('hidden: your place is shown only to you, with the note', (tester) async {
    setTallPhone(tester);
    final r = BRig(daily: boardOf({
      'rows': [
        {'rank': 1, 'display_name': 'Amina W.', 'km': 60.0, 'county': 'Nairobi', 'grade': 'Grade 4', 'movement': null, 'me': false},
      ],
      'me': {'rank': 9, 'km': 20.0, 'eligible': true, 'hidden': true, 'display_name': 'Brian O.', 'movement': 3},
      'hide_name': true,
    }));
    await r.open(tester);
    expect(find.text('Place 9'), findsOneWidget);
    expect(find.text('Your name is hidden. Only you can see your place.'), findsOneWidget);
    expect(find.text('Up 3 since yesterday'), findsOneWidget);
    r.daily.dispose();
    r.weekly.dispose();
  });

  testWidgets('not eligible yet: what to do to get a place (daily and weekly)', (tester) async {
    setTallPhone(tester);
    final me = {'rank': null, 'km': 10.0, 'eligible': false, 'hidden': false, 'display_name': 'Brian O.', 'movement': null};
    final r = BRig(
      daily: boardOf({'rows': <dynamic>[], 'me': me}),
      weekly: boardOf({'board': 'weekly', 'period_key': 'week-3', 'rows': <dynamic>[], 'me': me}),
    );
    await r.open(tester);
    expect(find.text('No one is on the board yet.'), findsOneWidget);
    expect(find.text("Answer today's checkpoint on time to appear."), findsOneWidget);
    expect(find.text("Answer today's checkpoint on time to get a place."), findsOneWidget);
    expect(find.text('Keep travelling'), findsOneWidget);

    await tester.tap(find.text('This week'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Travel on three days this week to appear.'), findsOneWidget);
    expect(find.text('Travel on three days this week to get a place.'), findsOneWidget);
    r.daily.dispose();
    r.weekly.dispose();
  });

  testWidgets('no kilometres yet', (tester) async {
    setTallPhone(tester);
    final r = BRig(daily: boardOf({'rows': <dynamic>[], 'me': null}));
    await r.open(tester);
    expect(find.text('You have no kilometres today yet.'), findsOneWidget);
    r.daily.dispose();
    r.weekly.dispose();
  });

  testWidgets('before Day 1 the board is closed', (tester) async {
    setTallPhone(tester);
    final r = BRig(daily: boardOf({'open': false, 'rows': <dynamic>[], 'me': null}));
    await r.open(tester);
    expect(find.text('The leaderboard opens on Day 1.'), findsOneWidget);
    r.daily.dispose();
    r.weekly.dispose();
  });

  testWidgets('a grade outside PP1 to Grade 10 has no board but its kilometres count', (tester) async {
    setTallPhone(tester);
    final r = BRig(daily: boardOf({'grade_band': null, 'rows': <dynamic>[], 'me': null}));
    await r.open(tester);
    expect(find.text('Your kilometres count'), findsOneWidget);
    expect(find.text('You are not on a leaderboard because your grade is outside PP1 to Grade 10.'), findsOneWidget);
    r.daily.dispose();
    r.weekly.dispose();
  });

  testWidgets('boards switched off (404): a kind note, not an error page', (tester) async {
    setTallPhone(tester);
    final r = BRig(dailyError: const NotFoundError());
    await r.open(tester);
    expect(find.text('The leaderboards are not open yet'), findsOneWidget);
    expect(find.text('Something went wrong'), findsNothing);
    r.daily.dispose();
    r.weekly.dispose();
  });

  testWidgets('offline on the first load: retry', (tester) async {
    setTallPhone(tester);
    final r = BRig(dailyError: const OfflineError());
    await r.open(tester);
    expect(find.text('You are offline'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    r.daily.dispose();
    r.weekly.dispose();
  });

  testWidgets('a row is one labelled item for TalkBack', (tester) async {
    final semantics = tester.ensureSemantics();
    setTallPhone(tester);
    final r = BRig();
    await r.open(tester);
    expect(
      find.bySemanticsLabel('Place 2. Brian O.. You. Grade 5, Kisumu. 50 km. Down 1 since yesterday'),
      findsOneWidget,
    );
    semantics.dispose();
    r.daily.dispose();
    r.weekly.dispose();
  });

  testWidgets('Kiswahili copy', (tester) async {
    setTallPhone(tester);
    final r = BRig(lang: 'sw');
    await r.open(tester);
    expect(find.text('Ubao wa matokeo'), findsOneWidget);
    expect(find.text('Leo'), findsOneWidget);
    expect(find.text('Umepanda 2 tangu jana'), findsOneWidget);
    r.daily.dispose();
    r.weekly.dispose();
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('360 dp, text x$scale: no overflow, 48 dp and labelled targets', (tester) async {
      final semantics = tester.ensureSemantics();
      setPhone(tester);
      final r = BRig();
      await r.open(tester, scale: scale);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
      r.daily.dispose();
      r.weekly.dispose();
    });
  }
}
