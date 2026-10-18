import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/api_error.dart';
import '../../data/models/msafara.dart';
import '../../data/repositories/repositories.dart';
import 'quest_strings.dart';

/// Monotonic time, so the countdown never reads the phone's wall clock (which the learner can set).
abstract class QuestClock {
  Duration get elapsed;
}

class StopwatchClock implements QuestClock {
  final Stopwatch _sw = Stopwatch()..start();
  @override
  Duration get elapsed => _sw.elapsed;
}

/// Where the learner's language choice for Elimu Quest is kept (device preference, not account data).
class QuestLangStore {
  QuestLangStore([SharedPreferences? prefs]) : _prefs = prefs;
  static const key = 'quest.lang';
  SharedPreferences? _prefs;

  Future<String?> load() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final v = _prefs!.getString(key);
      return QuestStrings.supported.contains(v) ? v : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String lang) async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setString(key, lang);
    } catch (_) {
      // A preference that cannot be saved is not worth an error.
    }
  }
}

/// What `/student/quest` knows: the last `GET msafara/state`, the language, and whether to fall back to
/// the website. Every Elimu Quest screen reads it, and calls [handleError] with what a repository threw
/// so a 409 gate sends the learner back to the right state.
class MsafaraSession extends ChangeNotifier {
  MsafaraSession(
    this.repo, {
    String? initialLanguage,
    QuestLangStore? langStore,
    QuestClock? clock,
    this.remoteEnabled,
  })  : _clock = clock ?? StopwatchClock(),
        _langStore = langStore,
        lang = QuestStrings.supported.contains(initialLanguage) ? initialLanguage! : 'en';

  final MsafaraRepository repo;
  final QuestClock _clock;
  final QuestLangStore? _langStore;

  /// Remote config `flags.msafara.enabled`. Null result means unknown, which counts as enabled.
  final Future<bool?> Function()? remoteEnabled;

  MsafaraState? state;
  AppApiError? error;
  bool loading = false;

  /// Show the website's Elimu Quest: remote config off, `stage: disabled`, or a 404 from `state`.
  bool useWebFallback = false;

  String lang;
  QuestStrings get strings => QuestStrings.of(lang);

  /// The refresh started by the last [handleError], for tests and for screens that want to wait.
  Future<void>? refreshing;

  Duration _stateAt = Duration.zero;
  bool _disposed = false;

  /// Reads the saved language, then the remote flag, then the state.
  Future<void> start({String? deviceLanguage}) async {
    final saved = await _langStore?.load();
    lang = saved ?? QuestStrings.fromLocale(deviceLanguage);
    if (remoteEnabled != null) {
      final enabled = await remoteEnabled!();
      if (enabled == false) {
        useWebFallback = true;
        _notify();
        return;
      }
    }
    await refresh();
  }

  Future<void> setLanguage(String value) async {
    if (!QuestStrings.supported.contains(value) || value == lang) return;
    lang = value;
    _notify();
    await _langStore?.save(value);
  }

  Future<void> refresh() async {
    if (loading) return;
    loading = true;
    _notify();
    try {
      final s = await repo.state();
      state = s;
      _stateAt = _clock.elapsed;
      error = null;
      useWebFallback = s.stage == QuestStage.disabled;
    } catch (e) {
      final err = AppApiError.from(e);
      if (err is NotFoundError) {
        useWebFallback = true;
        error = null;
      } else {
        error = err;
      }
    } finally {
      loading = false;
      _notify();
    }
  }

  /// Whole seconds left before Day 1 (or Day 0), counted from the server's `seconds_to_start` at the
  /// time of the last state. Null when there is no countdown.
  int? get secondsToStart {
    final s = state?.secondsToStart;
    if (s == null) return null;
    final left = s - (_clock.elapsed - _stateAt).inSeconds;
    return left < 0 ? 0 : left;
  }

  /// Returns true when [e] was a Msafara gate or a missing Msafara: the session refreshed and the
  /// screen should let go and let the gate route. Other errors are the screen's to show.
  bool handleError(Object e) {
    final err = AppApiError.from(e);
    if (err is MsafaraGateError) {
      refreshing = refresh();
      return true;
    }
    return false;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
