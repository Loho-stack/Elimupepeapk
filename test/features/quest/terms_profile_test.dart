import 'package:dio/dio.dart';
import 'package:elimupepe/core/network/api_exception.dart';
import 'package:elimupepe/features/quest/profile_page.dart';
import 'package:elimupepe/features/quest/terms_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import 'support.dart';

void main() {
  setUpAll(loadClayFonts);

  group('TermsPage', () {
    Future<QuestRig> open(WidgetTester tester, Responder handler, {VoidCallback? onDone, double scale = 1.0}) async {
      setTallPhone(tester);
      final rig = QuestRig(handler);
      await tester.pumpWidget(screenApp(TermsPage(session: rig.session, onDone: onDone), textScale: scale));
      await settle(tester);
      return rig;
    }

    testWidgets('renders the server text exactly, with both attestations', (tester) async {
      await open(tester, (o) => ok('terms'));
      for (final t in [
        'Welcome to Elimu Quest!',
        'Elimu Quest is a journey across Kenya. Every day you visit a new town, read, learn and earn kilometres (KM).',
        'What we keep',
        'Your name, your grade and your county.',
        'Play fair',
        'I accept the Elimu Quest terms and conditions.',
        'My parent or guardian has agreed that I can take part in Elimu Quest.',
        'Your parent or guardian can also say yes in their own ElimuPepe account.',
      ]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
    });

    testWidgets('asks the server for the language of the session', (tester) async {
      final rig = await open(tester, (o) => ok('terms'));
      expect(rig.calls('GET', '/msafara/terms').single.queryParameters, {'lang': 'en'});
      await tester.runAsync(() => rig.session.setLanguage('sw'));
      await settle(tester);
      expect(rig.calls('GET', '/msafara/terms').last.queryParameters, {'lang': 'sw'});
    });

    testWidgets('Continue needs both boxes; then it posts both as true with an Idempotency-Key', (tester) async {
      var done = 0;
      final rig = await open(tester, (o) => switch ((o.method, o.path)) {
            ('POST', '/msafara/terms') => ok('terms_accepted'),
            ('GET', '/msafara/state') => ok('state_countdown'),
            _ => ok('terms'),
          }, onDone: () => done++);

      await tester.tap(find.text('Continue'), warnIfMissed: false);
      await tester.pump();
      expect(rig.calls('POST', '/msafara/terms'), isEmpty);

      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      await tester.tap(find.text('Continue'), warnIfMissed: false);
      await tester.pump();
      expect(rig.calls('POST', '/msafara/terms'), isEmpty, reason: 'one box is not enough');

      await tester.tap(find.byType(Checkbox).last);
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await settle(tester);

      final post = rig.calls('POST', '/msafara/terms').single;
      expect(post.data, {'accept_terms': true, 'parent_agreed': true});
      expect(post.headers['Idempotency-Key'], isA<String>());
      expect(rig.calls('GET', '/msafara/state'), hasLength(1));
      expect(done, 1);
    });

    testWidgets('offline keeps the same key for the retry and says so', (tester) async {
      var offline = true;
      final rig = await open(tester, (o) {
        if (o.method == 'POST') {
          if (offline) throw DioException(requestOptions: o, error: const OfflineException());
          return ok('terms_accepted');
        }
        return o.path == '/msafara/state' ? ok('state_countdown') : ok('terms');
      });
      await tester.tap(find.byType(Checkbox).first);
      await tester.tap(find.byType(Checkbox).last);
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await settle(tester);
      expect(find.textContaining('You are offline'), findsOneWidget);

      offline = false;
      await tester.tap(find.text('Continue'));
      await settle(tester);
      final keys = rig.calls('POST', '/msafara/terms').map((o) => o.headers['Idempotency-Key']).toList();
      expect(keys, hasLength(2));
      expect(keys[0], keys[1]);
    });

    testWidgets('a terms_required style gate on the post refreshes the state', (tester) async {
      var done = 0;
      final rig = await open(tester, (o) {
        if (o.method == 'POST') return gate('not_started');
        return o.path == '/msafara/state' ? ok('state_countdown') : ok('terms');
      }, onDone: () => done++);
      await tester.tap(find.byType(Checkbox).first);
      await tester.tap(find.byType(Checkbox).last);
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await settle(tester);
      expect(rig.calls('GET', '/msafara/state'), hasLength(1));
      expect(done, 1);
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('360 dp, text x$scale: no overflow, labelled targets', (tester) async {
        final semantics = tester.ensureSemantics();
        await open(tester, (o) => ok('terms'), scale: scale);
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
      });
    }
  });

  group('ProfilePage', () {
    Future<QuestRig> open(WidgetTester tester, Responder handler, {VoidCallback? onDone, double scale = 1.0}) async {
      setTallPhone(tester);
      final rig = QuestRig(handler);
      await tester.pumpWidget(screenApp(ProfilePage(session: rig.session, onDone: onDone), textScale: scale));
      await settle(tester);
      return rig;
    }

    testWidgets('choose grade and county from the options, then save only those', (tester) async {
      var done = 0;
      final rig = await open(tester, (o) => switch ((o.method, o.path)) {
            ('POST', '/msafara/profile') => ok('profile_saved'),
            ('GET', '/msafara/state') => ok('state_active'),
            _ => ok('profile'),
          }, onDone: () => done++);

      expect(find.text('Tell us about you'), findsOneWidget);
      // Start is disabled until both are chosen.
      await tester.tap(find.text('Start my journey'), warnIfMissed: false);
      await tester.pump();
      expect(rig.calls('POST', '/msafara/profile'), isEmpty);

      await tester.tap(find.text('Your grade'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Grade 4'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Your county'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nairobi'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start my journey'));
      await settle(tester);

      final post = rig.calls('POST', '/msafara/profile').single;
      expect(post.data, {'grade': 'G4', 'county': 'Nairobi'});
      expect(post.headers['Idempotency-Key'], isA<String>());
      expect(done, 1);
    });

    testWidgets('a field the account already has is read only and not sent', (tester) async {
      final form = data('profile')
        ..['missing'] = ['county']
        ..['grade'] = 'G4';
      final rig = await open(tester, (o) => switch ((o.method, o.path)) {
            ('POST', '/msafara/profile') => ok('profile_saved'),
            ('GET', '/msafara/state') => ok('state_active'),
            _ => jsonBody({'success': true, 'data': form}),
          });
      expect(find.text('Grade 4'), findsOneWidget);

      await tester.tap(find.text('Your county'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bomet'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start my journey'));
      await settle(tester);
      expect(rig.calls('POST', '/msafara/profile').single.data, {'county': 'Bomet'});
    });

    testWidgets('a 422 marks the field and the retry is a new action', (tester) async {
      var attempts = 0;
      final rig = await open(tester, (o) {
        if (o.method == 'POST') {
          attempts++;
          return jsonBody({
            'success': false,
            'message': 'The given data was invalid.',
            'errors': {'county': ['Choose your county.']},
          }, status: 422);
        }
        return ok('profile');
      });
      await tester.tap(find.text('Your grade'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PP1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Your county'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Baringo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start my journey'));
      await settle(tester);
      await tester.tap(find.text('Start my journey'));
      await settle(tester);

      expect(attempts, 2);
      expect(find.text('Check what you entered and try again.'), findsOneWidget);
      final keys = rig.calls('POST', '/msafara/profile').map((o) => o.headers['Idempotency-Key']).toList();
      expect(keys[0], isNot(keys[1]));
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('360 dp, text x$scale: no overflow, labelled targets', (tester) async {
        final semantics = tester.ensureSemantics();
        await open(tester, (o) => ok('profile'), scale: scale);
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
      });
    }
  });
}
