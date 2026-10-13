import 'package:flutter/material.dart';

import '../tokens/clay_metrics.dart';
import '../tokens/clay_tokens.dart';

enum ClayElevation {
  /// Outer drop + inner light + inner shade (`--clay`).
  raised,

  /// Small drop + inner light (active segment).
  low,

  /// Pressed button and text fields (`--clay-pressed`).
  pressed,

  /// Inset well: progress tracks, segmented track.
  well,

  /// No shadow.
  flat,
}

/// The Clay material. Flutter has no inset BoxShadow, so the inner light and
/// shade are painted with blurred paths clipped to the shape.
class ClaySurface extends StatelessWidget {
  const ClaySurface({
    super.key,
    required this.child,
    this.color,
    this.radius = ClayRadii.l,
    this.borderRadius,
    this.elevation = ClayElevation.raised,
    this.padding,
    this.borderColor,
    this.clip = false,
  });

  final Widget child;
  final Color? color;
  final double radius;
  final BorderRadius? borderRadius;
  final ClayElevation elevation;
  final EdgeInsetsGeometry? padding;

  /// Overrides the default border (only used in high contrast).
  final Color? borderColor;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final p = ClayTokens.of(context).palette;
    final shape = borderRadius ?? BorderRadius.circular(radius);
    final tint = p.shadowTint;

    final shadows = <BoxShadow>[];
    if (!p.flat) {
      if (elevation == ClayElevation.raised) {
        shadows.add(BoxShadow(
          color: tint.withValues(alpha: p.dropAlpha),
          offset: const Offset(0, 10),
          blurRadius: 22,
          spreadRadius: -8,
        ));
      } else if (elevation == ClayElevation.low ||
          elevation == ClayElevation.pressed) {
        shadows.add(BoxShadow(
          color: tint.withValues(alpha: (p.dropAlpha * 1.07).clamp(0, 1)),
          offset: const Offset(0, 4),
          blurRadius: 10,
          spreadRadius: -4,
        ));
      }
    }

    final border = p.flat && elevation != ClayElevation.flat
        ? Border.all(color: borderColor ?? p.line, width: 2)
        : (borderColor != null ? Border.all(color: borderColor!, width: 2) : null);

    Widget content = child;
    if (padding != null) content = Padding(padding: padding!, child: content);
    if (clip) content = ClipRRect(borderRadius: shape, child: content);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? p.card,
        borderRadius: shape,
        boxShadow: shadows,
        border: border,
      ),
      child: p.flat
          ? content
          : CustomPaint(
              painter: _InsetPainter(
                shape: shape,
                insets: _insetsFor(elevation, p.shadowTint, p.lightAlpha,
                    p.shadeAlpha, p.isDark),
              ),
              child: content,
            ),
    );
  }

  static List<_Inset> _insetsFor(ClayElevation e, Color tint, double lightA,
      double shadeA, bool dark) {
    final light = Colors.white.withValues(alpha: lightA);
    switch (e) {
      case ClayElevation.raised:
        return [
          _Inset(const Offset(3, 3), 6, light),
          _Inset(const Offset(-4, -5), 8, tint.withValues(alpha: shadeA)),
        ];
      case ClayElevation.low:
        return [_Inset(const Offset(3, 3), 6, light)];
      case ClayElevation.pressed:
        return [
          _Inset(const Offset(2, 3), 6,
              tint.withValues(alpha: dark ? 0.45 : 0.16)),
          _Inset(const Offset(-2, -2), 4,
              Colors.white.withValues(alpha: dark ? 0.04 : 0.5)),
        ];
      case ClayElevation.well:
        return [
          _Inset(const Offset(2, 2), 5,
              tint.withValues(alpha: dark ? 0.5 : 0.18)),
        ];
      case ClayElevation.flat:
        return const [];
    }
  }
}

class _Inset {
  const _Inset(this.offset, this.blur, this.color);
  final Offset offset;
  final double blur;
  final Color color;

  @override
  bool operator ==(Object other) =>
      other is _Inset &&
      other.offset == offset &&
      other.blur == blur &&
      other.color == color;

  @override
  int get hashCode => Object.hash(offset, blur, color);
}

class _InsetPainter extends CustomPainter {
  _InsetPainter({required this.shape, required this.insets});
  final BorderRadius shape;
  final List<_Inset> insets;

  @override
  void paint(Canvas canvas, Size size) {
    if (insets.isEmpty || size.isEmpty) return;
    final rrect = shape.toRRect(Offset.zero & size);
    canvas.save();
    canvas.clipRRect(rrect);
    for (final i in insets) {
      if (i.color.a == 0) continue;
      final hole = rrect.shift(i.offset);
      final outer = Path()..addRect((Offset.zero & size).inflate(40));
      final ring = Path.combine(
        PathOperation.difference,
        outer,
        Path()..addRRect(hole),
      );
      canvas.drawPath(
        ring,
        Paint()
          ..color = i.color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, i.blur / 2),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_InsetPainter old) =>
      old.shape != shape || !_listEq(old.insets, insets);

  static bool _listEq(List<_Inset> a, List<_Inset> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
