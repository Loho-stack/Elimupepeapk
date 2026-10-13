import 'package:flutter/material.dart';

import '../tokens/clay_metrics.dart';
import '../tokens/clay_tokens.dart';

enum ClaySkeletonShape { title, text, button, art, box }

/// Loading placeholder (`.clay-skeleton`). The shimmer stops when reduced
/// motion is on. Pass [semanticLabel] on one skeleton per group only.
class ClaySkeleton extends StatefulWidget {
  const ClaySkeleton({
    super.key,
    this.shape = ClaySkeletonShape.text,
    this.width,
    this.height,
    this.semanticLabel,
  });

  final ClaySkeletonShape shape;
  final double? width;
  final double? height;
  final String? semanticLabel;

  @override
  State<ClaySkeleton> createState() => _ClaySkeletonState();
}

class _ClaySkeletonState extends State<ClaySkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: ClayDurations.shimmer);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = ClayTokens.of(context).palette;
    final reduced = ClayMotion.of(context).reduced;
    if (reduced) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }

    double h;
    double? w = widget.width;
    var radius = ClayRadii.s;
    switch (widget.shape) {
      case ClaySkeletonShape.title:
        h = 28;
        w ??= double.infinity;
        radius = ClayRadii.s;
      case ClaySkeletonShape.text:
        h = 16;
        w ??= double.infinity;
        radius = 8;
      case ClaySkeletonShape.button:
        h = ClaySize.touch;
        w ??= double.infinity;
        radius = ClayRadii.pill;
      case ClaySkeletonShape.art:
        h = 140;
        w ??= double.infinity;
        radius = ClayRadii.m;
      case ClaySkeletonShape.box:
        h = 72;
        w ??= double.infinity;
        radius = ClayRadii.s;
    }
    h = widget.height ?? h;

    final box = AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: reduced
              ? null
              : LinearGradient(
                  colors: [p.line, p.page, p.line],
                  stops: const [0.3, 0.5, 0.7],
                  transform: _Slide(_c.value),
                ),
          color: reduced ? p.line : null,
        ),
      ),
    );

    return widget.semanticLabel == null
        ? ExcludeSemantics(child: box)
        : Semantics(label: widget.semanticLabel, child: ExcludeSemantics(child: box));
  }
}

class _Slide extends GradientTransform {
  const _Slide(this.t);
  final double t;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (t * 2 - 1), 0, 0);
}
