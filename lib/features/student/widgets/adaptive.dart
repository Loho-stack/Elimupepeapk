import 'package:flutter/material.dart';

import '../../../core/design/clay.dart';

/// True when the learner reads at 150 percent or more (OS text size times the in-app setting).
bool largeText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(10) >= 15;

/// A progress ring with its percent label, sized to the text: the ring grows with the text size and
/// the label never overflows it.
class RingBadge extends StatelessWidget {
  const RingBadge({
    super.key,
    required this.percent,
    required this.semanticLabel,
    this.size = 72,
    this.label,
  });
  final int percent;
  final String semanticLabel;
  final double size;

  /// Text in the ring; defaults to the percent with a % sign.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final scaled = MediaQuery.textScalerOf(
      context,
    ).scale(size).clamp(size, size * 1.7);
    return ClayProgressRing(
      value: percent / 100,
      semanticLabel: semanticLabel,
      size: scaled,
      child: Padding(
        padding: EdgeInsets.all(scaled * 0.2),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label ?? '$percent%',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
      ),
    );
  }
}

/// A ring (or any leading widget) beside its text, stacked above it at large text sizes
/// so the text keeps its full width.
class LeadingAndText extends StatelessWidget {
  const LeadingAndText({super.key, required this.leading, required this.text});
  final Widget leading;
  final Widget text;

  @override
  Widget build(BuildContext context) {
    if (largeText(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leading,
          const SizedBox(height: ClaySpace.s2),
          text,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        leading,
        const SizedBox(width: ClaySpace.s3),
        Expanded(child: text),
      ],
    );
  }
}
