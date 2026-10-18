import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/api_error.dart';
import '../../data/models/msafara_quests.dart';

/// Keeps the reading lock of one quest. It pings the server every [interval] and on a page change,
/// but only while the app is in the foreground and the screen is visible. The server is the clock: the
/// lock shown is always the last reply, never a local count.
///
/// A 429 on a ping is harmless: the ping is skipped and the last lock stays. An offline ping is skipped
/// too. Only a Msafara gate or a missing quest is reported, through [onError].
class ReadingController extends ChangeNotifier {
  ReadingController({
    required this.ping,
    required QuestLock initial,
    this.onError,
    this.isVisible,
    this.interval = const Duration(seconds: 20),
    this.pageGap = const Duration(seconds: 5),
    DateTime Function()? now,
    int? initialPage,
  })  : _lock = initial,
        _page = initialPage,
        _now = now ?? DateTime.now;

  /// Sends one ping with a fresh Idempotency-Key. [page] is 1-based, null for a lesson.
  final Future<QuestLock> Function(int? page) ping;

  /// Called for a Msafara gate or a 404 so the screen can route away.
  final void Function(AppApiError error)? onError;

  /// False when another route covers this screen. Checked before every ping.
  final bool Function()? isVisible;

  final Duration interval;

  /// The shortest time between two pings, so quick page flips stay under the server's limit.
  final Duration pageGap;
  final DateTime Function() _now;

  QuestLock _lock;
  int? _page;
  Timer? _timer;
  Timer? _later;
  DateTime? _lastPing;
  bool _foreground = true;
  bool _inFlight = false;
  bool _disposed = false;

  QuestLock get lock => _lock;
  int? get page => _page;
  bool get foreground => _foreground;

  bool get _active => !_disposed && _foreground && (isVisible?.call() ?? true);

  /// Starts the 20 second rhythm and sends the first ping now.
  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => pingNow());
    pingNow();
  }

  void setForeground(bool value) {
    if (_foreground == value) return;
    _foreground = value;
    if (value) pingNow();
  }

  /// The learner moved to [page] (1-based).
  void onPage(int page) {
    if (_page == page) return;
    _page = page;
    final last = _lastPing;
    final wait = last == null ? Duration.zero : pageGap - _now().difference(last);
    if (wait <= Duration.zero) {
      pingNow();
    } else {
      _later?.cancel();
      _later = Timer(wait, pingNow);
    }
  }

  Future<void> pingNow() async {
    if (!_active || _inFlight || _lock.unlocked) return;
    _inFlight = true;
    _lastPing = _now();
    try {
      final next = await ping(_page);
      if (_disposed) return;
      _lock = next;
      if (next.unlocked) {
        _timer?.cancel();
        _later?.cancel();
      }
      notifyListeners();
    } catch (e) {
      final err = AppApiError.from(e);
      // 429, offline and server trouble: skip this ping, keep the last lock, say nothing.
      if (err is MsafaraGateError || err is NotFoundError || err is ForbiddenError) onError?.call(err);
    } finally {
      _inFlight = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _later?.cancel();
    super.dispose();
  }
}
