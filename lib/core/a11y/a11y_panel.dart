import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/clay.dart';
import 'a11y_controller.dart';
import 'a11y_settings.dart';
import 'speech_service.dart';

/// Opens the accessibility panel as a Clay sheet. Same fieldsets as the web
/// panel: Read aloud, Text size, Spacing, Colours, Comfort, Language.
Future<void> showA11yPanel(BuildContext context) {
  final controller = context.read<A11yController>();
  final speech = context.read<SpeechService>();
  return showClaySheet<void>(
    context: context,
    title: 'Accessibility',
    builder: (_) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: controller),
        Provider<SpeechService>.value(value: speech),
      ],
      child: const A11yPanel(),
    ),
  );
}

class A11yPanel extends StatelessWidget {
  const A11yPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<A11yController>();
    final s = c.settings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Group(
          title: 'Read aloud',
          children: [
            _Segments(
              label: 'Reading speed',
              tabs: const ['Slow', 'Normal', 'Fast'],
              index: s.readSpeed < 0.9 ? 0 : (s.readSpeed > 1.15 ? 2 : 1),
              onChanged: (i) =>
                  c.update(s.copyWith(readSpeed: const [0.8, 1.0, 1.3][i])),
            ),
            const SizedBox(height: ClaySpace.s2),
            _SpeedSlider(settings: s, onChanged: (v) => c.update(s.copyWith(readSpeed: v))),
            const SizedBox(height: ClaySpace.s2),
            const _TestVoice(),
          ],
        ),
        _Group(
          title: 'Text size',
          children: [
            _Segments(
              label: 'Text size',
              tabs: const ['A', 'A+', 'A++', 'A+++'],
              semanticTabs: const [
                'Normal text',
                'Larger text',
                'Large text',
                'Largest text',
              ],
              index: s.textSize,
              onChanged: (i) => c.update(s.copyWith(textSize: i)),
            ),
          ],
        ),
        _Group(
          title: 'Spacing',
          children: [
            _Segments(
              label: 'Line spacing',
              tabs: const ['Normal', 'Roomy', 'Roomier'],
              index: s.lineSpacing,
              onChanged: (i) => c.update(s.copyWith(lineSpacing: i)),
            ),
            const SizedBox(height: ClaySpace.s3),
            _Segments(
              label: 'Letter spacing',
              tabs: const ['Normal', 'Wide', 'Wider'],
              index: s.letterSpacing,
              onChanged: (i) => c.update(s.copyWith(letterSpacing: i)),
            ),
          ],
        ),
        _Group(
          title: 'Colours',
          children: [
            _Segments(
              label: 'Theme',
              tabs: const ['Light', 'Dark', 'High contrast'],
              index: s.theme.index,
              onChanged: (i) =>
                  c.update(s.copyWith(theme: ClayThemeMode.values[i])),
            ),
            const SizedBox(height: ClaySpace.s2),
            _Toggle(
              title: 'Colour-blind friendly colours',
              value: s.colourBlind,
              onChanged: (v) => c.update(s.copyWith(colourBlind: v)),
            ),
          ],
        ),
        _Group(
          title: 'Comfort',
          children: [
            _Toggle(
              title: 'Dyslexia-friendly font',
              value: s.dyslexiaFont,
              onChanged: (v) => c.update(s.copyWith(dyslexiaFont: v)),
            ),
            _Toggle(
              title: 'Reduce motion',
              value: s.reduceMotion,
              onChanged: (v) => c.update(s.copyWith(reduceMotion: v)),
            ),
            _Toggle(
              title: 'Mute sounds',
              value: s.muteSounds,
              onChanged: (v) => c.update(s.copyWith(muteSounds: v)),
            ),
            _Toggle(
              title: 'Simple view',
              value: s.simpleView,
              onChanged: (v) => c.update(s.copyWith(simpleView: v)),
            ),
          ],
        ),
        _Group(
          title: 'Language',
          children: [
            _Segments(
              label: 'Reading language',
              tabs: const ['Auto', 'English', 'Kiswahili'],
              index: s.readLang.index,
              onChanged: (i) =>
                  c.update(s.copyWith(readLang: A11yReadLang.values[i])),
            ),
          ],
        ),
        const SizedBox(height: ClaySpace.s2),
        _SyncStatus(state: c.syncState),
        const SizedBox(height: ClaySpace.s3),
        ClayButton(
          label: 'Reset to defaults',
          variant: ClayButtonVariant.secondary,
          onPressed: s == A11ySettings.defaults ? null : c.reset,
        ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: ClaySpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Padding(
                padding: const EdgeInsets.only(bottom: ClaySpace.s2),
                child: Text(title,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
            ),
            ...children,
          ],
        ),
      );
}

