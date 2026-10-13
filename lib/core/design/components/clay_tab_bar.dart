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

    return ClaySurface(
      radius: ClayRadii.pill,
      color: p.line,
      elevation: ClayElevation.well,
      padding: const EdgeInsets.all(2),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: ClayPressable(
                onTap: () => onChanged(i),
                selected: i == index,
                semanticLabel:
                    '${tabs[i].label}, tab ${i + 1} of ${tabs.length}',
                minSize: const Size(0, ClaySize.touch),
                builder: (context, pressed, focused) {
                  final selected = i == index;
                  return ClaySurface(
                    radius: ClayRadii.pill,
                    color: selected ? p.card : Colors.transparent,
                    elevation:
                        selected ? ClayElevation.low : ClayElevation.flat,
                    borderColor: selected && p.flat ? p.primaryDeep : null,
                    padding: const EdgeInsets.symmetric(
                        horizontal: ClaySpace.s2, vertical: ClaySpace.s2),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (tabs[i].icon != null) ...[
                            Icon(tabs[i].icon,
                                size: 18,
                                color: selected ? p.primaryDeep : p.muted),
                            const SizedBox(width: ClaySpace.s1),
                          ],
                          Flexible(
                            child: Text(
                              tabs[i].label,
                              textAlign: TextAlign.center,
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
              ),
            ),
        ],
      ),
    );
  }
}
