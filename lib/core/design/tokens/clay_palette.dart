import 'package:flutter/material.dart';

/// Colour roles from the web Clay layer (Modules/Msafara tokens.css,
/// resources/student-dashboard/css/{theme,a11y}.css). The web names the
/// brand roles `--blue*` even though the student theme maps them to green;
/// here they are called primary* to avoid that trap.
enum ClayThemeMode { light, dark, contrast }

@immutable
class ClayPalette {
  const ClayPalette({
    required this.brightness,
    required this.primary,
    required this.primarySoft,
    required this.primarySurface,
    required this.primaryDeep,
    required this.onPrimary,
    required this.page,
    required this.card,
    required this.line,
    required this.ink,
    required this.night,
    required this.muted,
    required this.quiet,
    required this.danger,
    required this.dangerSoft,
    required this.dangerSurface,
    required this.dangerDeep,
    required this.shadowTint,
    required this.dropAlpha,
    required this.lightAlpha,
    required this.shadeAlpha,
    this.flat = false,
  });

  final Brightness brightness;

  /// Brand fill (Safaricom green). Not used for text on light surfaces.
  final Color primary;
  final Color primarySoft;
  final Color primarySurface;

  /// AA-safe text, icon and focus colour on [card] and [primarySurface].
  final Color primaryDeep;

  /// Label colour on [primary] fills.
  final Color onPrimary;
  final Color page;
  final Color card;
  final Color line;
  final Color ink;
  final Color night;
  final Color muted;
  final Color quiet;
  final Color danger;
  final Color dangerSoft;
  final Color dangerSurface;
  final Color dangerDeep;

  /// Clay shadow tint and strengths (web `--clay-*`).
  final Color shadowTint;
  final double dropAlpha;
  final double lightAlpha;
  final double shadeAlpha;

  /// High contrast: no shadows, 2 dp white borders instead.
  final bool flat;

  bool get isDark => brightness == Brightness.dark;

  static const light = ClayPalette(
    brightness: Brightness.light,
    primary: Color(0xFF49AA44),
    primarySoft: Color(0xFF9BD897),
    primarySurface: Color(0xFFDBF1DA),
    primaryDeep: Color(0xFF1D611A),
    onPrimary: Color(0xFF0F250E),
    page: Color(0xFFF2F8F1),
    card: Color(0xFFFFFFFF),
    line: Color(0xFFDBF1DA),
    ink: Color(0xFF0F250E),
    night: Color(0xFF143A12),
    muted: Color(0xFF335332),
    quiet: Color(0xFF456543),
    danger: Color(0xFFEB5757),
    dangerSoft: Color(0xFFF19595),
    dangerSurface: Color(0xFFFAD5D5),
    dangerDeep: Color(0xFFB61616),
    shadowTint: Color(0xFF012532),
    dropAlpha: 0.28,
    lightAlpha: 0.75,
    shadeAlpha: 0.10,
  );

  static const dark = ClayPalette(
    brightness: Brightness.dark,
    primary: Color(0xFF49AA44),
    primarySoft: Color(0xFF2E6B32),
    primarySurface: Color(0xFF1E3A24),
    primaryDeep: Color(0xFF8FDB8A),
    onPrimary: Color(0xFF0F250E),
    page: Color(0xFF0D1A0F),
    card: Color(0xFF15281A),
    line: Color(0xFF2A4630),
    ink: Color(0xFFEAF5E8),
    night: Color(0xFF0A140C),
    muted: Color(0xFFBFD6BC),
    quiet: Color(0xFFA8C4A5),
    danger: Color(0xFFEB5757),
    dangerSoft: Color(0xFF8C3A3A),
    dangerSurface: Color(0xFF3B1B1B),
    dangerDeep: Color(0xFFFFA3A3),
    shadowTint: Color(0xFF000000),
    dropAlpha: 0.60,
    lightAlpha: 0.06,
    shadeAlpha: 0.35,
  );

  static const contrast = ClayPalette(
    brightness: Brightness.dark,
    primary: Color(0xFF5CE65C),
    primarySoft: Color(0xFF003B00),
    primarySurface: Color(0xFF0A2E0A),
    primaryDeep: Color(0xFF7DFF7D),
    onPrimary: Color(0xFF000000),
    page: Color(0xFF000000),
    card: Color(0xFF000000),
    line: Color(0xFFFFFFFF),
    ink: Color(0xFFFFFFFF),
    night: Color(0xFF000000),
    muted: Color(0xFFFFFFFF),
    quiet: Color(0xFFFFFFFF),
    danger: Color(0xFFFF6B6B),
    dangerSoft: Color(0xFF5A0000),
    dangerSurface: Color(0xFF2B0000),
    dangerDeep: Color(0xFFFF9E9E),
    shadowTint: Color(0xFF000000),
    dropAlpha: 0,
    lightAlpha: 0,
    shadeAlpha: 0,
    flat: true,
  );

  /// Okabe-Ito colour-blind palette, light mode only (a11y.css:110).
  static const colourBlind = ClayPalette(
    brightness: Brightness.light,
    primary: Color(0xFF0072B2),
    primarySoft: Color(0xFF8CC7EA),
    primarySurface: Color(0xFFD6EAF8),
    primaryDeep: Color(0xFF004A75),
    onPrimary: Color(0xFFFFFFFF),
    page: Color(0xFFF3F8FB),
    card: Color(0xFFFFFFFF),
    line: Color(0xFFD6EAF8),
    ink: Color(0xFF0A2233),
    night: Color(0xFF0A2233),
    muted: Color(0xFF2C4A5E),
    quiet: Color(0xFF45647A),
    danger: Color(0xFFD55E00),
    dangerSoft: Color(0xFFF2B27F),
    dangerSurface: Color(0xFFFFE6D1),
    dangerDeep: Color(0xFF8A3B00),
    shadowTint: Color(0xFF012532),
    dropAlpha: 0.28,
    lightAlpha: 0.75,
    shadeAlpha: 0.10,
  );

  static ClayPalette resolve(ClayThemeMode mode, {bool colourBlind = false}) {
    switch (mode) {
      case ClayThemeMode.contrast:
        return contrast;
      case ClayThemeMode.dark:
        return dark;
      case ClayThemeMode.light:
        return colourBlind ? ClayPalette.colourBlind : light;
    }
  }
}

/// Msafara module blue family (tokens.css:24). Kept for the Msafara area
/// only; the student shell uses [ClayPalette].
abstract final class MsafaraBlue {
  static const base = Color(0xFF03AEEF);
  static const mid = Color(0xFF86D2F6);
  static const surface = Color(0xFFC5EAFB);
  static const deep = Color(0xFF02678D);
  static const ink = Color(0xFF012532);
  static const page = Color(0xFFF4FAFC);
}