class _Segments extends StatelessWidget {
  const _Segments({
    required this.label,
    required this.tabs,
    required this.index,
    required this.onChanged,
    this.semanticTabs,
  });

  final String label;
  final List<String> tabs;
  final List<String>? semanticTabs;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: label,
        child: ClayTabBar(
          tabs: [for (final t in tabs) ClayTab(label: t)],
          index: index,
          onChanged: onChanged,
        ),
      );
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = ClayTokens.of(context).palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: ClaySpace.s2),
      child: ClayPressable(
        onTap: () => onChanged(!value),
        isButton: false,
        radius: ClayRadii.m,
        minSize: const Size(0, ClaySize.touch),
        semanticLabel: '$title, ${value ? 'on' : 'off'}',
        builder: (context, pressed, focused) => Container(
          constraints: const BoxConstraints(minHeight: ClaySize.touch),
          padding: const EdgeInsets.symmetric(
              horizontal: ClaySpace.s3, vertical: ClaySpace.s2),
          decoration: BoxDecoration(
            color: value ? p.primarySurface : p.page,
            borderRadius: BorderRadius.circular(ClayRadii.m),
            border: Border.all(
                color: value ? p.primaryDeep : p.line, width: value ? 3 : 2),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(title, style: Theme.of(context).textTheme.bodyLarge),
              ),
              const SizedBox(width: ClaySpace.s2),
              ClayBadge(
                label: value ? 'On' : 'Off',
                tone: value ? ClayBadgeTone.done : ClayBadgeTone.soon,
                icon: value ? ClayIcons.check : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeedSlider extends StatelessWidget {
  const _SpeedSlider({required this.settings, required this.onChanged});
  final A11ySettings settings;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: 'Fine reading speed',
        value: '${settings.readSpeed.toStringAsFixed(1)} times',
        child: Slider(
          min: 0.7,
          max: 1.5,
          divisions: 8,
          value: settings.readSpeed,
          label: '${settings.readSpeed.toStringAsFixed(1)}x',
          onChanged: onChanged,
        ),
      );
}

class _TestVoice extends StatefulWidget {
  const _TestVoice();

  @override
  State<_TestVoice> createState() => _TestVoiceState();
}

class _TestVoiceState extends State<_TestVoice> {
  String? _notice;

  Future<void> _speak() async {
    final settings = context.read<A11yController>().settings;
    final speech = context.read<SpeechService>();
    final locale = Localizations.maybeLocaleOf(context);
    final result = await speech.speak(
      settings.readLang == A11yReadLang.sw
          ? 'Hii ni sauti ya kusoma kwa sauti.'
          : 'This is the read aloud voice.',
      settings,
      appLocale: locale,
    );
    if (!mounted) return;
    setState(() => _notice = switch (result) {
          SpeakResult.spoken => null,
          SpeakResult.noVoice =>
            'No voice for this language is installed on this phone. '
                'You can add one in the phone text-to-speech settings.',
          SpeakResult.failed => 'Could not play the voice. Please try again.',
        });
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClayButton(
            label: 'Test voice',
            icon: ClayIcons.listen,
            variant: ClayButtonVariant.secondary,
            onPressed: _speak,
          ),
          if (_notice != null)
            Padding(
              padding: const EdgeInsets.only(top: ClaySpace.s2),
              child: Semantics(
                liveRegion: true,
                child: Text(_notice!,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ),
        ],
      );
}

class _SyncStatus extends StatelessWidget {
  const _SyncStatus({required this.state});
  final A11ySyncState state;

  @override
  Widget build(BuildContext context) {
    final text = switch (state) {
      A11ySyncState.localOnly => 'Saved on this phone.',
      A11ySyncState.synced => 'Saved to your account.',
      A11ySyncState.pending => 'Saving to your account...',
      A11ySyncState.failed =>
        'Saved on this phone. It will save to your account when you are online.',
    };
    return Semantics(
      liveRegion: true,
      child: Text(text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
