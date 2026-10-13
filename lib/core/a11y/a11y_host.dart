import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/clay.dart';
import 'a11y_controller.dart';
import 'a11y_panel.dart';
import 'speech_service.dart';

/// Use as `MaterialApp.builder` content. Applies the user's text size on top
/// of the OS text scale (capped at 2.0, the largest size the layouts are
/// tested at), installs the accessibility action for every [ClayAppBar],
/// exposes whether Simple view is on, and shows a floating accessibility
/// button on screens that have no [ClayAppBar] (so the panel is reachable
/// from every screen, including the older ones with their own app bars).
class A11yHost extends StatefulWidget {
  const A11yHost({super.key, required this.navigatorKey, required this.child});

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  static const double maxTextScale = 2.0;

  @override
  State<A11yHost> createState() => _A11yHostState();
}

class _A11yHostState extends State<A11yHost> {
  final ValueNotifier<int> _barCount = ValueNotifier<int>(0);

  @override
  void dispose() {
    _barCount.dispose();
    super.dispose();
  }

  void _open() {
    final ctx = widget.navigatorKey.currentContext;
    if (ctx != null) showA11yPanel(ctx);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<A11yController>().settings;
    final media = MediaQuery.of(context);
    final os = media.textScaler.scale(1.0);
    final scale = math.min(os * s.textScale, A11yHost.maxTextScale);

    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(scale)),
      child: SimpleView(
        enabled: s.simpleView,
        child: ClayAppBarScope(
          onOpenAccessibility: _open,
          presence: _barCount,
          child: Stack(
            children: [
              Positioned.fill(child: widget.child),
              ValueListenableBuilder<int>(
                valueListenable: _barCount,
                builder: (context, count, _) => count > 0
                    ? const SizedBox.shrink()
                    : _FloatingA11yButton(onPressed: _open),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small round button above the bottom bar. Built without Tooltip or
/// Overlay (it lives above the Navigator).
class _FloatingA11yButton extends StatelessWidget {
  const _FloatingA11yButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = ClayTokens.of(context).palette;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Positioned(
      right: ClaySpace.s2,
      bottom: bottom + 96,
      child: ClayPressable(
        onTap: onPressed,
        semanticLabel: 'Accessibility settings',
        builder: (context, pressed, focused) => SizedBox(
          width: ClaySize.touch,
          height: ClaySize.touch,
          child: ClaySurface(
            radius: ClayRadii.pill,
            color: p.card,
            elevation: pressed ? ClayElevation.pressed : ClayElevation.raised,
            child: Center(
              child: Icon(ClayIcons.accessibility,
                  size: 24, color: p.primaryDeep),
            ),
          ),
        ),
      ),
    );
  }
}

/// Screens can read `SimpleView.of(context)` to hide non-core widgets and
/// use larger tiles, as the web `data-simple` mode does.
class SimpleView extends InheritedWidget {
  const SimpleView({super.key, required this.enabled, required super.child});
  final bool enabled;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SimpleView>()?.enabled ??
      false;

  @override
  bool updateShouldNotify(SimpleView old) => old.enabled != enabled;
}

/// A "Listen" button next to content: reads [text] aloud with the user's
/// speed and language. Stops when the widget leaves the screen.
class ReadAloud extends StatefulWidget {
  const ReadAloud({super.key, required this.text, required this.child});

  /// What is read. Pass the visible text of [child] (real content).
  final String text;
  final Widget child;

  @override
  State<ReadAloud> createState() => _ReadAloudState();
}

class _ReadAloudState extends State<ReadAloud> {
  late final SpeechService _speech = context.read<SpeechService>();

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  Future<void> _read() async {
    final settings = context.read<A11yController>().settings;
    await _speech.speak(widget.text, settings,
        appLocale: Localizations.maybeLocaleOf(context));
  }

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: widget.child),
          ClayIconButton(
            icon: ClayIcons.listen,
            label: 'Listen',
            onPressed: _read,
          ),
        ],
      );
}
