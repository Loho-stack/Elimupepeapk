import 'package:flutter/material.dart';

import '../icons.dart';
import '../tokens/clay_metrics.dart';
import '../tokens/clay_tokens.dart';
import 'clay_button.dart';

/// Supplies the "open accessibility panel" action to every [ClayAppBar]
/// below it, and counts how many app bars are on screen. The app root
/// installs this once, so the panel is reachable from every screen without
/// each screen wiring it; when no [ClayAppBar] is showing (older screens
/// with their own app bar) the host shows a floating accessibility button
/// instead.
class ClayAppBarScope extends InheritedWidget {
  const ClayAppBarScope({
    super.key,
    required this.onOpenAccessibility,
    required super.child,
    this.presence,
  });

  final VoidCallback? onOpenAccessibility;

  /// Number of [ClayAppBar]s currently mounted.
  final ValueNotifier<int>? presence;

  static VoidCallback? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ClayAppBarScope>()
      ?.onOpenAccessibility;

  static ValueNotifier<int>? presenceOf(BuildContext context) => context
      .getInheritedWidgetOfExactType<ClayAppBarScope>()
      ?.presence;

  @override
  bool updateShouldNotify(ClayAppBarScope old) =>
      old.onOpenAccessibility != onOpenAccessibility;
}

/// Header bar (`.lpl-top`): back or custom leading, title as a heading,
/// actions, and the accessibility action when the scope provides one.
class ClayAppBar extends StatefulWidget implements PreferredSizeWidget {
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
  State<ClayAppBar> createState() => _ClayAppBarState();
}

class _ClayAppBarState extends State<ClayAppBar> {
  ValueNotifier<int>? _presence;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = widget.showAccessibility
        ? ClayAppBarScope.presenceOf(context)
        : null;
    if (next == _presence) return;
    _leave();
    _presence = next;
    if (next != null) {
      // Not during build: the host listens and rebuilds.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // The host may already be gone when the whole app is torn down.
        try {
          if (mounted && _presence == next) next.value++;
        } catch (_) {}
      });
      _registered = true;
    }
  }

  bool _registered = false;

  void _leave() {
    final p = _presence;
    if (p != null && _registered) {
      _registered = false;
      // The notifier may already be disposed when the whole app goes away.
      try {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            if (p.value > 0) p.value--;
          } catch (_) {}
        });
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _leave();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = ClayTokens.of(context).palette;
    final openA11y =
        widget.showAccessibility ? ClayAppBarScope.maybeOf(context) : null;
    final canPop = Navigator.maybeOf(context)?.canPop() ?? false;

    final lead = widget.leading ??
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
          height: widget.preferredSize.height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: ClaySpace.s2),
            child: Row(
              children: [
                if (lead != null) lead else const SizedBox(width: ClaySpace.s2),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                ...widget.actions,
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
