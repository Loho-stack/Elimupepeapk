import 'dart:math' as math;

import 'package:elimupepe/core/design/tokens/clay_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _channel(double v) =>
    v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

/// WCAG 2.1 contrast ratio.
double contrastRatio(Color a, Color b) {
  final l1 = _luminance(a), l2 = _luminance(b);
  return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
}

void main() {
  final palettes = <String, ClayPalette>{
    'light': ClayPalette.light,
    'dark': ClayPalette.dark,
    'contrast': ClayPalette.contrast,
    'colourBlind': ClayPalette.colourBlind,
  };

  palettes.forEach((name, p) {
    group('$name contrast', () {
      test('ink on page and card is AA', () {
        expect(contrastRatio(p.ink, p.page), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(p.ink, p.card), greaterThanOrEqualTo(4.5));
      });
      test('muted and quiet text on page and card is AA', () {
        for (final t in [p.muted, p.quiet]) {
          expect(contrastRatio(t, p.page), greaterThanOrEqualTo(4.5));
          expect(contrastRatio(t, p.card), greaterThanOrEqualTo(4.5));
        }
      });
      test('primaryDeep on card and primarySurface is AA', () {
        expect(contrastRatio(p.primaryDeep, p.card), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(p.primaryDeep, p.primarySurface),
            greaterThanOrEqualTo(4.5));
      });
      test('onPrimary label on primary fill is AA', () {
        expect(contrastRatio(p.onPrimary, p.primary), greaterThanOrEqualTo(4.5));
      });
      test('dangerDeep on card and dangerSurface is AA', () {
        expect(contrastRatio(p.dangerDeep, p.card), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(p.dangerDeep, p.dangerSurface),
            greaterThanOrEqualTo(4.5));
      });
      test('primary fill and line are visible as UI (3:1) on card', () {
        // Non-text UI: the progress fill must be distinguishable from its
        // track; in flat mode the white border carries it.
        final ui = p.flat ? p.line : p.primaryDeep;
        expect(contrastRatio(ui, p.card), greaterThanOrEqualTo(3.0));
      });
    });
  });
}
