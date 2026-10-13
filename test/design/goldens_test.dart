import 'package:elimupepe/core/design/clay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

/// Golden galleries at 360x780 dp (rendered at 2x). Reduced motion is on so
/// animated parts (progress, skeleton) are in their final state.
///
/// Regenerate with: flutter test --update-goldens test/design/goldens_test.dart
/// Goldens are generated and compared on Windows; other platforms render text
/// slightly differently.
void main() {
  setUpAll(loadClayFonts);

  // flutter_test disables blurred shadows by default; Clay depends on them.
  // The framework checks the flag before tearDown hooks run, so each golden
  // test restores it itself in a finally block.
  Future<void> withShadows(Future<void> Function() body) async {
    debugDisableShadows = false;
    try {
      await body();
    } finally {
      debugDisableShadows = true;
    }
  }

  final galleries = <String, Widget Function()>{
    'buttons': () => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClayButton(label: 'Continue learning', onPressed: () {}),
            const SizedBox(height: 12),
            ClayButton(
                label: 'Open my library', icon: ClayIcons.library, onPressed: () {}),
            const SizedBox(height: 12),
            ClayButton(
                label: 'View details',
                variant: ClayButtonVariant.secondary,
                onPressed: () {}),
            const SizedBox(height: 12),
            ClayButton(
                label: 'Not now',
                variant: ClayButtonVariant.ghost,
                onPressed: () {}),
            const SizedBox(height: 12),
            const ClayButton(label: 'Locked', onPressed: null),
            const SizedBox(height: 12),
            ClayButton(label: 'Signing in', loading: true, onPressed: () {}),
            const SizedBox(height: 12),
            Row(children: [
              ClayIconButton(
                  icon: ClayIcons.accessibility,
                  label: 'Accessibility settings',
                  onPressed: () {}),
              ClayIconButton(
                  icon: ClayIcons.bell, label: 'Notifications', onPressed: () {}),
              ClayIconButton(
                  icon: ClayIcons.menu, label: 'Menu', onPressed: () {}),
            ]),
          ],
        ),
    'cards_chips_badges': () => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ClayCard(
                child: Text('Plain card. Clay cards have a soft drop shadow and an inner highlight.')),
            const SizedBox(height: 12),
            const ClayCard(
                tone: ClayCardTone.green,
                tight: true,
                child: Text('Green surface card (tight)')),
            const SizedBox(height: 12),
            const ClayCard(
                tone: ClayCardTone.rose,
                tight: true,
                child: Text('Rose surface card (tight)')),
            const SizedBox(height: 12),
            const ClayCard(
                tone: ClayCardTone.flat, tight: true, child: Text('Flat outlined card')),
            const SizedBox(height: 12),
            ClayCard(
                onTap: () {},
                semanticLabel: 'Open my courses',
                child: const Row(children: [
                  Icon(ClayIcons.learn),
                  SizedBox(width: 12),
                  Expanded(child: Text('Tappable card: My courses')),
                ])),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              const ClayChip(label: 'Stat chip', icon: ClayIcons.achievements),
              ClayChip(label: 'Selected', selected: true, onTap: () {}),
              ClayChip(label: 'Filter', onTap: () {}),
            ]),
            const SizedBox(height: 16),
            const Wrap(spacing: 8, runSpacing: 8, children: [
              ClayBadge(label: 'Done', tone: ClayBadgeTone.done, icon: ClayIcons.check),
              ClayBadge(label: 'Live now', tone: ClayBadgeTone.solid),
              ClayBadge(label: 'Neutral'),
              ClayBadge(label: 'Soft', tone: ClayBadgeTone.soft),
              ClayBadge(label: 'Overdue', tone: ClayBadgeTone.warn, icon: ClayIcons.warning),
              ClayBadge(label: 'Coming soon', tone: ClayBadgeTone.soon),
            ]),
          ],
        ),
    'progress_tabs': () => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Label('Bar at 0, 40 and 100 percent'),
            const ClayProgressBar(value: 0, semanticLabel: 'Not started'),
            const SizedBox(height: 12),
            const ClayProgressBar(value: 0.4, semanticLabel: 'In progress'),
            const SizedBox(height: 12),
            const ClayProgressBar(value: 1, semanticLabel: 'Complete'),
            const SizedBox(height: 12),
            const ClayProgressBar(value: 0.6, danger: true, semanticLabel: 'Behind'),
            const SizedBox(height: 24),
            const _Label('Ring at 25, 60 and 100 percent'),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ClayProgressRing(
                    value: 0.25, size: 84, semanticLabel: 'a', child: Text('25%')),
                ClayProgressRing(
                    value: 0.6, size: 84, semanticLabel: 'b', child: Text('60%')),
                ClayProgressRing(
                    value: 1, size: 84, semanticLabel: 'c', child: Text('100%')),
              ],
            ),
            const SizedBox(height: 24),
            const _Label('Tabs'),
            ClayTabBar(
              tabs: const [
                ClayTab(label: 'Courses'),
                ClayTab(label: 'Books'),
                ClayTab(label: 'Quizzes'),
              ],
              index: 1,
              onChanged: (_) {},
            ),
            const SizedBox(height: 12),
            ClayTabBar(
              tabs: const [
                ClayTab(label: 'Today', icon: ClayIcons.home),
                ClayTab(label: 'Week', icon: ClayIcons.learn),
              ],
              index: 0,
              onChanged: (_) {},
            ),
          ],
        ),
    'empty_states': () => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ClayEmptyState(
              title: 'No books yet',
              message: 'Books you open will show up here.',
            ),
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
              title: 'Locked',
              message: 'Ask a parent to unlock this.',
              locked: true,
            ),
          ],
        ),
    'skeletons_avatars': () => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Label('Skeletons (title, text, button, art)'),
            const ClaySkeleton(shape: ClaySkeletonShape.title, width: 180),
            const SizedBox(height: 8),
            const ClaySkeleton(),
            const SizedBox(height: 8),
            const ClaySkeleton(width: 220),
            const SizedBox(height: 8),
            const ClaySkeleton(shape: ClaySkeletonShape.button),
            const SizedBox(height: 8),
            const ClaySkeleton(shape: ClaySkeletonShape.art),
            const SizedBox(height: 16),
            const _Label('Avatars'),
            const Row(children: [
              ClayAvatar(name: 'Amina Wanjiru'),
              SizedBox(width: 8),
              ClayAvatar(name: 'Otieno'),
              SizedBox(width: 8),
              ClayAvatar(name: 'J K', size: 64),
            ]),
          ],
        ),
    'lists_forms': () => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ClayListTile(title: 'Mathematics', subtitle: 'Grade 6'),
            const SizedBox(height: 8),
            ClayListTile(
              title: 'Science',
              subtitle: 'Grade 6',
              leading: const Icon(ClayIcons.labs),
              onTap: () {},
            ),
            const SizedBox(height: 8),
            ClayListTile(
                title: 'Selected row',
                selected: true,
                leading: const Icon(ClayIcons.check),
                onTap: () {}),
            const SizedBox(height: 20),
            const ClayTextField(
              label: 'Student ID',
              hint: 'Enter your Student ID',
              prefixIcon: ClayIcons.profile,
            ),
            const SizedBox(height: 12),
            const ClayTextField(
              label: 'Password',
              hint: 'Enter your password',
              obscureText: true,
              prefixIcon: ClayIcons.lock,
              helperText: 'Passwords are never saved on this device.',
            ),
            const SizedBox(height: 12),
            const ClayTextField(
              label: 'Search',
              hint: 'Search books',
              prefixIcon: ClayIcons.search,
              errorText: 'Type at least two letters',
            ),
          ],
        ),
  };

  for (final entry in galleries.entries) {
    for (final mode in clayModes) {
      testWidgets('golden ${entry.key} ${mode.name}', (tester) => withShadows(() async {
        setPhone(tester, dpr: 2.0);
        await tester.pumpWidget(clayApp(
          entry.value(),
          options: ClayThemeOptions(mode: mode, reduceMotion: true),
          scroll: false,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/${entry.key}_${mode.name}.png'),
        );
      }));
    }
  }

  for (final mode in clayModes) {
    testWidgets('golden app_bar_and_sheet ${mode.name}', (tester) => withShadows(() async {
      setPhone(tester, dpr: 2.0);
      await tester.pumpWidget(clayApp(
        const Align(
          alignment: Alignment.bottomCenter,
          child: ClaySheet(
            title: 'Accessibility',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClayTabBar(
                  tabs: [
                    ClayTab(label: 'Light'),
                    ClayTab(label: 'Dark'),
                    ClayTab(label: 'Contrast'),
                  ],
                  index: 0,
                  onChanged: _noop,
                ),
                SizedBox(height: 16),
                ClayCard(
                    tone: ClayCardTone.green,
                    tight: true,
                    child: Text('Sheet content sits on the card surface.')),
              ],
            ),
          ),
        ),
        options: ClayThemeOptions(mode: mode, reduceMotion: true),
        scroll: false,
        appBar: const ClayAppBar(title: 'My Library', leading: SizedBox(width: 8)),
        onOpenAccessibility: () {},
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/app_bar_and_sheet_${mode.name}.png'),
      );
    }));
  }
}

void _noop(int _) {}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: Theme.of(context).textTheme.labelSmall),
      );
}
