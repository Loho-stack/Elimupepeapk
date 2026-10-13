import 'dart:math';

/// A fresh UUID v4 (random, 122 bits from a secure source), sent as the
/// `Idempotency-Key` header of award, spend and submit calls.
String newIdempotencyKey([Random? random]) {
  final r = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => r.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10
  String hex(int from, int to) => bytes
      .sublist(from, to)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}

/// One user action (Mark as done on a lesson, Send a question). It owns one
/// key for its whole life: the first try and every retry send the same key, so
/// the server runs the action once and replays the answer. A new tap on the
/// same button after the action succeeded is a new action with a new key.
class PendingAction {
  PendingAction({String? key}) : key = key ?? newIdempotencyKey();

  /// Restored from the offline outbox.
  PendingAction.restored(this.key);

  final String key;
}
