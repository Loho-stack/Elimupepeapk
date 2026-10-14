import 'package:flutter/foundation.dart';

import '../../data/api_error.dart';

/// Loads one thing for a screen and keeps what it last got. A failed refresh
/// keeps the old data and records the error, so the screen can show the data
/// with an "offline" banner instead of an empty error page.
class LoadController<T> extends ChangeNotifier {
  LoadController(this._fetch);

  final Future<T> Function() _fetch;

  T? _data;
  AppApiError? _error;
  bool _loading = false;
  bool _disposed = false;
  bool _again = false;

  T? get data => _data;
  AppApiError? get error => _error;
  bool get loading => _loading;

  /// First load, nothing to show yet.
  bool get initialLoading => _loading && _data == null;

  /// Showing old data because the last load failed.
  bool get stale => _data != null && _error != null;

  /// The last failure was the device being offline.
  bool get offline => _error is OfflineError;

  /// Loads again when called while a load is running (the inputs may have changed), once.
  Future<void> load() async {
    if (_loading) {
      _again = true;
      return;
    }
    _loading = true;
    _notify();
    try {
      do {
        _again = false;
        try {
          _data = await _fetch();
          _error = null;
        } catch (e) {
          _error = AppApiError.from(e);
        }
      } while (_again && !_disposed);
    } finally {
      _loading = false;
      _notify();
    }
  }

  /// Pull to refresh: same as [load] (it returns when the load is over).
  Future<void> refresh() => load();

  /// Replaces the data without a request (a write that returned the new state).
  void set(T value) {
    _data = value;
    _error = null;
    _notify();
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
