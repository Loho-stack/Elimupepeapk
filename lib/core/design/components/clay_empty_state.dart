import 'package:flutter/material.dart';

import '../icons.dart';
import '../tokens/clay_metrics.dart';
import '../tokens/clay_tokens.dart';
import 'clay_button.dart';
import 'clay_surface.dart';

/// Empty, offline, error and locked states (`.clay-state`). Always says what
/// happened and, when possible, what to do next.
class ClayEmptyState extends StatelessWidget {
  const ClayEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.locked = false,
  });

  final String title;
  final String? message;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Uses the danger surface and a lock icon (`.clay-state--locked`).
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final p = ClayTokens.of(context).palette;
    final theme = Theme.of(context).textTheme;
    final art = icon ?? (locked ? ClayIcons.lock : ClayIcons.inbox);
    final fg = locked ? p.dangerDeep : p.primaryDeep;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          vertical: ClaySpace.s5, horizontal: ClaySpace.s4),
      decoration: BoxDecoration(
        color: locked ? p.dangerSurface : p.primarySurface,
        borderRadius: BorderRadius.circular(ClayRadii.m),
        border: p.flat ? Border.all(color: p.line, width: 2) : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MergeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: SizedBox(
                    width: ClaySize.ringDefault,
                    height: ClaySize.ringDefault,
                    child: ClaySurface(
                      radius: ClayRadii.pill,
                      child: Center(child: Icon(art, size: 44, color: fg)),
                    ),
                  ),
                ),
                const SizedBox(height: ClaySpace.s4),
                Semantics(
                  header: true,
                  child: Text(title,
                      textAlign: TextAlign.center, style: theme.titleMedium),
                ),
                if (message != null) ...[
                  const SizedBox(height: ClaySpace.s2),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Text(message!,
                        textAlign: TextAlign.center,
                        style: theme.bodyMedium!.copyWith(color: p.muted)),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: ClaySpace.s4),
            ClayButton(
              label: actionLabel!,
              onPressed: onAction,
              expand: false,
            ),
          ],
        ],
      ),
    );
  }
}
