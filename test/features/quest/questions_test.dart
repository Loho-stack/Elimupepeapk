import 'package:elimupepe/core/design/clay.dart';
import 'package:elimupepe/data/api_error.dart';
import 'package:elimupepe/data/models/msafara_quests.dart';
import 'package:elimupepe/features/quest/quest_session.dart';
import 'package:elimupepe/features/quest/questions_controller.dart';
import 'package:elimupepe/features/quest/questions_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

AnswerResult answerOf(String fixture) => AnswerResult.fromJson(data(fixture));

class QRig {
  QRig({int no = 1, this.lang = 'en'}) {
    repo = FakeQuestRepo();
    session = MsafaraSession(repo, initialLanguage: lang);
    controller = QuestionsController(repo: repo, no: no, onGate: (e) => gates.add(e));
  }

  final String lang;
  late final FakeQuestRepo repo;
  late final MsafaraSession session;
  late final QuestionsController controller;
  final gates = <AppApiError>[];
  var closed = 0;

  Widget build({double scale = 1.0}) => screenApp(
        QuestionsPage(session: session, controller: controller, onClose: () => closed++),
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

  testWidgets('starts at the first unanswered question, one at a time', (tester) async {
    setTallPhone(tester);
    final r = QRig();
    await r.open(tester);
    expect(find.text('Question 2 of 3'), findsOneWidget);
    expect(find.text('The longest river in Kenya is the ___.'), findsOneWidget);
    expect(find.text('What is the capital of Kenya?'), findsNothing);
    expect(find.text('Type the missing word'), findsOneWidget);
    r.controller.dispose();
  });

  testWidgets('fill in the blank: Answer needs text, sends the trimmed word, shows the explanation', (tester) async {
    setTallPhone(tester);
    final r = QRig();
    r.repo.answerReplies.add(answerOf('answer'));
    await r.open(tester);

    await tester.tap(find.text('Answer'), warnIfMissed: false);
    await tester.pump();
    expect(r.repo.answers, isEmpty);

    await tester.enterText(find.byType(TextField), '  Tana ');
    await tester.pump();
    await tester.tap(find.text('Answer'));
    await tester.pump();

    expect(r.repo.answers.single.questionId, 8302);
    expect(r.repo.answers.single.text, 'Tana');
    expect(r.repo.answers.single.choice, isNull);
    expect(find.text('Hongera! That is right'), findsOneWidget);
    expect(find.text('You answered: Tana'), findsOneWidget);
    expect(find.text("The Tana is the longest river in Kenya."), findsOneWidget);
    expect(find.text('The answer is: Tana'), findsNothing, reason: 'only shown when wrong');
    r.controller.dispose();
  });

  testWidgets('true or false: the choice is the option number from 1; a wrong answer shows the right one', (tester) async {
    setTallPhone(tester);
    final r = QRig();
    r.repo.answerReplies.addAll([answerOf('answer'), answerOf('answer_last')]);
    await r.open(tester);

    await tester.enterText(find.byType(TextField), 'Tana');
    await tester.pump();
    await tester.tap(find.text('Answer'));
    await tester.pump();
    await tester.tap(find.text('Next question'));
    await tester.pump();

    expect(find.text('Question 3 of 3'), findsOneWidget);
    expect(find.text('True'), findsOneWidget);
    expect(find.text('False'), findsOneWidget);
    await tester.tap(find.text('False'));
    await tester.pump();
    await tester.tap(find.text('Answer'));
    await tester.pump();

    expect(r.repo.answers.last.choice, 2);
    expect(r.repo.answers.last.text, isNull);
    expect(find.text('Not this time'), findsOneWidget);
    expect(find.text('The answer is: True'), findsOneWidget);
    expect(find.text('Mombasa is a port city on the Indian Ocean.'), findsOneWidget);
    expect(r.repo.answers.map((a) => a.key).toSet(), hasLength(2), reason: 'a key per answer');
    r.controller.dispose();
  });

  testWidgets('the last answer leads to the score and the kilometres', (tester) async {
    setTallPhone(tester);
    final r = QRig();
    r.repo.answerReplies.addAll([answerOf('answer'), answerOf('answer_last')]);
    await r.open(tester);
    await tester.enterText(find.byType(TextField), 'Tana');
    await tester.pump();
    await tester.tap(find.text('Answer'));
    await tester.pump();
    await tester.tap(find.text('Next question'));
    await tester.pump();
    await tester.tap(find.text('False'));
    await tester.pump();
    await tester.tap(find.text('Answer'));
    await tester.pump();

    expect(find.text('See my result'), findsOneWidget);
    await tester.tap(find.text('See my result'));
    await tester.pump();

    expect(find.text('Quest done'), findsOneWidget);
    expect(find.text('2 of 3 right'), findsOneWidget);
    expect(find.text('Well done! You understood what you read.'), findsOneWidget);
    expect(find.text('Up to 10 km, on its way'), findsOneWidget);
    expect(find.text('Your answers'), findsOneWidget);
    expect(find.text('What is the capital of Kenya?'), findsOneWidget);

    await tester.tap(find.text('Back to Elimu Quest'));
    expect(r.closed, 1);
    r.controller.dispose();
  });

  testWidgets('under half right: the gentle message and the half-km note', (tester) async {
    setTallPhone(tester);
    final r = QRig();
    final j = data('answer_last');
    (j['quest'] as Map<String, dynamic>)
      ..['right'] = 1
      ..['score'] = 0.3333
      ..['km_expected'] = 5.0;
    r.repo.answerReplies.addAll([answerOf('answer'), AnswerResult.fromJson(j)]);
    await r.open(tester);
    await tester.enterText(find.byType(TextField), 'Tana');
    await tester.pump();
    await tester.tap(find.text('Answer'));
    await tester.pump();
    await tester.tap(find.text('Next question'));
    await tester.pump();
    await tester.tap(find.text('False'));
    await tester.pump();
    await tester.tap(find.text('Answer'));
    await tester.pump();
    await tester.tap(find.text('See my result'));
    await tester.pump();

    expect(find.textContaining('You finished it, and that counts'), findsOneWidget);
    expect(find.text('Up to 5 km, on its way'), findsOneWidget);
    expect(find.textContaining('earns half of the 10 km'), findsOneWidget);
    r.controller.dispose();
  });

  testWidgets('offline: a clear message, the answer is kept, and the retry reuses the same key', (tester) async {
    setTallPhone(tester);
    final r = QRig();
    r.repo.answerReplies.addAll([const OfflineError(), answerOf('answer')]);
    await r.open(tester);
    await tester.enterText(find.byType(TextField), 'Tana');
    await tester.pump();
    await tester.tap(find.text('Answer'));
    await tester.pump();

    expect(find.text('Your answer is kept. Check your connection, then press Answer again.'), findsOneWidget);
    expect(find.text('Hongera! That is right'), findsNothing);
    expect(find.text('Tana'), findsOneWidget, reason: 'the typed word is still there');

    await tester.tap(find.text('Answer'));
    await tester.pump();
    expect(find.text('Hongera! That is right'), findsOneWidget);
    expect(r.repo.answers, hasLength(2));
    expect(r.repo.answers[0].key, r.repo.answers[1].key);
    r.controller.dispose();
  });

  testWidgets('a 422 shows a message and the corrected answer is a new action', (tester) async {
    setTallPhone(tester);
    final r = QRig();
    r.repo.answerReplies.addAll([const ValidationError(), answerOf('answer')]);
    await r.open(tester);
    await tester.enterText(find.byType(TextField), 'Tana');
    await tester.pump();
    await tester.tap(find.text('Answer'));
    await tester.pump();
    expect(find.text('Check what you entered and try again.'), findsOneWidget);
    await tester.tap(find.text('Answer'));
    await tester.pump();
    expect(r.repo.answers[0].key, isNot(r.repo.answers[1].key));
    r.controller.dispose();
  });

  testWidgets('locked: says to read first and leads back to the reading', (tester) async {
    setTallPhone(tester);
    final r = QRig();
    r.repo.questionsReply = () => const QuestLockedError(remaining: 105);
    await r.open(tester);
    expect(find.text('Read first. The questions open when the reading time is done.'), findsOneWidget);
    await tester.tap(find.text('Back to reading'));
    expect(r.closed, 1);
    r.controller.dispose();
  });

  testWidgets('a quest closed on another device reloads and shows the result', (tester) async {
    setTallPhone(tester);
    final r = QRig();
    r.repo.answerReplies.add(const ConflictError(code: 'quest_completed'));
    await r.open(tester);
    r.repo.questionsReply = () => QuestionSet.fromJson({...data('questions'), 'completed': true, 'right': 2});
    await tester.enterText(find.byType(TextField), 'Tana');
    await tester.pump();
    await tester.tap(find.text('Answer'));
    await tester.pump();
    await tester.pump();
    expect(r.repo.questionsCalls, 2);
    expect(find.text('Quest done'), findsOneWidget);
    r.controller.dispose();
  });

  testWidgets('a gate 409 tells the screen to leave', (tester) async {
    setTallPhone(tester);
    final r = QRig();
    r.repo.questionsReply = () => const MsafaraGateError(code: 'terms_required');
    await r.open(tester);
    expect(r.gates.single, isA<MsafaraGateError>());
    r.controller.dispose();
  });

  testWidgets('a finished quest shows the answers without a km line', (tester) async {
    setTallPhone(tester);
    final r = QRig();
    r.repo.questionsReply = () => QuestionSet.fromJson({...data('questions'), 'completed': true, 'right': 2});
    await r.open(tester);
    expect(find.text('Quest done'), findsOneWidget);
    expect(find.textContaining('km, on its way'), findsNothing);
    expect(find.text('Your answers'), findsOneWidget);
    r.controller.dispose();
  });

  testWidgets('the bonus quest has no kilometres', (tester) async {
    setTallPhone(tester);
    final r = QRig(no: 6);
    final j = data('answer_last');
    (j['quest'] as Map<String, dynamic>)
      ..['passed'] = null
      ..['km_expected'] = 0.0;
    r.repo.answerReplies.addAll([answerOf('answer'), AnswerResult.fromJson(j)]);
    await r.open(tester);
    await tester.enterText(find.byType(TextField), 'Tana');
    await tester.pump();
    await tester.tap(find.text('Answer'));
    await tester.pump();
    await tester.tap(find.text('Next question'));
    await tester.pump();
    await tester.tap(find.text('False'));
    await tester.pump();
    await tester.tap(find.text('Answer'));
    await tester.pump();
    await tester.tap(find.text('See my result'));
    await tester.pump();
    expect(find.textContaining('km'), findsNothing);
    r.controller.dispose();
  });

  testWidgets('Kiswahili copy', (tester) async {
    setTallPhone(tester);
    final r = QRig(lang: 'sw');
    await r.open(tester);
    expect(find.text('Swali la 2 kati ya 3'), findsOneWidget);
    expect(find.text('Andika neno linalokosekana'), findsOneWidget);
    expect(find.text('Jibu'), findsOneWidget);
    r.controller.dispose();
  });

  testWidgets('the progress bar speaks the number answered and right', (tester) async {
    final semantics = tester.ensureSemantics();
    setTallPhone(tester);
    final r = QRig();
    await r.open(tester);
    expect(find.byWidgetPredicate((w) => w is ClayProgressBar && w.semanticLabel == '1 of 3 questions answered, 1 right'), findsOneWidget);
    semantics.dispose();
    r.controller.dispose();
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('360 dp, text x$scale: question and feedback have no overflow and 48 dp targets', (tester) async {
      final semantics = tester.ensureSemantics();
      setPhone(tester);
      final r = QRig();
      r.repo.answerReplies.add(answerOf('answer'));
      await r.open(tester, scale: scale);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      await tester.enterText(find.byType(TextField), 'Tana');
      await tester.pump();
      await tester.tap(find.text('Answer'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      semantics.dispose();
      r.controller.dispose();
    });
  }
}
