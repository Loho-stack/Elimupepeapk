import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'a11y_settings.dart';

enum SpeakResult { spoken, noVoice, failed }

/// Read-aloud. On-device voices only: text is never sent anywhere by us.
abstract class SpeechService {
  Future<SpeakResult> speak(
    String text,
    A11ySettings settings, {
    Locale? appLocale,
  });
  Future<void> stop();
}

/// Picks the language tags to try, most specific first (`en-KE`, `sw-KE`
/// where available, then generic fallbacks).
List<String> speechLanguageCandidates(A11ySettings s, Locale? appLocale) {
  final code = switch (s.readLang) {
    A11yReadLang.en => 'en',
    A11yReadLang.sw => 'sw',
    A11yReadLang.auto => (appLocale?.languageCode == 'sw') ? 'sw' : 'en',
  };
  return code == 'sw'
      ? const ['sw-KE', 'sw-TZ', 'sw']
      : const ['en-KE', 'en-GB', 'en-US', 'en'];
}

/// Web speed 0.7..1.5 maps to the Android engine rate (0.5 = normal).
double speechRateFor(double readSpeed) => (0.5 * readSpeed).clamp(0.2, 1.0);

class FlutterTtsService implements SpeechService {
  FlutterTtsService([FlutterTts? tts]) : _tts = tts ?? FlutterTts();
  final FlutterTts _tts;

  @override
  Future<SpeakResult> speak(
    String text,
    A11ySettings settings, {
    Locale? appLocale,
  }) async {
    if (text.trim().isEmpty) return SpeakResult.failed;
    try {
      String? chosen;
      for (final tag in speechLanguageCandidates(settings, appLocale)) {
        final ok = await _tts.isLanguageAvailable(tag);
        if (ok == true || ok == 1) {
          chosen = tag;
          break;
        }
      }
      if (chosen == null) return SpeakResult.noVoice;
      await _tts.stop();
      await _tts.setLanguage(chosen);
      await _tts.setSpeechRate(speechRateFor(settings.readSpeed));
      await _tts.speak(text);
      return SpeakResult.spoken;
    } catch (e) {
      if (kDebugMode) debugPrint('TTS failed: ${e.runtimeType}');
      return SpeakResult.failed;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
