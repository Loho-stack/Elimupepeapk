import 'package:flutter/foundation.dart';

import '../../data/api_error.dart';
import '../../data/idempotency.dart';
import '../../data/models/msafara_checkpoint.dart';
import '../../data/repositories/repositories.dart';

enum CheckpointPhase {
  loading,

  /// The checkpoint is on screen.
  ready,

  /// The server has none for this learner's band and day (404).
  none,

  /// Could not load; [CheckpointController.error] says why.
  failed,
}

/// The "Did you know" checkpoint of one day. Each attempt has one Idempotency-Key that stays the same
/// through offline retries; the chosen option is never thrown away by a failed send.
class CheckpointController extends ChangeNotifier {
  CheckpointController({required this.repo, required this.day, this.onGate});

  final MsafaraRepository repo;
  final int day;

  /// A Msafara gate 409: the screen should leave.
  final void Function(AppApiError error)? onGate;

  CheckpointPhase phase = CheckpointPhase.loading;
  Checkpoint? checkpoint;
  AppApiError? error;
  String? selected;
  bool busy = false;
  bool offlineKept = false;
  String? answerError;

  /// The reply to the answer just sent, shown until the learner goes on or tries again.
  CheckpointResult? result;

  PendingAction? _action;
  int? _actionAttempt;
  bool _disposed = false;

  bool get canSubmit => !busy && selected != null && (checkpoint?.canAnswer ?? false) && result == null;

  Future<void> load() async {
    phase = CheckpointPhase.loading;
    error = null;
    _notify();
    await _fetch();
    _notify();
  }

  Future<void> _fetch() async {
    try {
      checkpoint = await repo.checkpoint(day: day);
      phase = CheckpointPhase.ready;
    } catch (e) {
      final err = AppApiError.from(e);
      if (err is NotFoundError) {
        phase = CheckpointPhase.none;
      } else {
        error = err;
        phase = CheckpointPhase.failed;
        if (err is MsafaraGateError) onGate?.call(err);
      }
    }
  }

  void select(String option) {
    if (busy || result != null) return;
    selected = option;
    answerError = null;
    _notify();
  }

  Future<void> submit() async {
    final cp = checkpoint;
    final option = selected;
    if (cp == null || option == null || !canSubmit) return;
    final attempt = cp.answers.length + 1;
    if (_actionAttempt != attempt || _action == null) {
      _action = PendingAction();
      _actionAttempt = attempt;
    }
    busy = true;
    offlineKept = false;
    answerError = null;
    _notify();
    try {
      result = await repo.answerCheckpoint(day, option: option, key: _action!.key);
      _action = null;
      _actionAttempt = null;
      // The new attempts list and state come from the server.
      await _refreshQuietly();
    } catch (e) {
      final err = AppApiError.from(e);
      if (err is OfflineError) {
        offlineKept = true;
      } else if (err is MsafaraGateError) {
        error = err;
        phase = CheckpointPhase.failed;
        onGate?.call(err);
      } else if (err is ConflictError) {
        // Locked, closed or already answered (maybe on another device): show what the server has.
        _action = null;
        _actionAttempt = null;
        await _fetch();
      } else if (err is ValidationError) {
        _action = null;
        _actionAttempt = null;
        answerError = err.message;
      } else {
        answerError = err.message;
      }
    } finally {
      busy = false;
    }
    _notify();
  }

  /// After a wrong answer with tries left: back to the question.
  void tryAgain() {
    result = null;
    selected = null;
    _notify();
  }

  Future<void> _refreshQuietly() async {
    try {
      checkpoint = await repo.checkpoint(day: day);
    } catch (_) {
      // The reply of the answer is on screen; a stale list is better than an error.
    }
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
