import 'package:elimupepe/data/models/msafara_quests.dart';
import 'package:elimupepe/features/quest/quest_home_page.dart';
import 'package:elimupepe/features/quest/quest_widgets.dart';
import 'package:elimupepe/features/student/load_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

class Taps {
  final quests = <int>[];
  var bonus = 0;
  final checkpoints = <int>[];
  var journey = 0, boards = 0, me = 0;

  QuestHomeActions get actions => QuestHomeActions(
        openQuest: (c) => quests.add(c.no),
        openBonus: () => bonus++,
        openCheckpoint: checkpoints.add,
        openJourney: () => journey++,
        openBoards: () => boards++,
        openMe: () => me++,
      );

  QuestHomeActions get noLinks => QuestHomeActions(openQuest: (c) => quests.add(c.no), openBonus: () => bonus++);
}

Future<LoadController<QuestHome>> loaded(String fixture) async {
  final c = LoadController<QuestHome>(() async => QuestHome.fromJson(data(fixture)));
  await c.load();
  return c;
}

Widget page(QuestRig rig, LoadController<QuestHome> c, QuestHomeActions a, {double scale = 1.0}) =>
    screenApp(QuestHomePage(session: rig.session, controller: c, actions: a), textScale: scale);

void main() {
  setUpAll(loadClayFonts);

  QuestRig rig({String lang = 'en'}) => QuestRig((o) => ok('state_active'), lang: lang);

  testWidgets('shows the day, town, leg, kilometres, goal and the Quest cards', (tester) async {
    setTallPhone(tester);
    await tester.pumpWidget(page(rig(), await loaded('home'), Taps().actions));
    await tester.pump(const Duration(milliseconds: 600));

    for (final text in [
      'Day 12 of 92',
      'Voi',
      'Taita-Taveta',
      'Leg 1: Pwani to the Peaks',
      'Day 12 of 31 in this leg',
      '182.5',
      'kilometres travelled in all',
      '30 of 360 km',
      "Today's goal: 60 minutes",
      '24 of 60 minutes read',
      "Today's Quest",
      'Quest 1 · English Q&A',
      'Our Land and People',
      'Longhorn',
      'Read pages 4 to 9',
      'The questions are locked until you have read for 3 minutes.',
      'Keep reading',
      'Quest 2 · Kiswahili Q&A',
      'Quest done: 4 of 5 right',
      'See your answers',
      'Towns you missed',
      'Day 10: Mombasa',
      'Your place today',
      'Place 7',
      'Up 2 from yesterday',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
  });

  testWidgets("today's checkpoint card shows the Did you know and opens the day", (tester) async {
    setTallPhone(tester);
    final taps = Taps();
    await tester.pumpWidget(page(rig(), await loaded('home'), taps.actions));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Did you know?'), findsOneWidget);
    expect(find.text('Unlock Voi'), findsOneWidget);
    expect(find.text('Read the Did You Know, then answer one question.'), findsOneWidget);
    await tester.tap(find.text('Unlock Voi'));
    expect(taps.checkpoints, [12]);
  });

  testWidgets('a Quest card opens its quest', (tester) async {
    setTallPhone(tester);
    final taps = Taps();
    await tester.pumpWidget(page(rig(), await loaded('home'), taps.actions));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Our Land and People'));
    await tester.tap(find.text('Short lesson for Grade 4'));
    expect(taps.quests, [1, 2]);
  });

  testWidgets('the links to the map, boards and me appear when their screens exist', (tester) async {
    setTallPhone(tester);
    final taps = Taps();
    await tester.pumpWidget(page(rig(), await loaded('home'), taps.actions));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Map'));
    await tester.tap(find.text('Board'));
    await tester.tap(find.text('Me'));
    expect((taps.journey, taps.boards, taps.me), (1, 1, 1));

    await tester.pumpWidget(page(rig(), await loaded('home'), taps.noLinks));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Map'), findsNothing);
  });

  testWidgets('Kiswahili copy', (tester) async {
    setTallPhone(tester);
    await tester.pumpWidget(page(rig(lang: 'sw'), await loaded('home'), Taps().actions));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Siku 12 kati ya 92'), findsOneWidget);
    expect(find.text('Jaribio la leo'), findsOneWidget);
    expect(find.text('Soma ukurasa 4 hadi 9'), findsOneWidget);
    expect(find.text('Hatua 1: Pwani to the Peaks'), findsOneWidget);
  });

  testWidgets('after the journey ends it says so and lists no quests', (tester) async {
    setTallPhone(tester);
    await tester.pumpWidget(page(rig(), await loaded('home_ended'), Taps().actions));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('The journey has ended'), findsOneWidget);
    expect(find.text('1210.5'), findsOneWidget);
    expect(find.textContaining('Quest 1'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no quests yet: the not ready card', (tester) async {
    setTallPhone(tester);
    final j = data('home')..['quests'] = <dynamic>[];
    final c = LoadController<QuestHome>(() async => QuestHome.fromJson(j));
    await c.load();
    await tester.pumpWidget(page(rig(), c, Taps().actions));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text("Today's Quest is not ready yet"), findsOneWidget);
  });

  testWidgets('the bonus card opens the bonus quest', (tester) async {
    setTallPhone(tester);
    final taps = Taps();
    final j = data('home')..['bonus'] = {'no': 6, 'questions': 3, 'unlocked': true, 'completed': false};
    final c = LoadController<QuestHome>(() async => QuestHome.fromJson(j));
    await c.load();
    await tester.pumpWidget(page(rig(), c, taps.actions));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Try again: questions you missed'), findsOneWidget);
    await tester.tap(find.text('Try again: questions you missed'));
    expect(taps.bonus, 1);
  });

  testWidgets('the daily limit reached is said kindly', (tester) async {
    setTallPhone(tester);
    final j = data('home');
    (j['km'] as Map<String, dynamic>)['today'] = 360.0;
    final c = LoadController<QuestHome>(() async => QuestHome.fromJson(j));
    await c.load();
    await tester.pumpWidget(page(rig(), c, Taps().actions));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('You have reached'), findsOneWidget);
  });

  testWidgets('reduced motion: no entrance animation is built', (tester) async {
    setTallPhone(tester);
    final c = await loaded('home');
    await tester.pumpWidget(Builder(
      builder: (context) => MediaQuery(
        data: MediaQueryData(disableAnimations: true, size: tester.view.physicalSize),
        child: page(rig(), c, Taps().actions),
      ),
    ));
    await tester.pump();
    expect(find.descendant(of: find.byType(QuestEntrance), matching: find.byType(Opacity)), findsNothing);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('360 dp, text x$scale: no overflow, 48 dp and labelled targets', (tester) async {
      final semantics = tester.ensureSemantics();
      setPhone(tester);
      await tester.pumpWidget(page(rig(), await loaded('home'), Taps().actions, scale: scale));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });
  }

  testWidgets('a quest card is one labelled button for TalkBack', (tester) async {
    final semantics = tester.ensureSemantics();
    setTallPhone(tester);
    await tester.pumpWidget(page(rig(), await loaded('home'), Taps().actions));
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      find.bySemanticsLabel(RegExp(r'^Quest 1 · English Q&A\. Our Land and People\. Read pages 4 to 9\.')),
      findsOneWidget,
    );
    semantics.dispose();
  });
}
