import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/clay_metrics.dart';
import '../tokens/clay_tokens.dart';

typedef ClayPressableBuilder = Widget Function(
    BuildContext context, bool pressed, bool focused);

/// Shared interaction behaviour for every tappable Clay component:
/// minimum 48 dp target, keyboard and switch activation, visible focus ring
/// (2 dp card gap + 3 dp primaryDeep, web `--focus`), pressed state and a
/// tap micro-animation that is skipped when reduced motion is on.
class ClayPressable extends StatefulWidget {
  const ClayPressable({
    super.key,
    required this.onTap,
    required this.builder,
    this.semanticLabel,
    this.semanticValue,
    this.selected,
    this.radius = ClayRadii.pill,
    this.minSize = const Size(ClaySize.touch, ClaySize.touch),
    this.isButton = true,
    this.onLongPress,
  });

  /// Null disables the control (and announces it as disabled).
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final ClayPressableBuilder builder;

  /// When set, replaces the label read from the child widgets.
  final String? semanticLabel;
  final String? semanticValue;
  final bool? selected;
  final double radius;
  final Size minSize;
  final bool isButton;

  @override
  State<ClayPressable> createState() => _ClayPressableState();
}

class _ClayPressableState extends State<ClayPressable> {
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.onTap != null;

  void _setPressed(bool v) {
    if (!_enabled || _pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final p = ClayTokens.of(context).palette;
    final motion = ClayMotion.of(context);
    final pressed = _pressed && _enabled;

    Widget visual = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: widget.minSize.width,
        minHeight: widget.minSize.height,
      ),
      child: widget.builder(context, pressed, _focused),
    );

    visual = AnimatedSlide(
      offset: Offset(0, pressed ? 0.04 : 0),
      duration: motion.press,
      curve: motion.bounce,
      child: AnimatedScale(
        scale: pressed ? 0.97 : 1,
        duration: motion.press,
        curve: motion.bounce,
        child: visual,
      ),
    );

    if (_focused) {
      final r = BorderRadius.circular(widget.radius + 5);
      visual = Stack(
        clipBehavior: Clip.none,
        children: [
          visual,
          Positioned.fill(
            left: -5,
            top: -5,
            right: -5,
            bottom: -5,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: r,
                  border: Border.all(color: p.primaryDeep, width: 3),
                ),
              ),
            ),
          ),
        ],
      );
    }

    final action = FocusableActionDetector(
      enabled: _enabled,
      mouseCursor:
          _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap?.call();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: visual,
      ),
    );

    final hasLabel = widget.semanticLabel != null;
    return Semantics(
      container: true,
      button: widget.isButton,
      enabled: _enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      value: widget.semanticValue,
      onTap: widget.onTap,
      excludeSemantics: hasLabel,
      child: hasLabel ? action : MergeSemantics(child: action),
    );
  }
}
