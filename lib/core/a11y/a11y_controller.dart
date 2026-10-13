import 'package:flutter/foundation.dart';

import 'a11y_settings.dart';
import 'a11y_store.dart';
import 'a11y_sync.dart';

enum A11ySyncState {
  /// Sync is off (flag) or the account cannot sync (not a student).
  localOnly,
  synced,
  pending,
  failed,
}

/// Holds the current [A11ySettings], saves every change locally at once and
/// queues it for the server. Last write wins (the PUT returns the stored
/// row). Offline changes stay queued across restarts and are replayed.
class A11yController extends ChangeNotifier {
  A11yController({
    required A11yStore store,
    A11ySync sync = const LocalOnlySync(),
    bool Function()? canSync,
  })  : _store = store,
        _sync = sync,
        _canSync = canSync ?? (() => true);

  final A11yStore _store;
  final A11ySync _sync;
  final bool Function() _canSync;

  A11ySettings _settings = A11ySettings.defaults;
  Map<String, dynamic> _pending = {};
  A11ySyncState _state = A11ySyncState.localOnly;
  bool _forbidden = false;
  bool _flushing = false;

  A11ySettings get settings => _settings;
  A11ySyncState get syncState => _state;

  bool get soundsAllowed => !_settings.muteSounds;
  bool get _syncActive => _sync.enabled && !_forbidden && _canSync();

  /// Loads the local copy. Call once at start-up before the first frame.
  Future<void> load() async {
    _settings = await _store.load() ?? A11ySettings.defaults;
    _pending = await _store.loadPending();
    _refreshState();
    notifyListeners();
  }

  Future<void> update(A11ySettings next) async {
    if (next == _settings) return;
    final changes = next.diff(_settings);
    _settings = next;
    _pending = {..._pending, ...changes};
    _refreshState();
    notifyListeners();
    await _store.save(next);
    await _store.savePending(_pending);
    await _flush();
  }

  Future<void> reset() => update(A11ySettings.defaults);

  /// After login: the account's saved settings win; if the account has none
  /// yet, this device's non-default choices are uploaded.
  Future<void> onSignedIn() async {
    _forbidden = false;
    if (!_syncActive) return _refreshState();
    try {
      final pull = await _sync.pull();
      final remote = pull.settings;
      if (remote != null) {
        await _store.saveEtag(pull.etag);
        if (pull.updatedAt != null) {
          // The account has saved settings: they replace local ones.
          _pending = {};
          await _applyRemote(remote);
        } else {
          final changes = _settings.diff(A11ySettings.defaults);
          _pending = {..._pending, ...changes};
          await _store.savePending(_pending);
        }
      }
    } on A11ySyncForbidden {
      _forbidden = true;
    } catch (_) {
      _state = A11ySyncState.failed;
      notifyListeners();
      return;
    }
    await _flush();
  }

  /// Pulls the server copy again (for example on app resume).
  Future<void> refreshFromServer() async {
    if (!_syncActive || _pending.isNotEmpty) return _flush();
    try {
      final pull = await _sync.pull(etag: await _store.loadEtag());
      if (!pull.notModified && pull.settings != null) {
        await _store.saveEtag(pull.etag);
        await _applyRemote(pull.settings!);
      }
      _refreshState(synced: true);
    } on A11ySyncForbidden {
      _forbidden = true;
      _refreshState();
    } catch (_) {
      _state = A11ySyncState.failed;
    }
    notifyListeners();
  }

  /// On logout: drop the account-bound queue and ETag. Settings stay as the
  /// device preference.
  Future<void> onSignedOut() async {
    _pending = {};
    _forbidden = false;
    await _store.clearAccountState();
    _refreshState();
    notifyListeners();
  }

  Future<void> _applyRemote(A11ySettings remote) async {
    _settings = remote;
    await _store.save(remote);
    _refreshState(synced: true);
    notifyListeners();
  }

  Future<void> _flush() async {
    if (_flushing || _pending.isEmpty || !_syncActive) {
      _refreshState();
      notifyListeners();
      return;
    }
    _flushing = true;
    final sent = Map<String, dynamic>.from(_pending);
    try {
      final stored = await _sync.push(sent);
      // Keep keys that changed again while the request was in flight.
      _pending.removeWhere((k, v) => sent.containsKey(k) && sent[k] == v);
      await _store.savePending(_pending);
      if (_pending.isEmpty) {
        _settings = stored;
        await _store.save(stored);
        _refreshState(synced: true);
      } else {
        _refreshState();
      }
    } on A11ySyncForbidden {
      _forbidden = true;
      _refreshState();
    } catch (_) {
      // Offline, 429 or server error: stay queued and retry on the next
      // change, sign-in or resume.
      _state = A11ySyncState.failed;
    } finally {
      _flushing = false;
    }
    notifyListeners();
  }

  void _refreshState({bool synced = false}) {
    if (!_syncActive) {
      _state = A11ySyncState.localOnly;
    } else if (_pending.isNotEmpty) {
      _state = A11ySyncState.pending;
    } else if (synced || _state == A11ySyncState.synced) {
      _state = A11ySyncState.synced;
    } else {
      _state = A11ySyncState.pending;
    }
  }
}
