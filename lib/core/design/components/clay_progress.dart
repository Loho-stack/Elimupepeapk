import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens/clay_metrics.dart';
import '../tokens/clay_tokens.dart';
import 'clay_surface.dart';

String _percent(double v) => '${(v.clamp(0, 1) * 100).round()} percent';

/// Progress bar (`.clay-progress`): 14 dp inset well with a primary fill.
/// [value] is 0..1 from real data. In the colour-blind theme the fill gets a
/// diagonal stripe so progress is not colour only.
class ClayProgressBar extends StatelessWidget {
  const ClayProgressBar({
    super.key,
    required this.value,
    required this.semanticLabel,
    this.danger = false,
  });

  final double value;
  final String semanticLabel;
  final bool danger;

  static const double height = 14;

  @override
  Widget build(BuildContext context) {
    final t = ClayTokens.of(context);
    final p = t.palette;
    final motion = ClayMotion.of(context);
    final v = value.clamp(0.0, 1.0);
    final fill = danger ? p.danger : (p.flat ? p.primaryDeep : p.primary);

    return Semantics(
      label: semanticLabel,
      value: _percent(v),
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          child: ClaySurface(
            radius: ClayRadii.pill,
            color: p.line,
            elevation: ClayElevation.well,
            child: LayoutBuilder(
              builder: (context, c) {
                final target = v == 0 ? 0.0 : math.max(height, c.maxWidth * v);
                return Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: motion.bar,
                    curve: ClayCurves.out,
                    width: target,
                    height: height,
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(ClayRadii.pill),
                    ),
                    child: t.colourBlind
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(ClayRadii.pill),
                            child: CustomPaint(painter: _StripePainter()),
                          )
                        : null,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _StripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = 3;
    for (double x = -size.height; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Progress ring (`.clay-ring`). [child] sits in the centre, typically the
/// percentage as text.
class ClayProgressRing extends StatelessWidget {
  const ClayProgressRing({
    super.key,
    required this.value,
    required this.semanticLabel,
    this.size = ClaySize.ringDefault,
    this.child,
  });

  final double value;
  final String semanticLabel;
  final double size;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final p = ClayTokens.of(context).palette;
    final motion = ClayMotion.of(context);
    final v = value.clamp(0.0, 1.0);
    return Semantics(
      label: semanticLabel,
      value: _percent(v),
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: v),
            duration: motion.ring,
            curve: ClayCurves.out,
            builder: (context, animated, _) => CustomPaint(
              painter: _RingPainter(
                value: animated,
                track: p.line,
                color: p.flat ? p.primaryDeep : p.primary,
                stroke: size * 0.11,
              ),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.track,
    required this.color,
    required this.stroke,
  });

  final double value;
  final Color track;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arc, 0, math.pi * 2, false, base..color = track);
    if (value > 0) {
      canvas.drawArc(
          arc, -math.pi / 2, math.pi * 2 * value, false, base..color = color);
    }
  }

  @override
  bool shouldRepaint(_RingPainter o) =>
      o.value != value || o.track != track || o.color != color || o.stroke != stroke;
}
