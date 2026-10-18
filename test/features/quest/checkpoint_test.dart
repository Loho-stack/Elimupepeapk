import 'package:elimupepe/data/api_error.dart';
import 'package:elimupepe/data/models/msafara_checkpoint.dart';
import 'package:elimupepe/features/quest/checkpoint_controller.dart';
import 'package:elimupepe/features/quest/checkpoint_page.dart';
import 'package:elimupepe/features/quest/quest_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

Checkpoint cp([Map<String, dynamic> over = const {}]) => Checkpoint.fromJson({...data('checkpoint'), ...over});
CheckpointResult result([Map<String, dynamic> over = const {}]) =>
    CheckpointResult.fromJson({...data('checkpoint_answer'), ...over});

class CRig {
  CRig({int day = 12, String lang = 'en'}) {
    repo = FakeQuestRepo();
    session = MsafaraSession(repo, initialLanguage: lang);
    controller = CheckpointController(repo: repo, day: day, onGate: gates.add);
  }

  late final FakeQuestRepo repo;
  late final MsafaraSession session;
  late final CheckpointController controller;
  final gates = <AppApiError>[];
  var closed = 0;

  Widget build({double scale = 1.0}) => screenApp(
        CheckpointPage(session: session, controller: controller, onClose: () => closed++),
        textScale: scale,
      );

  Future<void> open(WidgetTester tester, {double scale = 1.0}) async {
    await controller.load();
    await tester.pumpWidget(build(scale: scale));
    await tester.pump();
  }
}

