import 'package:elimupepe/core/design/clay.dart';
import 'package:elimupepe/features/quest/boards_page.dart';
import 'package:elimupepe/features/quest/quest_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'boards_test.dart' show BRig;
import 'support.dart';

/// Goldens of the Elimu Quest screens at 360x780 dp (rendered at 2x), reduced motion on.
///
/// Regenerate with: flutter test --update-goldens test/features/quest/goldens_test.dart
/// Goldens are generated and compared on Windows; other platforms render text slightly differently.
void main() {
  setUpAll(loadClayFonts);

  Future<void> golden(
    WidgetTester tester,
    String name,
    QuestRig rig, {
    required ClayThemeMode mode,
    required double scale,
    required Widget Function(QuestRig rig) screen,
  }) async {
    await withShadows(() async {
      setPhone(tester, dpr: 2.0);
      await loadState(tester, rig);
      await tester.pumpWidget(screenApp(
        screen(rig),
        options: ClayThemeOptions(mode: mode, reduceMotion: true),
        textScale: scale,
      ));
      await settle(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/${name}_${goldenKey(mode, scale)}.png'));
    });
  }

  Widget gate(QuestRig rig) => QuestGate(
        session: rig.session,
        onReserve: () {},
        onProfile: () {},
        activeBuilder: (_) => const SizedBox(),
        fallbackBuilder: (_) => const SizedBox(),
      );

  for (final (mode, scale) in [
    (ClayThemeMode.light, 1.0),
    (ClayThemeMode.light, 2.0),
    (ClayThemeMode.dark, 1.0),
  ]) {
    testWidgets('countdown, seat open [${mode.name} x$scale]', (tester) async {
      await golden(tester, 'countdown_open', QuestRig((o) => ok('state_terms')), mode: mode, scale: scale, screen: gate);
    });
  }

  testWidgets('countdown, seat reserved, Kiswahili [light x1.0]', (tester) async {
    await golden(tester, 'countdown_reserved_sw', QuestRig((o) => ok('state_countdown'), lang: 'sw'),
        mode: ClayThemeMode.light, scale: 1.0, screen: gate);
  });

  for (final (mode, scale) in [
    (ClayThemeMode.light, 1.0),
    (ClayThemeMode.light, 2.0),
    (ClayThemeMode.dark, 1.0),
  ]) {
    testWidgets('boards [${mode.name} x$scale]', (tester) async {
      final r = BRig();
      await r.daily.load();
      await withShadows(() async {
        setPhone(tester, dpr: 2.0);
        await tester.pumpWidget(screenApp(
          BoardsPage(session: r.session, daily: r.daily, weekly: r.weekly),
          options: ClayThemeOptions(mode: mode, reduceMotion: true),
          textScale: scale,
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/boards_${goldenKey(mode, scale)}.png'));
      });
      r.daily.dispose();
      r.weekly.dispose();
    });
  }
}
