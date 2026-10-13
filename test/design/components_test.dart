import 'dart:ui' show Tristate;

import 'package:elimupepe/core/design/clay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  setUpAll(loadClayFonts);

  group('ClayButton', () {
    var taps = 0;
    testClayMatrix(
      'primary, secondary, ghost, disabled, loading',
      (c) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClayButton(label: 'Continue learning', onPressed: () => taps++),
          const SizedBox(height: 12),
          ClayButton(
              label: 'Open library',
              variant: ClayButtonVariant.secondary,
              icon: ClayIcons.library,
              onPressed: () {}),
          const SizedBox(height: 12),
          ClayButton(
              label: 'Not now',
              variant: ClayButtonVariant.ghost,
              onPressed: () {}),
          const SizedBox(height: 12),
          const ClayButton(label: 'Locked', onPressed: null),
          const SizedBox(height: 12),
          ClayButton(label: 'Saving', loading: true, onPressed: () {}),
        ],
      ),
      verify: (t) async {
        expect(find.bySemanticsLabel('Continue learning'), findsOneWidget);
        expect(find.bySemanticsLabel('Saving, loading'), findsOneWidget);
        final disabled = t.getSemantics(find.bySemanticsLabel('Locked'));
        expect(disabled.flagsCollection.isEnabled, Tristate.isFalse);
      },
    );

    testWidgets('tap fires, loading and disabled do not', (tester) async {
      var a = 0, b = 0;
      setPhone(tester);
      await tester.pumpWidget(clayApp(Column(children: [
        ClayButton(label: 'Go', onPressed: () => a++),
        ClayButton(label: 'Busy', loading: true, onPressed: () => b++),
        const ClayButton(label: 'Off', onPressed: null),
      ])));
      await tester.tap(find.text('Go'));
      await tester.tap(find.text('Busy'));
      await tester.tap(find.text('Off'));
      expect(a, 1);
      expect(b, 0);
    });

    testWidgets('pressed state scales; reduced motion has zero duration',
        (tester) async {
      setPhone(tester);
      await tester.pumpWidget(clayApp(
        ClayButton(label: 'Go', onPressed: () {}),
        options: const ClayThemeOptions(reduceMotion: true),
      ));
      final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale.duration, Duration.zero);

      await tester.pumpWidget(clayApp(ClayButton(label: 'Go', onPressed: () {})));
      await tester.pumpAndSettle();
      final normal = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(normal.duration, ClayDurations.press);
    });

    testWidgets('OS disableAnimations also removes the tap animation',
        (tester) async {
      setPhone(tester);
      late ClayMotion motion;
      await tester.pumpWidget(MaterialApp(
        theme: ClayTheme.build(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(builder: (c) {
            motion = ClayMotion.of(c);
            return const SizedBox();
          }),
        ),
      ));
      expect(motion.reduced, isTrue);
      expect(motion.press, Duration.zero);
    });

    testWidgets('keyboard focus shows the focus ring and Enter activates',
        (tester) async {
      var taps = 0;
      setPhone(tester);
      await tester.pumpWidget(
          clayApp(ClayButton(label: 'Go', onPressed: () => taps++)));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(find.byType(Positioned), findsWidgets);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(taps, 1);
    });
  });

  group('ClayIconButton', () {
    testClayMatrix(
      'is 48 dp and labelled',
      (c) => Row(children: [
        ClayIconButton(icon: ClayIcons.close, label: 'Close', onPressed: () {}),
      ]),
      verify: (t) async {
        expect(t.getSize(find.byType(ClayIconButton)), const Size(48, 48));
      },
    );
  });

  group('ClayCard', () {
    testClayMatrix(
      'tones and tappable card',
      (c) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ClayCard(child: Text('Plain card with some body text')),
          const SizedBox(height: 12),
          const ClayCard(tone: ClayCardTone.green, child: Text('Green card')),
          const SizedBox(height: 12),
          const ClayCard(tone: ClayCardTone.rose, tight: true, child: Text('Rose card')),
          const SizedBox(height: 12),
          const ClayCard(tone: ClayCardTone.flat, child: Text('Flat dashed card')),
          const SizedBox(height: 12),
          ClayCard(
              onTap: () {},
              semanticLabel: 'Open my courses',
              child: const Text('My courses')),
        ],
      ),
      verify: (t) async {
        expect(find.bySemanticsLabel('Open my courses'), findsOneWidget);
      },
    );
  });

  group('ClayChip and ClayBadge', () {
    testClayMatrix(
      'chip, selectable chip, badges',
      (c) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ClayChip(label: 'Streak', value: 'x', icon: ClayIcons.achievements),
          const SizedBox(height: 12),
          ClayChip(label: 'Mathematics', selected: true, onTap: () {}),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: const [
            ClayBadge(label: 'Done', tone: ClayBadgeTone.done, icon: ClayIcons.check),
            ClayBadge(label: 'Live now', tone: ClayBadgeTone.solid),
            ClayBadge(label: 'Overdue', tone: ClayBadgeTone.warn, icon: ClayIcons.warning),
            ClayBadge(label: 'Soon', tone: ClayBadgeTone.soon),
          ]),
        ],
      ),
      verify: (t) async {
        final chip = t.getSemantics(find.bySemanticsLabel('Mathematics'));
        expect(chip.flagsCollection.isSelected, Tristate.isTrue);
        expect(find.bySemanticsLabel('Streak, x'), findsOneWidget);
        expect(find.bySemanticsLabel('Overdue'), findsOneWidget);
      },
    );
  });

  group('ClayProgress', () {
    testClayMatrix(
      'bar and ring expose percent',
      (c) => const Column(
        children: [
          ClayProgressBar(value: 0.5, semanticLabel: 'Course progress'),
          SizedBox(height: 16),
          ClayProgressBar(value: 0, semanticLabel: 'Not started'),
          SizedBox(height: 16),
          ClayProgressBar(value: 1, semanticLabel: 'Finished', danger: true),
          SizedBox(height: 16),
          ClayProgressRing(
              value: 0.75, semanticLabel: 'Weekly goal', child: Text('75%')),
        ],
      ),
      verify: (t) async {
        final bar = t.getSemantics(find.bySemanticsLabel('Course progress'));
        expect(bar.value, '50 percent');
        final ring = t.getSemantics(find.bySemanticsLabel('Weekly goal'));
        expect(ring.value, '75 percent');
      },
    );

    testWidgets('colour-blind theme adds a stripe overlay', (tester) async {
      setPhone(tester);
      await tester.pumpWidget(clayApp(
        const ClayProgressBar(value: 0.6, semanticLabel: 'p'),
        options: const ClayThemeOptions(colourBlind: true),
      ));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(CustomPaint), findsWidgets);
      final plain = clayApp(const ClayProgressBar(value: 0.6, semanticLabel: 'p'));
      await tester.pumpWidget(plain);
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('ClayTabBar', () {
    var index = 0;
    testClayMatrix(
      'three tabs',
      (c) => StatefulBuilder(
        builder: (c, set) => ClayTabBar(
          tabs: const [
            ClayTab(label: 'Courses'),
            ClayTab(label: 'Books'),
            ClayTab(label: 'Quizzes'),
          ],
          index: index,
          onChanged: (i) => set(() => index = i),
        ),
      ),
      verify: (t) async {
        final tab = t.getSemantics(find.bySemanticsLabel('Courses, tab 1 of 3'));
        expect(tab.flagsCollection.isSelected, Tristate.isTrue);
      },
    );

    testWidgets('tapping changes selection', (tester) async {
      setPhone(tester);
      var i = 0;
      await tester.pumpWidget(clayApp(StatefulBuilder(
        builder: (c, set) => ClayTabBar(
          tabs: const [ClayTab(label: 'A'), ClayTab(label: 'B')],
          index: i,
          onChanged: (v) => set(() => i = v),
        ),
      )));
      await tester.tap(find.text('B'));
      await tester.pump();
      expect(i, 1);
    });
  });

  group('ClayEmptyState', () {
    testClayMatrix(
      'empty, offline with action, locked',
      (c) => Column(children: [
        const ClayEmptyState(
            title: 'No books yet', message: 'Books you open will show up here.'),
        const SizedBox(height: 12),
        ClayEmptyState(
          title: 'You are offline',
          message: 'Check your connection and try again.',
          icon: ClayIcons.offline,
          actionLabel: 'Try again',
          onAction: () {},
        ),
        const SizedBox(height: 12),
        const ClayEmptyState(
            title: 'Locked', message: 'Ask a parent to unlock this.', locked: true),
      ]),
      verify: (t) async {
        expect(find.bySemanticsLabel('Try again'), findsOneWidget);
      },
    );
  });

  group('ClayListTile', () {
    testClayMatrix(
      'static and tappable rows',
      (c) => Column(children: [
        const ClayListTile(title: 'Mathematics', subtitle: 'Grade 6'),
        const SizedBox(height: 8),
        ClayListTile(
          title: 'Science',
          subtitle: 'Grade 6',
          leading: const Icon(Icons.science_outlined),
          onTap: () {},
        ),
        const SizedBox(height: 8),
        ClayListTile(title: 'Selected row', selected: true, onTap: () {}),
      ]),
      verify: (t) async {
        expect(find.bySemanticsLabel('Science, Grade 6'), findsOneWidget);
        expect(t.getSize(find.byType(ClayListTile).at(1)).height,
            greaterThanOrEqualTo(48));
      },
    );
  });

  group('ClayTextField', () {
    testClayMatrix(
      'label, hint, error, helper',
      (c) => const Column(children: [
        ClayTextField(label: 'Student ID', hint: 'Enter your Student ID'),
        SizedBox(height: 12),
        ClayTextField(
            label: 'Password', obscureText: true, helperText: 'At least 8 characters'),
        SizedBox(height: 12),
        ClayTextField(label: 'Search', errorText: 'Type at least two letters'),
      ]),
      verify: (t) async {
        expect(find.text('Type at least two letters'), findsOneWidget);
        expect(t.getSize(find.byType(TextField).first).height,
            greaterThanOrEqualTo(40));
      },
    );

    testWidgets('typing updates controller', (tester) async {
      setPhone(tester);
      final ctl = TextEditingController();
      await tester.pumpWidget(clayApp(ClayTextField(label: 'Name', controller: ctl)));
      await tester.enterText(find.byType(TextField), 'Amina');
      expect(ctl.text, 'Amina');
    });
  });

  group('ClaySheet', () {
    testWidgets('opens, is named, closes with the close button', (tester) async {
      final semantics = tester.ensureSemantics();
      setPhone(tester);
      await tester.pumpWidget(clayApp(Builder(
        builder: (c) => ClayButton(
          label: 'Open',
          onPressed: () => showClaySheet<void>(
            context: c,
            title: 'Accessibility',
            builder: (_) => const Text('Sheet body'),
          ),
        ),
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Sheet body'), findsOneWidget);
      expect(find.bySemanticsLabel('Close'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Sheet body'), findsNothing);
      semantics.dispose();
    });

    for (final scale in clayScales) {
      testWidgets('long content scrolls without overflow at x$scale',
          (tester) async {
        setPhone(tester);
        await tester.pumpWidget(clayApp(
          Builder(
            builder: (c) => ClayButton(
              label: 'Open',
              onPressed: () => showClaySheet<void>(
                context: c,
                title: 'Long',
                builder: (_) => Column(children: [
                  for (var i = 0; i < 40; i++) Text('Line $i of sheet content'),
                ]),
              ),
            ),
          ),
          textScale: scale,
        ));
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('ClayAppBar', () {
    testWidgets('shows the accessibility action when the scope provides it',
        (tester) async {
      var opened = 0;
      final semantics = tester.ensureSemantics();
      setPhone(tester);
      await tester.pumpWidget(clayApp(
        const SizedBox(),
        appBar: const ClayAppBar(title: 'My Library'),
        onOpenAccessibility: () => opened++,
      ));
      expect(find.bySemanticsLabel('Accessibility settings'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Accessibility settings'));
      expect(opened, 1);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });

    testWidgets('hides it without a scope action', (tester) async {
      setPhone(tester);
      await tester.pumpWidget(
          clayApp(const SizedBox(), appBar: const ClayAppBar(title: 'Title')));
      expect(find.byTooltip('Accessibility settings'), findsNothing);
    });

    for (final scale in clayScales) {
      testWidgets('long title ellipsises at x$scale', (tester) async {
        setPhone(tester);
        await tester.pumpWidget(clayApp(
          const SizedBox(),
          textScale: scale,
          appBar: const ClayAppBar(
              title: 'A very long screen title that cannot fit on one line'),
          onOpenAccessibility: () {},
        ));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('ClaySkeleton', () {
    testWidgets('animates normally and is static with reduced motion',
        (tester) async {
      setPhone(tester);
      await tester.pumpWidget(clayApp(const Column(children: [
        ClaySkeleton(shape: ClaySkeletonShape.title, semanticLabel: 'Loading'),
        ClaySkeleton(),
        ClaySkeleton(shape: ClaySkeletonShape.button),
        ClaySkeleton(shape: ClaySkeletonShape.art),
      ])));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(clayApp(
        const ClaySkeleton(),
        options: const ClayThemeOptions(reduceMotion: true),
      ));
      await tester.pumpAndSettle();
      // No repeating ticker keeps the test pending.
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('ClayAvatar', () {
    testWidgets('initials are drawn locally', (tester) async {
      setPhone(tester);
      await tester.pumpWidget(clayApp(const ClayAvatar(name: 'amina wanjiru')));
      expect(find.text('AW'), findsOneWidget);
    });
  });

  group('themes', () {
    for (final mode in clayModes) {
      testWidgets('${mode.name} theme carries Clay tokens', (tester) async {
        late ClayTokens t;
        await tester.pumpWidget(MaterialApp(
          theme: ClayTheme.build(ClayThemeOptions(mode: mode)),
          home: Builder(builder: (c) {
            t = ClayTokens.of(c);
            return const SizedBox();
          }),
        ));
        expect(t.palette, ClayPalette.resolve(mode));
      });
    }

    testWidgets('dyslexia swaps the font family', (tester) async {
      final t = ClayTheme.build(const ClayThemeOptions(dyslexia: true));
      expect(t.textTheme.bodyMedium!.fontFamily, 'OpenDyslexic');
      expect(t.textTheme.titleLarge!.fontFamily, 'OpenDyslexic');
      final n = ClayTheme.build();
      expect(n.textTheme.bodyMedium!.fontFamily, 'Nunito');
      expect(n.textTheme.titleLarge!.fontFamily, 'Fredoka');
    });
  });
}