void main() {
  setUpAll(loadClayFonts);

  testWidgets('open: the postcard, the fact, the question and its options', (tester) async {
    setTallPhone(tester);
    final r = CRig();
    await r.open(tester);
    for (final t in [
      'Postcard from Voi',
      'Day 12',
      'Taita-Taveta County',
      'Did you know?',
      'Voi is the gateway to Tsavo East.',
      'Checkpoint question',
      'Which national park is next to Voi?',
      'Tsavo East',
      'Amboseli',
      'Nairobi National Park',
      'Worth 20 km',
      '2 tries left.',
    ]) {
      expect(find.text(t), t == 'Did you know?' ? findsWidgets : findsOneWidget, reason: t);
    }
    r.controller.dispose();
  });

  testWidgets('Answer needs an option, sends it with a key, and a right answer unlocks the town', (tester) async {
    setTallPhone(tester);
    final r = CRig();
    r.repo.checkpointAnswerReplies.add(result());
    await r.open(tester);

    await tester.tap(find.text('Answer'), warnIfMissed: false);
    await tester.pump();
    expect(r.repo.checkpointAnswers, isEmpty);

    r.repo.checkpointReply = () => cp({'solved': true, 'attempts_left': 1, 'can_answer': false, 'correct_answer': 'Tsavo East', 'answers': [
          {'attempt': 1, 'chosen': 'Tsavo East', 'correct': true, 'late': false, 'answered_at': '2026-10-30T09:12:44+03:00'}
        ]});
    await tester.tap(find.text('Tsavo East'));
    await tester.pump();
    await tester.tap(find.text('Answer'));
    await tester.pump();

    expect(r.repo.checkpointAnswers.single.day, 12);
    expect(r.repo.checkpointAnswers.single.option, 'Tsavo East');
    expect(r.repo.checkpointAnswers.single.key, isNotEmpty);
    expect(find.text('Hongera!'), findsOneWidget);
    expect(find.text('Correct! You unlocked Voi.'), findsOneWidget);
    expect(find.text('+20 coins'), findsOneWidget);
    expect(find.text('Up to 20 km, on its way'), findsOneWidget);
    expect(find.text('Your kilometres appear at the top within a minute.'), findsOneWidget);

    await tester.tap(find.text('Continue the journey'));
    expect(r.closed, 1);
    r.controller.dispose();
  });

  testWidgets('a wrong answer with a try left: another look, then the second try is worth less', (tester) async {
    setTallPhone(tester);
    final r = CRig();
    r.repo.checkpointAnswerReplies.add(
        result({'correct': false, 'solved': false, 'attempts_left': 1, 'coins': 0.0, 'km_expected': 0.0, 'correct_answer': null}));
    await r.open(tester);
    r.repo.checkpointReply = () => cp({'attempts_left': 1, 'km_expected': 10.0, 'answers': [
          {'attempt': 1, 'chosen': 'Amboseli', 'correct': false, 'late': false, 'answered_at': '2026-10-30T09:12:44+03:00'}
        ]});
    await tester.tap(find.text('Amboseli'));
    await tester.pump();
    await tester.tap(find.text('Answer'));
    await tester.pump();

    expect(find.text('Not quite. Have another look at the fact: you have one more try.'), findsOneWidget);
    expect(find.text('Try 1: Amboseli'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(find.text('Second try: 10 km instead of 20'), findsOneWidget);
    expect(find.text('Last try.'), findsOneWidget);
    expect(r.controller.selected, isNull);
    r.controller.dispose();
  });

  testWidgets('out of tries: kind words and the right answer', (tester) async {
    setTallPhone(tester);
    final r = CRig();
    r.repo.checkpointAnswerReplies.add(result(
        {'correct': false, 'solved': false, 'attempts_left': 0, 'coins': 0.0, 'km_expected': 0.0, 'correct_answer': 'Tsavo East'}));
    await r.open(tester);
    r.repo.checkpointReply = () => cp({'attempts_left': 0, 'can_answer': false, 'correct_answer': 'Tsavo East', 'answers': [
          {'attempt': 1, 'chosen': 'Amboseli', 'correct': false, 'late': false, 'answered_at': null},
          {'attempt': 2, 'chosen': 'Nairobi National Park', 'correct': false, 'late': false, 'answered_at': null},
        ]});
    await tester.tap(find.text('Amboseli'));
    await tester.pump();
    await tester.tap(find.text('Answer'));
    await tester.pump();
    expect(find.text('Good effort! That town was a tricky one. Tomorrow there is a new one.'), findsWidgets);
    expect(find.text('The answer is: Tsavo East'), findsWidgets);
    r.controller.dispose();
  });

  testWidgets('late: the ribbon and half the kilometres', (tester) async {
    setTallPhone(tester);
    final r = CRig();
    r.repo.checkpointReply = () => cp({'state': 'late', 'late': true, 'km_expected': 10.0});
    await r.open(tester);
    expect(find.text('Late'), findsOneWidget);
    expect(find.text('Late: half the kilometres'), findsOneWidget);
    r.controller.dispose();
  });

  testWidgets('locked: says when the town opens and shows no question', (tester) async {
    setTallPhone(tester);
    final r = CRig();
    r.repo.checkpointReply = () => cp({'state': 'locked', 'can_answer': false});
    await r.open(tester);
    expect(find.text('This town opens on 30 Oct 2026.'), findsOneWidget);
    expect(find.text('Which national park is next to Voi?'), findsNothing);
    r.controller.dispose();
  });

  testWidgets('closed: says so', (tester) async {
    setTallPhone(tester);
    final r = CRig();
    r.repo.checkpointReply = () => cp({'state': 'closed', 'can_answer': false});
    await r.open(tester);
    expect(find.text('This town closed more than a week ago.'), findsOneWidget);
    r.controller.dispose();
  });

  testWidgets('no question for the grade yet', (tester) async {
    setTallPhone(tester);
    final r = CRig();
    r.repo.checkpointReply = () => cp({'fact': null, 'question': null, 'options': <dynamic>[], 'can_answer': false});
    await r.open(tester);
    expect(find.text("Today's question for your grade is being prepared. Come back soon."), findsOneWidget);
    r.controller.dispose();
  });

  testWidgets('a 404 shows the same kind note and a way back', (tester) async {
    setTallPhone(tester);
    final r = CRig();
    r.repo.checkpointReply = () => const NotFoundError();
    await r.open(tester);
    expect(find.text("Today's question for your grade is being prepared. Come back soon."), findsOneWidget);
    await tester.tap(find.text('Back to Elimu Quest'));
    expect(r.closed, 1);
    r.controller.dispose();
  });

  testWidgets('Launch Day is practice', (tester) async {
    setTallPhone(tester);
    final r = CRig(day: 0);
    r.repo.checkpointReply = () => cp({'day': 0, 'km_expected': 0.0, 'full_km': 0.0, 'coins_expected': 0});
    await r.open(tester);
    expect(find.text('Launch Day'), findsOneWidget);
    expect(find.text('Launch Day is for practice: no kilometres or coins today.'), findsOneWidget);
    expect(find.textContaining('Worth'), findsNothing);
    r.controller.dispose();
  });

  testWidgets('solved on load shows the unlocked stamp and the answer', (tester) async {
    setTallPhone(tester);
    final r = CRig();
    r.repo.checkpointReply = () => cp({'solved': true, 'can_answer': false, 'correct_answer': 'Tsavo East', 'answers': [
          {'attempt': 1, 'chosen': 'Tsavo East', 'correct': true, 'late': false, 'answered_at': null}
        ]});
    await r.open(tester);
    expect(find.text('Town unlocked'), findsOneWidget);
    expect(find.text('Unlocked'), findsOneWidget);
    expect(find.text('The answer is: Tsavo East'), findsOneWidget);
    r.controller.dispose();
  });

  testWidgets('offline: the option is kept and the retry reuses the same key', (tester) async {
    setTallPhone(tester);
    final r = CRig();
    r.repo.checkpointAnswerReplies.addAll([const OfflineError(), result()]);
    await r.open(tester);
    await tester.tap(find.text('Tsavo East'));
    await tester.pump();
    await tester.tap(find.text('Answer'));
    await tester.pump();
    expect(find.text('Your answer is kept. Check your connection, then press Answer again.'), findsOneWidget);
    expect(r.controller.selected, 'Tsavo East');

    await tester.tap(find.text('Answer'));
    await tester.pump();
    expect(r.repo.checkpointAnswers, hasLength(2));
    expect(r.repo.checkpointAnswers[0].key, r.repo.checkpointAnswers[1].key);
    expect(find.text('Hongera!'), findsOneWidget);
    r.controller.dispose();
  });

  testWidgets('already answered on another device: reloads and shows what the server has', (tester) async {
    setTallPhone(tester);
    final r = CRig();
    r.repo.checkpointAnswerReplies.add(const ConflictError(code: 'already_answered'));
    await r.open(tester);
    r.repo.checkpointReply = () => cp({'solved': true, 'can_answer': false, 'correct_answer': 'Tsavo East', 'answers': [
          {'attempt': 1, 'chosen': 'Tsavo East', 'correct': true, 'late': false, 'answered_at': null}
        ]});
    await tester.tap(find.text('Amboseli'));
    await tester.pump();
    await tester.tap(find.text('Answer'));
    await tester.pump();
    expect(r.repo.checkpointCalls, 2);
    expect(find.text('Town unlocked'), findsOneWidget);
    r.controller.dispose();
  });

  testWidgets('a gate 409 tells the screen to leave', (tester) async {
    setTallPhone(tester);
    final r = CRig();
    r.repo.checkpointReply = () => const MsafaraGateError(code: 'terms_required');
    await r.open(tester);
    expect(r.gates.single, isA<MsafaraGateError>());
    r.controller.dispose();
  });

  testWidgets('Kiswahili copy', (tester) async {
    setTallPhone(tester);
    final r = CRig(lang: 'sw');
    await r.open(tester);
    expect(find.text('Kadi ya posta kutoka Voi'), findsOneWidget);
    expect(find.text('Swali la kituo'), findsOneWidget);
    expect(find.text('Jibu'), findsOneWidget);
    r.controller.dispose();
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('360 dp, text x$scale: no overflow, 48 dp and labelled targets', (tester) async {
      final semantics = tester.ensureSemantics();
      setPhone(tester);
      final r = CRig();
      await r.open(tester, scale: scale);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
      r.controller.dispose();
    });
  }
}
