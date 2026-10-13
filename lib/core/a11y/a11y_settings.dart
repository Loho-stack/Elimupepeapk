import 'package:flutter/foundation.dart';

import '../design/theme/clay_theme.dart';
import '../design/tokens/clay_palette.dart';

/// Same options and meaning as the web
/// `App\Services\StudentDashboard\AccessibilitySettings`: same keys, ranges,
/// defaults and sanitising rules, so a value saved on either side means the
/// same on the other.
@immutable
class A11ySettings {
  const A11ySettings({
    this.textSize = 0,
    this.lineSpacing = 0,
    this.letterSpacing = 0,
    this.dyslexiaFont = false,
    this.theme = ClayThemeMode.light,
    this.colourBlind = false,
    this.reduceMotion = false,
    this.muteSounds = false,
    this.simpleView = false,
    this.readSpeed = 1.0,
    this.readLang = A11yReadLang.auto,
  });

  /// 0..3 = 100, 115, 130, 150 percent.
  final int textSize;

  /// 0..2 = normal, roomy, roomier.
  final int lineSpacing;

  /// 0..2 = normal, wide, wider.
  final int letterSpacing;
  final bool dyslexiaFont;
  final ClayThemeMode theme;
  final bool colourBlind;
  final bool reduceMotion;
  final bool muteSounds;
  final bool simpleView;

  /// 0.7..1.5, one decimal.
  final double readSpeed;
  final A11yReadLang readLang;

  static const defaults = A11ySettings();
  static const textScales = [1.0, 1.15, 1.30, 1.50];

  /// The web 'theme' value for each mode.
  static const _themeNames = {
    ClayThemeMode.light: 'light',
    ClayThemeMode.dark: 'dark',
    ClayThemeMode.contrast: 'contrast',
  };

  double get textScale => textScales[textSize];

  ClayThemeOptions toThemeOptions() => ClayThemeOptions(
        mode: theme,
        colourBlind: colourBlind,
        dyslexia: dyslexiaFont,
        lineSpacing: lineSpacing,
        letterSpacing: letterSpacing,
        reduceMotion: reduceMotion,
      );

  A11ySettings copyWith({
    int? textSize,
    int? lineSpacing,
    int? letterSpacing,
    bool? dyslexiaFont,
    ClayThemeMode? theme,
    bool? colourBlind,
    bool? reduceMotion,
    bool? muteSounds,
    bool? simpleView,
    double? readSpeed,
    A11yReadLang? readLang,
  }) =>
      A11ySettings.sanitized(
        textSize: textSize ?? this.textSize,
        lineSpacing: lineSpacing ?? this.lineSpacing,
        letterSpacing: letterSpacing ?? this.letterSpacing,
        dyslexiaFont: dyslexiaFont ?? this.dyslexiaFont,
        theme: theme ?? this.theme,
        colourBlind: colourBlind ?? this.colourBlind,
        reduceMotion: reduceMotion ?? this.reduceMotion,
        muteSounds: muteSounds ?? this.muteSounds,
        simpleView: simpleView ?? this.simpleView,
        readSpeed: readSpeed ?? this.readSpeed,
        readLang: readLang ?? this.readLang,
      );

  /// Clamps every value into range (PHP `sanitize()`).
  factory A11ySettings.sanitized({
    int textSize = 0,
    int lineSpacing = 0,
    int letterSpacing = 0,
    bool dyslexiaFont = false,
    ClayThemeMode theme = ClayThemeMode.light,
    bool colourBlind = false,
    bool reduceMotion = false,
    bool muteSounds = false,
    bool simpleView = false,
    double readSpeed = 1.0,
    A11yReadLang readLang = A11yReadLang.auto,
  }) =>
      A11ySettings(
        textSize: textSize.clamp(0, 3),
        lineSpacing: lineSpacing.clamp(0, 2),
        letterSpacing: letterSpacing.clamp(0, 2),
        dyslexiaFont: dyslexiaFont,
        theme: theme,
        colourBlind: colourBlind,
        reduceMotion: reduceMotion,
        muteSounds: muteSounds,
        simpleView: simpleView,
        readSpeed: _round1(readSpeed.clamp(0.7, 1.5)),
        readLang: readLang,
      );

  /// Parses a server or stored map the way PHP does: missing or invalid
  /// keys fall back to the default, never throw.
  factory A11ySettings.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    return A11ySettings.sanitized(
      textSize: _int(j['text_size']),
      lineSpacing: _int(j['line_spacing']),
      letterSpacing: _int(j['letter_spacing']),
      dyslexiaFont: _bool(j['dyslexia_font']),
      theme: _themeNames.entries
              .where((e) => e.value == j['theme'])
              .map((e) => e.key)
              .firstOrNull ??
          ClayThemeMode.light,
      colourBlind: _bool(j['colour_blind']),
      reduceMotion: _bool(j['reduce_motion']),
      muteSounds: _bool(j['mute_sounds']),
      simpleView: _bool(j['simple_view']),
      readSpeed: _double(j['read_speed'], 1.0),
      readLang: A11yReadLang.values
              .where((l) => l.name == j['read_lang'])
              .firstOrNull ??
          A11yReadLang.auto,
    );
  }

  Map<String, dynamic> toJson() => {
        'text_size': textSize,
        'line_spacing': lineSpacing,
        'letter_spacing': letterSpacing,
        'dyslexia_font': dyslexiaFont,
        'theme': _themeNames[theme],
        'colour_blind': colourBlind,
        'reduce_motion': reduceMotion,
        'mute_sounds': muteSounds,
        'simple_view': simpleView,
        'read_speed': readSpeed,
        'read_lang': readLang.name,
      };

  /// Keys whose value differs from [other], for a partial PUT.
  Map<String, dynamic> diff(A11ySettings other) {
    final a = toJson(), b = other.toJson();
    return {
      for (final k in a.keys)
        if (a[k] != b[k]) k: a[k],
    };
  }

  @override
  bool operator ==(Object other) =>
      other is A11ySettings && mapEquals(other.toJson(), toJson());

  @override
  int get hashCode => Object.hashAll(toJson().values);

  static int _int(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.toInt() ?? 0;
    if (v is bool) return v ? 1 : 0;
    return 0;
  }

  static double _double(Object? v, double fallback) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  /// PHP FILTER_VALIDATE_BOOLEAN: 1, true, on, yes are true.
  static bool _bool(Object? v) {
    if (v is bool) return v;
    if (v is num) return v == 1;
    if (v is String) {
      return const {'1', 'true', 'on', 'yes'}.contains(v.trim().toLowerCase());
    }
    return false;
  }

  static double _round1(double v) => (v * 10).round() / 10;
}

enum A11yReadLang { auto, en, sw }
