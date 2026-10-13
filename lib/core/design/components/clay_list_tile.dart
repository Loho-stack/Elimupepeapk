import 'package:flutter/material.dart';

import '../icons.dart';
import '../theme/clay_theme.dart';
import '../tokens/clay_metrics.dart';
import '../tokens/clay_tokens.dart';
import 'clay_pressable.dart';

/// List row (`.sd-item`): min 48 dp, optional leading and trailing, chevron
/// when tappable.
class ClayListTile extends StatelessWidget {
  const ClayListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.selected = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = ClayTokens.of(context).palette;
    final theme = Theme.of(context).textTheme;
    final spoken = subtitle == null ? title : '$title, $subtitle';

    Widget body(bool pressed) => Container(
          constraints: const BoxConstraints(minHeight: ClaySize.touch),
          padding: const EdgeInsets.symmetric(
              horizontal: ClaySpace.s3, vertical: ClaySpace.s2),
          decoration: BoxDecoration(
            color: selected
                ? p.primarySurface
                : (pressed ? p.line : p.page),
            borderRadius: BorderRadius.circular(ClayRadii.s),
            border: p.flat
                ? Border.all(color: selected ? p.primaryDeep : p.line, width: 2)
                : null,
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: ClaySpace.s3),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        style: clayWeight(theme.titleSmall!, ClayType.bold)),
                    if (subtitle != null)
                      Text(subtitle!,
                          style: theme.bodySmall),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: ClaySpace.s2),
                trailing!,
              ] else if (onTap != null) ...[
                const SizedBox(width: ClaySpace.s2),
                Icon(ClayIcons.chevronRight, size: 20, color: p.quiet),
              ],
            ],
          ),
        );

    if (onTap == null) {
      return Semantics(container: true, label: spoken, child: ExcludeSemantics(child: body(false)));
    }
    return ClayPressable(
      onTap: onTap,
      radius: ClayRadii.s,
      selected: selected,
      semanticLabel: spoken,
      minSize: const Size(0, ClaySize.touch),
      builder: (context, pressed, focused) => body(pressed),
    );
  }
}
