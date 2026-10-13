import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/design/clay.dart';

class ClayNavItem {
  const ClayNavItem({required this.label, required this.icon});
  final String label;
  final IconData icon;
}

/// Bottom bar with a raised centre action, like the web mobile tab bar
/// (`.sd-tabbar`): items on a card with the clay drop shadow, the middle item
/// larger and filled. Every target is at least 48 dp; the selected item is
/// marked by an outline and a heavier label, not by colour alone.
///
/// [items] are laid out in order; [centerIndex] is the raised one. The last
/// slot is "More", which opens the drawer and is never "selected".
class ClayBottomBar extends StatelessWidget {
  const ClayBottomBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.onMore,
    this.centerIndex = 2,
    this.moreLabel = 'More',
  });

  final List<ClayNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onMore;
  final int centerIndex;
  final String moreLabel;

  /// Bottom bar labels grow with the text size setting up to this factor
  /// (five labels share the width of a phone); the full label is always read
  /// aloud, and the icons and targets keep their size.
  static const double maxLabelScale = 1.3;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: maxLabelScale,
      child: Builder(builder: _build),
    );
  }

  Widget _build(BuildContext context) {
    final p = ClayTokens.of(context).palette;
    final labelHeight = MediaQuery.textScalerOf(context).scale(ClayType.xs) * 1.5;
    final barHeight = math.max(64.0, 50 + labelHeight);
    final slots = <Widget>[
      for (var i = 0; i < items.length; i++)
        Expanded(
          child: _BarItem(
            item: items[i],
            selected: i == currentIndex,
            raised: i == centerIndex,
            position: '${i + 1} of ${items.length + 1}',
            height: barHeight,
            onTap: () => onTap(i),
          ),
        ),
      Expanded(
        child: _BarItem(
          item: ClayNavItem(label: moreLabel, icon: ClayIcons.menu),
          selected: false,
          raised: false,
          position: '${items.length + 1} of ${items.length + 1}',
          height: barHeight,
          onTap: onMore,
          hint: 'Opens the full menu',
        ),
      ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.card,
        border: p.flat
            ? Border(top: BorderSide(color: p.line, width: 2))
            : null,
        boxShadow: p.flat
            ? null
            : [
                BoxShadow(
                  color: p.shadowTint.withValues(alpha: 0.5 * p.dropAlpha),
                  offset: const Offset(0, -8),
                  blurRadius: 20,
                  spreadRadius: -12,
                ),
              ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: ClaySpace.s2, vertical: ClaySpace.s1),
          child: SizedBox(
            height: barHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: slots,
            ),
          ),
        ),
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({
    required this.item,
    required this.selected,
    required this.raised,
    required this.position,
    required this.height,
    required this.onTap,
    this.hint,
  });

  final ClayNavItem item;
  final bool selected;
  final bool raised;
  final String position;
  final double height;
  final VoidCallback onTap;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final p = ClayTokens.of(context).palette;
    final theme = Theme.of(context).textTheme;
    final fg = raised
        ? p.onPrimary
        : (selected ? p.primaryDeep : p.muted);

    return ClayPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: '${item.label}, $position'
          '${hint == null ? '' : ', $hint'}',
      radius: ClayRadii.m,
      minSize: Size(ClaySize.touch, height),
      builder: (context, pressed, focused) {
        final icon = Icon(item.icon, size: raised ? 28 : 24, color: fg);
        final label = FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            item.label,
            maxLines: 1,
            style: clayWeight(
              theme.labelSmall!.copyWith(color: fg),
              selected ? ClayType.heavy : ClayType.semibold,
            ),
          ),
        );

        if (raised) {
          return Center(
            child: Transform.translate(
              offset: const Offset(0, -10),
              child: ClaySurface(
                radius: ClayRadii.pill,
                color: p.primary,
                elevation:
                    pressed ? ClayElevation.pressed : ClayElevation.raised,
                borderColor: selected ? p.primaryDeep : null,
                padding: const EdgeInsets.symmetric(
                    horizontal: ClaySpace.s2, vertical: ClaySpace.s2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [icon, label],
                ),
              ),
            ),
          );
        }

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: ClaySpace.s3, vertical: ClaySpace.s1),
              decoration: BoxDecoration(
                color: selected ? p.primarySurface : Colors.transparent,
                borderRadius: BorderRadius.circular(ClayRadii.pill),
                border: selected
                    ? Border.all(color: p.primaryDeep, width: 2)
                    : null,
              ),
              child: icon,
            ),
            label,
          ],
        );
      },
    );
  }
}
