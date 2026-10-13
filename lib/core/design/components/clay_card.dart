import 'package:flutter/material.dart';

import '../tokens/clay_metrics.dart';
import '../tokens/clay_tokens.dart';
import 'clay_pressable.dart';
import 'clay_surface.dart';

enum ClayCardTone { plain, green, soft, rose, flat }

/// `.clay-card`. Becomes a button when [onTap] is set.
class ClayCard extends StatelessWidget {
  const ClayCard({
    super.key,
    required this.child,
    this.tone = ClayCardTone.plain,
    this.tight = false,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final ClayCardTone tone;
  final bool tight;
  final VoidCallback? onTap;

  /// Read instead of the card's text when set. Required for tappable cards
  /// whose content is not text.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = ClayTokens.of(context).palette;
    final radius = tight ? ClayRadii.m : ClayRadii.l;
    final padding = tight
        ? const EdgeInsets.symmetric(
            vertical: ClaySpace.s4, horizontal: ClaySpace.s3)
        : const EdgeInsets.symmetric(
            vertical: ClaySpace.s5, horizontal: ClaySpace.s4);

    Color color;
    switch (tone) {
      case ClayCardTone.plain:
        color = p.card;
      case ClayCardTone.green:
        color = p.primarySurface;
      case ClayCardTone.soft:
        color = p.primarySoft;
      case ClayCardTone.rose:
        color = p.dangerSurface;
      case ClayCardTone.flat:
        color = Colors.transparent;
    }

    Widget build(bool pressed) => ClaySurface(
          radius: radius,
          color: color,
          padding: padding,
          elevation: tone == ClayCardTone.flat
              ? ClayElevation.flat
              : (pressed ? ClayElevation.pressed : ClayElevation.raised),
          borderColor: tone == ClayCardTone.flat ? p.line : null,
          child: child,
        );

    if (onTap == null) {
      return semanticLabel == null
          ? build(false)
          : Semantics(container: true, label: semanticLabel, child: build(false));
    }
    return ClayPressable(
      onTap: onTap,
      radius: radius,
      semanticLabel: semanticLabel,
      builder: (context, pressed, focused) => build(pressed),
    );
  }
}
