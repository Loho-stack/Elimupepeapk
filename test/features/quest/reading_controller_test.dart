import 'package:elimupepe/data/api_error.dart';
import 'package:elimupepe/data/models/msafara_quests.dart';
import 'package:elimupepe/features/quest/reading_controller.dart';
import 'package:flutter_test/flutter_test.dart';

QuestLock lock({bool unlocked = false, int seconds = 0, bool inRange = true}) => QuestLock(
      unlocked: unlocked,
      seconds: seconds,
      remaining: 180 - seconds,
      requiredSeconds: 180,
      inRange: inRange,
      pageFrom: 4,
      pageTo: 9,
    );

/// Drives the controller on fake time: [tester.pump] moves both the timers and the clock the
/// controller reads.
class Rig {
  Rig(this.tester, {this.visible = true}) {
    controller = ReadingController(
      initial: lock(),
      initialPage: 4,
      now: () => clock,
      isVisible: () => visible,
      onError: errors.add,
      ping: (page) async {
        pages.add(page);
        final r = reply(pages.length);
        if (r is AppApiError) throw r;
        return r as QuestLock;
      },
    );
  }

  final WidgetTester tester;
  bool visible;
  DateTime clock = DateTime(2026, 10, 30, 9);
  late final ReadingController controller;
  final pages = <int?>[];
  final errors = <AppApiError>[];

  /// What the n-th ping (1-based) answers: a [QuestLock] or an [AppApiError].
  Object Function(int n) reply = (n) => lock(seconds: n * 20);

  Future<void> advance(Duration d) async {
    clock = clock.add(d);
    await tester.pump(d);
  }
}

void main() {
  testWidgets('pings on start with the start page, then every 20 seconds', (tester) async {
    final r = Rig(tester);
    r.controller.start();
    await tester.pump();
    expect(r.pages, [4]);
    await r.advance(const Duration(seconds: 20));
    await r.advance(const Duration(seconds: 20));
    expect(r.pages, [4, 4, 4]);
    expect(r.controller.lock.seconds, 60, reason: 'the lock is the last reply, not a local count');
    r.controller.dispose();
  });

  testWidgets('a lesson pings without a page', (tester) async {
    final r = Rig(tester);
    final c = ReadingController(initial: lock(), ping: (p) async {
      r.pages.add(p);
      return lock(seconds: 20);
    });
    c.start();
    await tester.pump();
    expect(r.pages, [null]);
    c.dispose();
    r.controller.dispose();
  });

  testWidgets('no pings in the background; coming back pings at once', (tester) async {
    final r = Rig(tester);
    r.controller.start();
    await tester.pump();
    r.controller.setForeground(false);
    await r.advance(const Duration(seconds: 60));
    expect(r.pages, hasLength(1));

    r.controller.setForeground(true);
    await tester.pump();
    expect(r.pages, hasLength(2));
    r.controller.dispose();
  });

  testWidgets('no pings while another screen covers this one', (tester) async {
    final r = Rig(tester);
    r.controller.start();
    await tester.pump();
    r.visible = false;
    await r.advance(const Duration(seconds: 40));
    expect(r.pages, hasLength(1));
    r.visible = true;
    await r.advance(const Duration(seconds: 20));
    expect(r.pages, hasLength(2));
    r.controller.dispose();
  });

  testWidgets('a page change pings at once, but never twice inside the gap', (tester) async {
    final r = Rig(tester);
    r.controller.start();
    await tester.pump();
    expect(r.pages, [4]);

    await r.advance(const Duration(seconds: 6));
    r.controller.onPage(5);
    await tester.pump();
    expect(r.pages, [4, 5]);

    // Quick flips inside 5 seconds: one ping with the latest page, after the gap.
    await r.advance(const Duration(seconds: 1));
    r.controller.onPage(6);
    r.controller.onPage(7);
    await tester.pump();
    expect(r.pages, [4, 5]);
    await r.advance(const Duration(seconds: 5));
    expect(r.pages, [4, 5, 7]);
    r.controller.dispose();
  });

  testWidgets('the same page again is not a change', (tester) async {
    final r = Rig(tester);
    r.controller.start();
    await tester.pump();
    r.controller.onPage(4);
    await tester.pump();
    expect(r.pages, hasLength(1));
    r.controller.dispose();
  });

  testWidgets('a 429 is skipped: no error, the last lock stays, the rhythm goes on', (tester) async {
    final r = Rig(tester)..reply = (n) => n == 2 ? const RateLimitedError() : lock(seconds: n * 20);
    r.controller.start();
    await tester.pump();
    expect(r.controller.lock.seconds, 20);

    await r.advance(const Duration(seconds: 20));
    expect(r.pages, hasLength(2));
    expect(r.controller.lock.seconds, 20, reason: 'kept the last lock');
    expect(r.errors, isEmpty);

    await r.advance(const Duration(seconds: 20));
    expect(r.controller.lock.seconds, 60);
    r.controller.dispose();
  });

  testWidgets('offline and server errors are skipped silently', (tester) async {
    final r = Rig(tester)..reply = (n) => n == 1 ? const OfflineError() : (n == 2 ? const ServerError() : lock(seconds: 40));
    r.controller.start();
    await tester.pump();
    await r.advance(const Duration(seconds: 20));
    expect(r.errors, isEmpty);
    await r.advance(const Duration(seconds: 20));
    expect(r.controller.lock.seconds, 40);
    r.controller.dispose();
  });

  testWidgets('a Msafara gate or a 404 is reported', (tester) async {
    final r = Rig(tester)..reply = (n) => const MsafaraGateError(code: 'terms_required');
    r.controller.start();
    await tester.pump();
    expect(r.errors.single, isA<MsafaraGateError>());
    r.controller.dispose();

    final r2 = Rig(tester)..reply = (n) => const NotFoundError();
    r2.controller.start();
    await tester.pump();
    expect(r2.errors.single, isA<NotFoundError>());
    r2.controller.dispose();
  });

  testWidgets('out of range is passed on, so the screen can pause and say so', (tester) async {
    final r = Rig(tester)..reply = (n) => lock(seconds: 95, inRange: false);
    r.controller.start();
    await tester.pump();
    expect(r.controller.lock.inRange, isFalse);
    expect(r.controller.lock.pageFrom, 4);
    r.controller.dispose();
  });

  testWidgets('unlocking stops the pings', (tester) async {
    final r = Rig(tester)..reply = (n) => lock(unlocked: true, seconds: 180);
    r.controller.start();
    await tester.pump();
    expect(r.controller.lock.unlocked, isTrue);
    await r.advance(const Duration(seconds: 60));
    expect(r.pages, hasLength(1));
    r.controller.dispose();
  });

  testWidgets('a ping is never sent while one is in flight', (tester) async {
    final r = Rig(tester);
    var running = 0;
    var overlap = false;
    final c = ReadingController(
      initial: lock(),
      initialPage: 4,
      interval: const Duration(seconds: 1),
      ping: (p) async {
        running++;
        if (running > 1) overlap = true;
        await Future<void>.delayed(const Duration(seconds: 3));
        running--;
        return lock(seconds: 20);
      },
    );
    c.start();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 4));
    expect(overlap, isFalse);
    c.dispose();
    await tester.pump(const Duration(seconds: 4)); // lets the last slow ping finish
    r.controller.dispose();
  });
}
