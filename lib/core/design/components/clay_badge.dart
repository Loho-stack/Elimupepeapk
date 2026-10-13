import 'package:flutter/material.dart';

import '../tokens/clay_metrics.dart';
import '../tokens/clay_tokens.dart';

enum ClayBadgeTone { neutral, soft, rose, solid, danger, done, soon, warn }

/// Status pill (`.clay-pill`, `.sd-status`, `.lp-badge`). Status is never
/// colour only: [label] is required and [icon] is shown when given. In the
/// colour-blind theme the badge also gets a 2 dp outline.
class ClayBadge extends StatelessWidget {
  const ClayBadge({
    super.key,
    required this.label,
    this.tone = ClayBadgeTone.neutral,
    this.icon,
  });

  final String label;
  final ClayBadgeTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = ClayTokens.of(context);
    final p = t.palette;
    Color bg, fg;
    switch (tone) {
      case ClayBadgeTone.neutral:
        bg = p.primarySurface;
        fg = p.primaryDeep;
      case ClayBadgeTone.soft:
        bg = p.primarySoft;
        fg = p.isDark ? p.ink : p.night;
      case ClayBadgeTone.rose:
        bg = p.dangerSurface;
        fg = p.dangerDeep;
      case ClayBadgeTone.solid:
      case ClayBadgeTone.done:
        bg = p.primaryDeep;
        fg = p.isDark ? p.onPrimary : Colors.white;
      case ClayBadgeTone.danger:
      case ClayBadgeTone.warn:
        bg = p.dangerSurface;
        fg = p.dangerDeep;
      case ClayBadgeTone.soon:
        bg = p.line;
        fg = p.muted;
    }
    final outlined = t.colourBlind || p.flat;

    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: ClaySize.pillMin),
          padding: const EdgeInsets.symmetric(
              horizontal: ClaySpace.s3, vertical: ClaySpace.s1),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(ClayRadii.pill),
            border: outlined ? Border.all(color: fg, width: 2) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: ClaySpace.s1),
              ],
              Flexible(
                child: Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall!
                      .copyWith(color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Initials avatar (`.clay-avatar`). Drawn locally: the learner's name is
/// never sent to an avatar web service.
class ClayAvatar extends StatelessWidget {
  const ClayAvatar({
    super.key,
    required this.name,
    this.size = ClaySize.avatarDefault,
    this.semanticLabel,
  });

  final String name;
  final double size;
  final String? semanticLabel;

  String get _initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first.characters.first;
    final last = parts.length > 1 ? parts.last.characters.first : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final p = ClayTokens.of(context).palette;
    return Semantics(
      label: semanticLabel ?? 'Avatar',
      image: true,
      child: ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: p.primarySurface,
            shape: BoxShape.circle,
            border: p.flat ? Border.all(color: p.line, width: 2) : null,
          ),
          child: Text(
            _initials,
            style: Theme.of(context).textTheme.labelLarge!.copyWith(
                  color: p.primaryDeep,
                  fontSize: size * 0.4,
                ),
          ),
        ),
      ),
    );
  }
}
