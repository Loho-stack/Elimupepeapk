import 'package:flutter/material.dart';

import '../icons.dart';
import '../theme/clay_theme.dart';
import '../tokens/clay_metrics.dart';
import '../tokens/clay_tokens.dart';
import 'clay_pressable.dart';
import 'clay_surface.dart';

/// Stat or filter chip (`.sd-chip`): icon tile, value, label. 48 dp tall.
/// Tappable when [onTap] is set; [selected] marks a chosen filter.
class ClayChip extends StatelessWidget {
  const ClayChip({
    super.key,
    required this.label,
    this.value,
    this.icon,
    this.onTap,
    this.selected = false,
  });

  final String label;

  /// A real value from the API. Never pass placeholder numbers.
  final String? value;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = ClayTokens.of(context).palette;
    final theme = Theme.of(context).textTheme;
    final spoken = value == null ? label : '$label, $value';

    Widget body(bool pressed) => ClaySurface(
          radius: ClayRadii.m,
          color: selected ? p.primarySurface : p.card,
          elevation: pressed ? ClayElevation.pressed : ClayElevation.raised,
          borderColor: selected && p.flat ? p.primaryDeep : null,
          padding: const EdgeInsets.symmetric(
              horizontal: ClaySpace.s4, vertical: ClaySpace.s3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: p.primarySurface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 18, color: p.primaryDeep),
                ),
                const SizedBox(width: ClaySpace.s2),
              ],
              if (selected) ...[
                Icon(ClayIcons.check, size: 18, color: p.primaryDeep),
                const SizedBox(width: ClaySpace.s1),
              ],
              if (value != null) ...[
                Text(value!, style: clayWeight(theme.titleMedium!, ClayType.bold)),
                const SizedBox(width: ClaySpace.s2),
              ],
              Flexible(
                child: Text(label,
                    style: theme.labelSmall!.copyWith(color: p.muted)),
              ),
            ],
          ),
        );

    if (onTap == null) {
      return Semantics(container: true, label: spoken, child: ExcludeSemantics(child: body(false)));
    }
    return ClayPressable(
      onTap: onTap,
      radius: ClayRadii.m,
      selected: selected,
      semanticLabel: spoken,
      builder: (context, pressed, focused) => body(pressed),
    );
  }
}
