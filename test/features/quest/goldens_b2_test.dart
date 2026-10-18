import 'dart:io';

import 'package:elimupepe/core/design/clay.dart';
import 'package:elimupepe/features/quest/quest_home_page.dart';
import 'package:elimupepe/features/quest/quest_read_page.dart';
import 'package:elimupepe/features/quest/questions_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_test.dart' show Taps, loaded;
import 'questions_test.dart' show QRig, answerOf;
import 'read_page_test.dart' show ReadRig, lockOf;
import 'support.dart';

/// Goldens of the Elimu Quest home, the reader lock (running and paused) and the questions at 360x780 dp
/// (rendered at 2x), reduced motion on.
///
/// Regenerate with: flutter test --update-goldens test/features/quest/goldens_b2_test.dart
/// Goldens are generated and compared on Windows; other platforms render text slightly differently.
void main() {
  setUpAll(loadClayFonts);

  Future<void> shot(
    WidgetTester tester,
    String name,
    Widget app, {
    required ClayThemeMode mode,
    required double scale,
    Future<void> Function()? after,
  }) async {
    await withShadows(() async {
      setPhone(tester, dpr: 2.0);
      await tester.pumpWidget(app);
      await tester.pump();
      await tester.pump();
      await after?.call();
      await tester.pump(const Duration(milliseconds: 100));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/${name}_${goldenKey(mode, scale)}.png'));
    });
  }

  ClayThemeOptions opts(ClayThemeMode m) => ClayThemeOptions(mode: m, reduceMotion: true);

  for (final (mode, scale) in [
    (ClayThemeMode.light, 1.0),
    (ClayThemeMode.light, 2.0),
    (ClayThemeMode.dark, 1.0),
  ]) {
    testWidgets('home [${mode.name} x$scale]', (tester) async {
      final rig = QuestRig((o) => ok('state_active'));
      final c = await loaded('home');
      await shot(
        tester,
        'home',
        screenApp(QuestHomePage(session: rig.session, controller: c, actions: Taps().actions),
            options: opts(mode), textScale: scale),
        mode: mode,
        scale: scale,
      );
    });

    testWidgets('reader lock running [${mode.name} x$scale]', (tester) async {
      final r = ReadRig();
      await shot(
        tester,
        'reader_running',
        screenApp(
          QuestReadPage(
            session: r.session,
            detail: r.detail,
            fetchPdf: (u) async => File('book.pdf'),
            onAnswer: () {},
            onClose: () {},
            pdfBuilder: (c, f, s, p, n) => const Center(child: Text('PDF')),
          ),
          options: opts(mode),
          textScale: scale,
        ),
        mode: mode,
        scale: scale,
      );
    });
  }

  testWidgets('reader lock paused [light x1.0]', (tester) async {
    final r = ReadRig();
    r.repo.pingReply = (n) => lockOf({'in_range': false});
    await shot(
      tester,
      'reader_paused',
      screenApp(
        QuestReadPage(
          session: r.session,
          detail: r.detail,
          fetchPdf: (u) async => File('book.pdf'),
          onAnswer: () {},
          onClose: () {},
          pdfBuilder: (c, f, s, p, n) => const Center(child: Text('PDF')),
        ),
        options: opts(ClayThemeMode.light),
      ),
      mode: ClayThemeMode.light,
      scale: 1.0,
    );
  });

  testWidgets('reader lock paused [light x2.0]', (tester) async {
    final r = ReadRig();
    r.repo.pingReply = (n) => lockOf({'in_range': false});
    await shot(
      tester,
      'reader_paused',
      screenApp(
        QuestReadPage(
          session: r.session,
          detail: r.detail,
          fetchPdf: (u) async => File('book.pdf'),
          onAnswer: () {},
          onClose: () {},
          pdfBuilder: (c, f, s, p, n) => const Center(child: Text('PDF')),
        ),
        options: opts(ClayThemeMode.light),
        textScale: 2.0,
      ),
      mode: ClayThemeMode.light,
      scale: 2.0,
    );
  });

  testWidgets('reader lock unlocked [light x1.0]', (tester) async {
    final r = ReadRig();
    r.repo.pingReply = (n) => lockOf({'unlocked': true, 'seconds': 180, 'remaining': 0});
    await shot(
      tester,
      'reader_unlocked',
      screenApp(
        QuestReadPage(
          session: r.session,
          detail: r.detail,
          fetchPdf: (u) async => File('book.pdf'),
          onAnswer: () {},
          onClose: () {},
          pdfBuilder: (c, f, s, p, n) => const Center(child: Text('PDF')),
        ),
        options: opts(ClayThemeMode.light),
      ),
      mode: ClayThemeMode.light,
      scale: 1.0,
    );
  });

  for (final (mode, scale) in [
    (ClayThemeMode.light, 1.0),
    (ClayThemeMode.light, 2.0),
    (ClayThemeMode.dark, 1.0),
  ]) {
    testWidgets('questions, a question [${mode.name} x$scale]', (tester) async {
      final r = QRig();
      await r.controller.load();
      await shot(
        tester,
        'questions_question',
        screenApp(QuestionsPage(session: r.session, controller: r.controller, onClose: () {}),
            options: opts(mode), textScale: scale),
        mode: mode,
        scale: scale,
      );
      r.controller.dispose();
    });

    testWidgets('questions, feedback [${mode.name} x$scale]', (tester) async {
      final r = QRig();
      r.repo.answerReplies.add(answerOf('answer'));
      await r.controller.load();
      r.controller.setText('Tana');
      await r.controller.submit();
      await shot(
        tester,
        'questions_feedback',
        screenApp(QuestionsPage(session: r.session, controller: r.controller, onClose: () {}),
            options: opts(mode), textScale: scale),
        mode: mode,
        scale: scale,
      );
      r.controller.dispose();
    });
  }
}
