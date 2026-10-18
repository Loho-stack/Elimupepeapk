import 'dart:io';

import 'package:elimupepe/data/api_error.dart';
import 'package:elimupepe/data/models/msafara_quests.dart';
import 'package:elimupepe/features/quest/quest_read_page.dart';
import 'package:elimupepe/features/quest/quest_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

QuestLock lockOf(Map<String, dynamic> over) => QuestLock.fromJson({...data('ping'), ...over});

/// The reading screen on a fake repository and a fake PDF view (pdfx needs a real device).
class ReadRig {
  ReadRig({String fixture = 'quest_book', this.fetch}) {
    repo = FakeQuestRepo();
    session = MsafaraSession(repo);
    detail = QuestDetail.fromJson(data(fixture));
  }

  late final FakeQuestRepo repo;
  late final MsafaraSession session;
  late final QuestDetail detail;
  Future<File> Function(String url)? fetch;

  final navigator = PdfNavigator();
  final goTo = <int>[];
  void Function(int)? pageChanged;
  var answered = 0;
  var closed = 0;
  var fetches = 0;

  Future<File> _fetch(String url) {
    fetches++;
    return (fetch ?? (u) async => File('book.pdf'))(url);
  }

  Widget build({double scale = 1.0}) => screenApp(
        QuestReadPage(
          session: session,
          detail: detail,
          fetchPdf: detail.book == null ? null : _fetch,
          onAnswer: () => answered++,
          onClose: () => closed++,
          pdfBuilder: (context, file, start, onPage, nav) {
            pageChanged = onPage;
            nav.goTo = goTo.add;
            return Center(child: Text('PDF from page $start'));
          },
        ),
        textScale: scale,
      );
}

