import 'package:flutter/material.dart';

import 'clay_metrics.dart';
import 'clay_palette.dart';

/// Everything a Clay component needs, attached to [ThemeData].
@immutable
class ClayTokens extends ThemeExtension<ClayTokens> {
  const ClayTokens({
    required this.palette,
    this.colourBlind = false,
    this.reduceMotion = false,
  });

  final ClayPalette palette;

  /// Adds pattern and outline cues so status is never colour only.
  final bool colourBlind;

  /// The in-app reduced motion setting. The OS setting is read separately
  /// through [ClayMotion.of].
  final bool reduceMotion;

  static ClayTokens of(BuildContext context) =>
      Theme.of(context).extension<ClayTokens>() ??
      const ClayTokens(palette: ClayPalette.light);

  @override
  ClayTokens copyWith({
    ClayPalette? palette,
    bool? colourBlind,
    bool? reduceMotion,
  }) =>
      ClayTokens(
        palette: palette ?? this.palette,
        colourBlind: colourBlind ?? this.colourBlind,
        reduceMotion: reduceMotion ?? this.reduceMotion,
      );

  @override
  ClayTokens lerp(ThemeExtension<ClayTokens>? other, double t) =>
      t < 0.5 || other is! ClayTokens ? this : other;
}

/// Motion helper: zero durations when the in-app setting or the OS
/// "remove animations" setting is on.
class ClayMotion {
  const ClayMotion._(this.reduced);
  final bool reduced;

  static ClayMotion of(BuildContext context) => ClayMotion._(
        ClayTokens.of(context).reduceMotion ||
            (MediaQuery.maybeDisableAnimationsOf(context) ?? false),
      );

  Duration _d(Duration full) => reduced ? Duration.zero : full;
  Duration get press => _d(ClayDurations.press);
  Duration get lift => _d(ClayDurations.lift);
  Duration get sheet => _d(ClayDurations.sheet);
  Duration get entrance => _d(ClayDurations.entrance);
  Duration get ring => _d(ClayDurations.ring);
  Duration get bar => _d(ClayDurations.bar);
  Curve get bounce => reduced ? Curves.linear : ClayCurves.bounce;
}
