import 'package:flutter/material.dart';

import '../tokens/clay_metrics.dart';
import '../tokens/clay_palette.dart';
import '../tokens/clay_tokens.dart';

/// Inputs that change how the theme is built. The accessibility controller
/// (commit 3) maps its settings onto this.
@immutable
class ClayThemeOptions {
  const ClayThemeOptions({
    this.mode = ClayThemeMode.light,
    this.colourBlind = false,
    this.dyslexia = false,
    this.lineSpacing = 0,
    this.letterSpacing = 0,
    this.reduceMotion = false,
  });

  final ClayThemeMode mode;
  final bool colourBlind;
  final bool dyslexia;

  /// 0 normal, 1 roomy, 2 roomier.
  final int lineSpacing;

  /// 0 normal, 1 wide, 2 wider.
  final int letterSpacing;
  final bool reduceMotion;
}

abstract final class ClayFonts {
  static const display = 'Fredoka';
  static const body = 'Nunito';
  static const dyslexic = 'OpenDyslexic';
}

abstract final class ClayTheme {
  static ThemeData build([ClayThemeOptions o = const ClayThemeOptions()]) {
    final p = ClayPalette.resolve(o.mode, colourBlind: o.colourBlind);
    final displayFamily = o.dyslexia ? ClayFonts.dyslexic : ClayFonts.display;
    final bodyFamily = o.dyslexia ? ClayFonts.dyslexic : ClayFonts.body;

    final height = const [1.4, 1.7, 2.0][o.lineSpacing.clamp(0, 2)];
    final letter = const [0.0, 0.04, 0.09][o.letterSpacing.clamp(0, 2)];
    final word = const [0.0, 0.08, 0.16][o.letterSpacing.clamp(0, 2)];

    TextStyle body(double size, {FontWeight w = FontWeight.w400}) => TextStyle(
          fontFamily: bodyFamily,
          fontSize: size,
          fontWeight: w,
          height: height,
          letterSpacing: letter * size,
          wordSpacing: word * size,
          color: p.ink,
        );
    TextStyle head(double size, {FontWeight w = ClayType.semibold}) =>
        body(size, w: w).copyWith(fontFamily: displayFamily, height: height - 0.2);

    final textTheme = TextTheme(
      displayLarge: head(ClayType.xxl, w: ClayType.bold),
      displayMedium: head(ClayType.xl, w: ClayType.bold),
      displaySmall: head(ClayType.l),
      headlineLarge: head(ClayType.xl, w: ClayType.bold),
      headlineMedium: head(ClayType.l),
      headlineSmall: head(ClayType.m),
      titleLarge: head(ClayType.l),
      titleMedium: head(ClayType.m),
      titleSmall: head(ClayType.s),
      bodyLarge: body(ClayType.m),
      bodyMedium: body(ClayType.s),
      bodySmall: body(ClayType.xs).copyWith(color: p.muted),
      labelLarge: head(ClayType.m),
      labelMedium: head(ClayType.s),
      labelSmall: body(ClayType.xs, w: ClayType.heavy),
    );

    final scheme = ColorScheme(
      brightness: p.brightness,
      primary: p.primaryDeep,
      onPrimary: p.isDark ? p.onPrimary : Colors.white,
      primaryContainer: p.primarySurface,
      onPrimaryContainer: p.primaryDeep,
      secondary: p.primary,
      onSecondary: p.onPrimary,
      secondaryContainer: p.primarySurface,
      onSecondaryContainer: p.primaryDeep,
      error: p.dangerDeep,
      onError: p.isDark ? p.onPrimary : Colors.white,
      errorContainer: p.dangerSurface,
      onErrorContainer: p.dangerDeep,
      surface: p.card,
      onSurface: p.ink,
      onSurfaceVariant: p.muted,
      outline: p.flat ? p.line : p.quiet,
      outlineVariant: p.line,
      surfaceContainerHighest: p.line,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.page,
      canvasColor: p.page,
      textTheme: textTheme,
      fontFamily: bodyFamily,
      dividerColor: p.line,
      splashFactory: o.reduceMotion ? NoSplash.splashFactory : null,
      focusColor: p.primaryDeep.withValues(alpha: 0.2),
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: [
        ClayTokens(
          palette: p,
          colourBlind: o.colourBlind && o.mode == ClayThemeMode.light,
          reduceMotion: o.reduceMotion,
        ),
      ],
    );
  }
}
