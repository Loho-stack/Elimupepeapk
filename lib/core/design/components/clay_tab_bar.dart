import 'package:flutter/material.dart';

import '../theme/clay_theme.dart';
import '../tokens/clay_metrics.dart';
import '../tokens/clay_tokens.dart';
import 'clay_pressable.dart';
import 'clay_surface.dart';

class ClayTab {
  const ClayTab({required this.label, this.icon});
  final String label;
  final IconData? icon;
}

/// Segmented tab control (`.clay-seg`, `.lp-tabs`). Items are 48 dp tall
/// (the web uses 44; the app target rule wins).
class ClayTabBar extends StatelessWidget {
  const ClayTabBar({
    super.key,
    required this.tabs,
    required this.index,
    required this.onChanged,
  });

  final List<ClayTab> tabs;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = ClayTokens.of(context).palette;
    final text = Theme.of(context).textTheme.labelMedium!;
    final scaler = MediaQuery.textScalerOf(context);

    // A segment is as wide as its label (and icon) needs. When all of them fit, they share the
    // bar in proportion to that width; when they do not (large text), the bar scrolls sideways,
    // so a label is never broken in the middle of a word.
    double natural(ClayTab tab) {
      final painter = TextPainter(
        text: TextSpan(
          text: tab.label,
          style: clayWeight(text, ClayType.bold),
        ),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final icon = tab.icon == null ? 0.0 : 18 + ClaySpace.s1;
      return painter.width.ceilToDouble() + icon + 2 * ClaySpace.s3;
    }

    Widget segment(int i) {
      return ClayPressable(
        onTap: () => onChanged(i),
        selected: i == index,
        semanticLabel: '${tabs[i].label}, tab ${i + 1} of ${tabs.length}',
        minSize: const Size(0, ClaySize.touch),
        builder: (context, pressed, focused) {
          final selected = i == index;
          return ClaySurface(
            radius: ClayRadii.pill,
            color: selected ? p.card : Colors.transparent,
            elevation: selected ? ClayElevation.low : ClayElevation.flat,
            borderColor: selected && p.flat ? p.primaryDeep : null,
            padding: const EdgeInsets.symmetric(
                horizontal: ClaySpace.s2, vertical: ClaySpace.s2),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (tabs[i].icon != null) ...[
                    Icon(tabs[i].icon,
                        size: 18, color: selected ? p.primaryDeep : p.muted),
                    const SizedBox(width: ClaySpace.s1),
                  ],
                  Flexible(
                    child: Text(
                      tabs[i].label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: clayWeight(
                        text.copyWith(color: selected ? p.ink : p.muted),
                        selected ? ClayType.bold : ClayType.semibold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return ClaySurface(
      radius: ClayRadii.pill,
      color: p.line,
      elevation: ClayElevation.well,
      padding: const EdgeInsets.all(2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final widths = [for (final t in tabs) natural(t)];
          final total = widths.fold<double>(0, (a, b) => a + b);
          if (total <= constraints.maxWidth) {
            return Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  Expanded(flex: widths[i].round(), child: segment(i)),
              ],
            );
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  SizedBox(width: widths[i], child: segment(i)),
              ],
            ),
          );
        },
      ),
    );
  }
}
