import 'package:elimupepe/data/api_error.dart';
import 'package:elimupepe/data/models/msafara_me.dart';
import 'package:elimupepe/features/quest/me_page.dart';
import 'package:elimupepe/features/quest/quest_session.dart';
import 'package:elimupepe/features/quest/terms_page.dart';
import 'package:elimupepe/features/student/load_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart' show jsonBody;
import 'support.dart';

MeData meOf([Map<String, dynamic> over = const {}]) => MeData.fromJson({...data('me'), ...over});

class MRig {
  MRig({MeData? me, String lang = 'en'}) {
    repo = FakeQuestRepo();
    session = MsafaraSession(repo, initialLanguage: lang);
    repo.meReply = () => me ?? meOf();
    controller = LoadController<MeData>(repo.me);
  }

  late final FakeQuestRepo repo;
  late final MsafaraSession session;
  late final LoadController<MeData> controller;
  var termsOpened = 0;

  Widget build({double scale = 1.0}) => screenApp(
        MePage(session: session, controller: controller, onOpenTerms: () => termsOpened++),
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

  group('model and repository', () {
    test('from the contract example', () {
      final m = MeData.fromJson(data('me'));
      expect((m.name, m.grade, m.gradeKey, m.gradeBand, m.county), ('Amina Wanjiru', 'Grade 4', 'G4', 'G4-6', 'Nairobi'));
      expect((m.boardName, m.parentalConsent, m.hideName, m.boards, m.sound), ('Amina W.', true, false, true, true));
      expect(m.km.total, 182.5);
    });

    test('copyWith changes only the switches', () {
      final m = MeData.fromJson(data('me')).copyWith(hideName: true, sound: false);
      expect((m.hideName, m.sound, m.name, m.county), (true, false, 'Amina Wanjiru', 'Nairobi'));
    });

    test('me, sound and hide-name send the contract bodies with a key', () async {
      final rig = QuestRig((o) => switch (o.path) {
            '/msafara/me' => ok('me'),
            '/msafara/me/sound' => jsonBody({'success': true, 'data': {'sound': 'off'}}),
            _ => jsonBody({'success': true, 'data': {'hide_name': true}}),
          });
      await rig.repo.me();
      expect(await rig.repo.setSound(false, key: 'k1'), isFalse);
      expect(await rig.repo.setHideName(true, key: 'k2'), isTrue);
      final seen = rig.adapter.seen;
      expect(seen[1].data, {'sound': 'off'});
      expect(seen[1].headers['Idempotency-Key'], 'k1');
      expect(seen[2].path, '/msafara/me/hide-name');
      expect(seen[2].data, {'hide': 'yes'});
      expect(seen[2].headers['Idempotency-Key'], 'k2');
    });

    test('the sound reply on means true', () async {
      final rig = QuestRig((o) => jsonBody({'success': true, 'data': {'sound': 'on'}}));
      expect(await rig.repo.setSound(true, key: 'k'), isTrue);
      expect(rig.adapter.seen.single.data, {'sound': 'on'});
    });
  });

  testWidgets('shows who the learner is and how others see them', (tester) async {
    setTallPhone(tester);
    final r = MRig();
    await r.open(tester);
    for (final t in [
      'Amina Wanjiru',
      'Grade 4',
      'G4-6',
      'Nairobi',
      '182.5',
      'Leaderboards',
      'How others see you',
      'Amina W.',
      'Others see your first name, the first letter of your last name, your grade and your county. Never your email, phone number or school.',
      'Hide my name from leaderboards',
      'Sound',
      'Sound and vibration are on.',
      'Elimu Quest terms',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
  });

  testWidgets('without parental consent only the initial is shown', (tester) async {
    setTallPhone(tester);
    final r = MRig(me: meOf({'parental_consent': false, 'board_name': 'A.'}));
    await r.open(tester);
    expect(find.text('A.'), findsOneWidget);
    expect(find.textContaining('parental consent is not recorded'), findsOneWidget);
  });

  testWidgets('hide my name: sends yes with a key, then shows Hidden and the offer to show it again', (tester) async {
    setTallPhone(tester);
    final r = MRig();
    r.repo.hideReplies.add(true);
    await r.open(tester);
    await tester.tap(find.text('Hide my name from leaderboards'));
    await tester.pump();

    expect(r.repo.hideCalls.single.hide, isTrue);
    expect(r.repo.hideCalls.single.key, isNotEmpty);
    expect(find.text('Hidden'), findsOneWidget);
    expect(find.text('Your name is hidden. Your kilometres still count, and only you can see your place.'), findsOneWidget);
    expect(find.text('Show my name on leaderboards'), findsOneWidget);

    r.repo.hideReplies.add(false);
    await tester.tap(find.text('Show my name on leaderboards'));
    await tester.pump();
    expect(r.repo.hideCalls.last.hide, isFalse);
    expect(find.text('Amina W.'), findsOneWidget);
  });

  testWidgets('sound off: the switch and the line change', (tester) async {
    setTallPhone(tester);
    final r = MRig();
    r.repo.soundReplies.add(false);
    await r.open(tester);
    await tester.tap(find.text('Sound'));
    await tester.pump();
    expect(r.repo.soundCalls.single.on, isFalse);
    expect(find.text('Sound and vibration are off.'), findsOneWidget);
  });

  testWidgets('offline: a message, the switch stays, and the retry reuses the key', (tester) async {
    setTallPhone(tester);
    final r = MRig();
    r.repo.soundReplies.addAll([const OfflineError(), false]);
    await r.open(tester);
    await tester.tap(find.text('Sound'));
    await tester.pump();
    expect(find.textContaining('You are offline'), findsOneWidget);
    expect(find.text('Sound and vibration are on.'), findsOneWidget);

    await tester.tap(find.text('Sound'));
    await tester.pump();
    expect(r.repo.soundCalls, hasLength(2));
    expect(r.repo.soundCalls[0].key, r.repo.soundCalls[1].key);
    expect(find.text('Sound and vibration are off.'), findsOneWidget);
  });

  testWidgets('boards off: a note instead of the switch; hide-name 404 says so', (tester) async {
    setTallPhone(tester);
    final r = MRig(me: meOf({'boards': false}));
    await r.open(tester);
    expect(find.text('The leaderboards are not open yet'), findsOneWidget);
    expect(find.text('Hide my name from leaderboards'), findsNothing);

    final r2 = MRig();
    r2.repo.hideReplies.add(const NotFoundError());
    await tester.pumpWidget(const SizedBox());
    await r2.open(tester);
    await tester.tap(find.text('Hide my name from leaderboards'));
    await tester.pump();
    expect(find.text('The leaderboards are not open yet'), findsOneWidget);
  });

  testWidgets('a grade with no leaderboard group says the kilometres still count', (tester) async {
    setTallPhone(tester);
    final r = MRig(me: meOf({'grade_band': null, 'grade': 'Grade 11'}));
    await r.open(tester);
    expect(find.text('None'), findsOneWidget);
    expect(find.text('Your kilometres count'), findsOneWidget);
  });

  testWidgets('a gate 409 on a switch refreshes the state', (tester) async {
    setTallPhone(tester);
    final r = MRig();
    r.repo.soundReplies.add(const MsafaraGateError(code: 'terms_required'));
    await r.open(tester);
    await tester.tap(find.text('Sound'));
    await tester.pump();
    expect(r.session.refreshing, isNotNull);
  });

  testWidgets('the terms link opens the terms', (tester) async {
    setTallPhone(tester);
    final r = MRig();
    await r.open(tester);
    await tester.tap(find.text('Elimu Quest terms'));
    expect(r.termsOpened, 1);
  });

  testWidgets('the language chips switch the copy', (tester) async {
    setTallPhone(tester);
    final r = MRig();
    await r.open(tester);
    await tester.tap(find.text('Kiswahili'));
    await tester.pump();
    expect(find.text('Masharti ya Elimu Quest'), findsOneWidget);
    expect(find.text('Sauti'), findsOneWidget);
  });

  testWidgets('the terms page in read-only mode has no boxes and no Continue', (tester) async {
    setTallPhone(tester);
    final repo = FakeQuestRepo();
    final session = MsafaraSession(repo);
    await tester.pumpWidget(screenApp(TermsPage(session: session, readOnly: true)));
    await tester.pump();
    await tester.pump();
    expect(find.text('Welcome to Elimu Quest!'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.text('Continue'), findsNothing);
    expect(find.text('What we keep'), findsOneWidget);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('360 dp, text x$scale: no overflow, 48 dp and labelled targets', (tester) async {
      final semantics = tester.ensureSemantics();
      setPhone(tester);
      final r = MRig();
      await r.open(tester, scale: scale);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });
  }
}
