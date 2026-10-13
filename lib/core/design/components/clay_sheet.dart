import 'package:flutter/material.dart';

import '../icons.dart';
import '../tokens/clay_metrics.dart';
import '../tokens/clay_tokens.dart';
import 'clay_button.dart';
import 'clay_surface.dart';

/// Opens a Clay bottom sheet (`.clay-sheet`): grip, title, close button,
/// scrollable content. Max width 560, max height 86% of the screen.
Future<T?> showClaySheet<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: const Color(0x8C012532),
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (ctx) => ClaySheet(title: title, child: builder(ctx)),
  );
}

class ClaySheet extends StatelessWidget {
  const ClaySheet({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = ClayTokens.of(context).palette;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.86;

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: title,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: ClaySurface(
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(ClayRadii.l)),
          elevation: ClayElevation.flat,
          borderColor: p.flat ? p.line : null,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: ClaySpace.s3),
                ExcludeSemantics(
                  child: Container(
                    width: 48,
                    height: 6,
                    decoration: BoxDecoration(
                      color: p.line,
                      borderRadius: BorderRadius.circular(ClayRadii.pill),
                      border: p.flat ? Border.all(color: p.ink) : null,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                      left: ClaySpace.s4, right: ClaySpace.s2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(title,
                              style: Theme.of(context).textTheme.titleLarge),
                        ),
                      ),
                      ClayIconButton(
                        icon: ClayIcons.close,
                        label: 'Close',
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                        ClaySpace.s4, 0, ClaySpace.s4, ClaySpace.s5),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
