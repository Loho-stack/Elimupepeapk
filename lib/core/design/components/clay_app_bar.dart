import 'package:flutter/material.dart';

import '../icons.dart';
import '../tokens/clay_metrics.dart';
import '../tokens/clay_tokens.dart';
import 'clay_button.dart';

/// Supplies the "open accessibility panel" action to every [ClayAppBar]
/// below it. The app root installs this once, so the panel is reachable
/// from every screen without each screen wiring it.
class ClayAppBarScope extends InheritedWidget {
  const ClayAppBarScope({
    super.key,
    required this.onOpenAccessibility,
    required super.child,
  });

  final VoidCallback? onOpenAccessibility;

  static VoidCallback? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ClayAppBarScope>()
      ?.onOpenAccessibility;

  @override
  bool updateShouldNotify(ClayAppBarScope old) =>
      old.onOpenAccessibility != onOpenAccessibility;
}

/// Header bar (`.lpl-top`): back or custom leading, title as a heading,
/// actions, and the accessibility action when the scope provides one.
class ClayAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ClayAppBar({
    super.key,
    required this.title,
    this.leading,
    this.actions = const [],
    this.showAccessibility = true,
  });

  final String title;
  final Widget? leading;
  final List<Widget> actions;
  final bool showAccessibility;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final p = ClayTokens.of(context).palette;
    final openA11y = showAccessibility ? ClayAppBarScope.maybeOf(context) : null;
    final canPop = Navigator.maybeOf(context)?.canPop() ?? false;

    final lead = leading ??
        (canPop
            ? ClayIconButton(
                icon: ClayIcons.back,
                label: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.card,
        border: p.flat
            ? Border(bottom: BorderSide(color: p.line, width: 2))
            : null,
        boxShadow: p.flat
            ? null
            : [
                BoxShadow(
                  color: p.shadowTint.withValues(alpha: 0.5 * p.dropAlpha),
                  offset: const Offset(0, 6),
                  blurRadius: 18,
                  spreadRadius: -12,
                ),
              ],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: preferredSize.height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: ClaySpace.s2),
            child: Row(
              children: [
                if (lead != null) lead else const SizedBox(width: ClaySpace.s2),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                ...actions,
                if (openA11y != null)
                  ClayIconButton(
                    icon: ClayIcons.accessibility,
                    label: 'Accessibility settings',
                    onPressed: openA11y,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