void main() {
  setUpAll(loadClayFonts);

  testWidgets('book: downloads, shows the book from the start page, pings with that page', (tester) async {
    setPhone(tester);
    final r = ReadRig();
    await tester.pumpWidget(r.build());
    await tester.pump();
    await tester.pump();

    expect(r.fetches, 1);
    expect(find.text('PDF from page 4'), findsOneWidget);
    expect(find.text('Pages 4 to 9'), findsOneWidget);
    expect(find.text('Page 4 of 64'), findsOneWidget);
    expect(r.repo.pingPages, [4]);
    expect(find.text('Keep reading: 2 minutes to go.'), findsOneWidget);
    expect(find.text('The questions open after that.'), findsOneWidget);
    r.session.dispose();
  });

  testWidgets('no ping goes out before the book is on screen', (tester) async {
    setPhone(tester);
    final r = ReadRig(fetch: (u) => Future<File>.delayed(const Duration(seconds: 3), () => File('book.pdf')));
    await tester.pumpWidget(r.build());
    await tester.pump(const Duration(seconds: 1));
    expect(r.repo.pingPages, isEmpty);
    await tester.pump(const Duration(seconds: 3));
    expect(r.repo.pingPages, [4]);
  });

  testWidgets('pings every 20 seconds with a fresh key each time, and the lock is the reply', (tester) async {
    setPhone(tester);
    final r = ReadRig();
    r.repo.pingReply = (n) => lockOf({'seconds': 95 + n * 20, 'remaining': 85 - n * 20});
    await tester.pumpWidget(r.build());
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 20));
    expect(r.repo.pingPages, [4, 4]);
    expect(r.repo.pingKeys.toSet(), hasLength(2), reason: 'a fresh key for every ping');
    expect(find.text('Keep reading: 1 minutes to go.'), findsOneWidget);
  });

  testWidgets('a page change sends a ping with the new page', (tester) async {
    setPhone(tester);
    final r = ReadRig();
    await tester.pumpWidget(r.build());
    await tester.pump();
    await tester.pump();
    r.pageChanged!(5);
    await tester.pump(const Duration(seconds: 6));
    expect(r.repo.pingPages, [4, 5]);
    expect(find.text('Page 5 of 64'), findsOneWidget);
  });

  testWidgets('off the quest pages: the ring pauses, says so, and Go to page N moves the book', (tester) async {
    setPhone(tester);
    final r = ReadRig();
    r.repo.pingReply = (n) => lockOf({'in_range': false});
    await tester.pumpWidget(r.build());
    await tester.pump();
    await tester.pump();

    expect(find.text('Time is paused.'), findsOneWidget);
    expect(find.text("These pages do not count for today's quest. Read pages 4 to 9."), findsOneWidget);
    expect(find.text('Go to page 4'), findsOneWidget);
    expect(find.text('Keep reading: 2 minutes to go.'), findsNothing);

    await tester.tap(find.text('Go to page 4'));
    expect(r.goTo, [4]);
  });

  testWidgets('when it is running again the pause note goes away', (tester) async {
    setPhone(tester);
    final r = ReadRig();
    r.repo.pingReply = (n) => n == 1 ? lockOf({'in_range': false}) : lockOf({'seconds': 100});
    await tester.pumpWidget(r.build());
    await tester.pump();
    await tester.pump();
    expect(find.text('Time is paused.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 20));
    expect(find.text('Time is paused.'), findsNothing);
  });

  testWidgets('unlocked: the lock is full and Answer the questions opens the questions', (tester) async {
    setPhone(tester);
    final r = ReadRig();
    r.repo.pingReply = (n) => lockOf({'unlocked': true, 'seconds': 180, 'remaining': 0});
    await tester.pumpWidget(r.build());
    await tester.pump();
    await tester.pump();

    expect(find.text('Unlocked! The questions are ready. Twende!'), findsOneWidget);
    await tester.tap(find.text('Answer the questions'));
    expect(r.answered, 1);

    // No more pings once it is unlocked.
    final sent = r.repo.pingPages.length;
    await tester.pump(const Duration(seconds: 60));
    expect(r.repo.pingPages, hasLength(sent));
  });

  testWidgets('the ring says what it is and how far along', (tester) async {
    final semantics = tester.ensureSemantics();
    setPhone(tester);
    final r = ReadRig();
    await tester.pumpWidget(r.build());
    await tester.pump();
    await tester.pump();
    expect(find.bySemanticsLabel('Reading time before the questions open'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('in the background nothing is sent; coming back sends one', (tester) async {
    setPhone(tester);
    final r = ReadRig();
    await tester.pumpWidget(r.build());
    await tester.pump();
    await tester.pump();
    final before = r.repo.pingPages.length;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 70));
    expect(r.repo.pingPages, hasLength(before));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(r.repo.pingPages, hasLength(before + 1));
  });

  testWidgets('while another screen covers it, nothing is sent', (tester) async {
    setPhone(tester);
    final r = ReadRig();
    await tester.pumpWidget(r.build());
    await tester.pump();
    await tester.pump();
    final before = r.repo.pingPages.length;

    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('COVER'))));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 50));
    expect(r.repo.pingPages, hasLength(before));

    nav.pop();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 20));
    expect(r.repo.pingPages.length, greaterThan(before));
  });

  testWidgets('a 429 on a ping shows nothing and keeps the last lock', (tester) async {
    setPhone(tester);
    final r = ReadRig();
    r.repo.pingReply = (n) => n == 2 ? const RateLimitedError() : lockOf({'seconds': 100, 'remaining': 80});
    await tester.pumpWidget(r.build());
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 20));
    expect(r.repo.pingPages, hasLength(2));
    expect(find.text('Keep reading: 2 minutes to go.'), findsOneWidget);
    expect(find.textContaining('Too many'), findsNothing);
    expect(r.closed, 0);
  });

  testWidgets('a gate answer on a ping routes away', (tester) async {
    setPhone(tester);
    final r = ReadRig();
    r.repo.pingReply = (n) => const MsafaraGateError(code: 'terms_required');
    await tester.pumpWidget(r.build());
    await tester.pump();
    await tester.pump();
    expect(r.closed, 1);
  });

  testWidgets('a book that cannot be downloaded says so and can be tried again', (tester) async {
    setPhone(tester);
    var fail = true;
    final r = ReadRig(fetch: (u) async => fail ? throw const PdfFailure() : File('book.pdf'));
    await tester.pumpWidget(r.build());
    await tester.pump();
    await tester.pump();
    expect(find.text('The book could not be opened. Check your connection and try again.'), findsOneWidget);
    expect(r.repo.pingPages, isEmpty);

    fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();
    expect(find.text('PDF from page 4'), findsOneWidget);
    expect(r.repo.pingPages, [4]);
  });

  testWidgets('lesson: shows the text, pings without a page', (tester) async {
    setPhone(tester);
    final r = ReadRig(fixture: 'quest_lesson');
    await tester.pumpWidget(r.build());
    await tester.pump();
    await tester.pump();
    expect(find.text('Methali za Kiswahili'), findsOneWidget);
    expect(find.text('Paragraph one.'), findsOneWidget);
    expect(find.text('Paragraph two.'), findsOneWidget);
    expect(r.repo.pingPages, [null]);
    expect(r.fetches, 0);
    expect(find.textContaining('Page '), findsNothing);
  });

  for (final scale in [1.0, 2.0]) {
    for (final paused in [false, true]) {
      testWidgets('360 dp, text x$scale, ${paused ? 'paused' : 'running'}: no overflow, 48 dp targets', (tester) async {
        final semantics = tester.ensureSemantics();
        setPhone(tester);
        final r = ReadRig();
        if (paused) r.repo.pingReply = (n) => lockOf({'in_range': false});
        await tester.pumpWidget(r.build(scale: scale));
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
      });
    }
  }
}

class PdfFailure implements Exception {
  const PdfFailure();
}
