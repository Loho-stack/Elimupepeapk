import 'package:flutter/material.dart';

import '../tokens/clay_metrics.dart';
import '../tokens/clay_tokens.dart';
import 'clay_pressable.dart';
import 'clay_surface.dart';

enum ClayButtonVariant { primary, secondary, ghost }

/// Pill button (`.clay-btn`). Disabled when [onPressed] is null; while
/// [loading] it ignores taps and announces "Loading".
class ClayButton extends StatelessWidget {
  const ClayButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = ClayButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final ClayButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final bool expand;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = ClayTokens.of(context).palette;
    final disabled = onPressed == null;
    final active = !disabled && !loading;

    Color bg;
    Color fg;
    switch (variant) {
      case ClayButtonVariant.primary:
        bg = p.primary;
        fg = p.onPrimary;
      case ClayButtonVariant.secondary:
        bg = p.card;
        fg = p.primaryDeep;
      case ClayButtonVariant.ghost:
        bg = Colors.transparent;
        fg = p.muted;
    }
    if (disabled) {
      bg = p.line;
      fg = p.quiet;
    }

    final text = Theme.of(context).textTheme.labelLarge!.copyWith(color: fg);

    return ClayPressable(
      onTap: active ? onPressed : null,
      semanticLabel: loading ? '$label, loading' : (semanticLabel ?? label),
      minSize: Size(expand ? double.infinity : ClaySize.touch, ClaySize.touch),
      builder: (context, pressed, focused) {
        final elevation = disabled || variant == ClayButtonVariant.ghost
            ? ClayElevation.flat
            : (pressed ? ClayElevation.pressed : ClayElevation.raised);
        return ClaySurface(
          radius: ClayRadii.pill,
          color: bg,
          elevation: elevation,
          borderColor: variant == ClayButtonVariant.ghost ? p.line : null,
          padding: const EdgeInsets.symmetric(
              horizontal: ClaySpace.s5, vertical: ClaySpace.s3),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: fg,
                    // A fixed arc instead of a spinner when motion is reduced.
                    value: ClayMotion.of(context).reduced ? 0.7 : null,
                  ),
                )
              else if (icon != null)
                Icon(icon, size: 20, color: fg),
              if (loading || icon != null) const SizedBox(width: ClaySpace.s2),
              Flexible(
                child: Text(label,
                    style: text, textAlign: TextAlign.center, softWrap: true),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Square 48 dp icon-only button (`.clay-btn--icon`). [label] is required
/// because there is no visible text.
class ClayIconButton extends StatelessWidget {
  const ClayIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = ClayTokens.of(context).palette;
    return Tooltip(
      message: label,
      child: ClayPressable(
        onTap: onPressed,
        semanticLabel: label,
        radius: ClayRadii.pill,
        builder: (context, pressed, focused) => SizedBox(
          width: ClaySize.touch,
          height: ClaySize.touch,
          child: Center(
            child: Icon(icon,
                size: 24,
                color: onPressed == null ? p.quiet : (color ?? p.primaryDeep)),
          ),
        ),
      ),
    );
  }
}
