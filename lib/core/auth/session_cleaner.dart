import 'package:shared_preferences/shared_preferences.dart';

import 'legacy_migration.dart';
import 'remembered_login.dart';
import 'token_store.dart';

/// What logout, account deletion and an expired session wipe: everything in
/// secure storage, every SharedPreferences key except accessibility
/// preferences (they belong to the device, not the account), and the webview
/// cookies, cache and local storage (done by [clearWebview]).
///
/// The remembered Student ID survives only if the learner opted in
/// ([keepRemembered]), and the migration flag survives so old data is never
/// re-imported.
class SessionCleaner {
  SessionCleaner({
    required SecureKv kv,
    required Future<SharedPreferences> Function() prefs,
    this.clearWebview,
  })  : _kv = kv,
        _prefs = prefs;

  final SecureKv _kv;
  final Future<SharedPreferences> Function() _prefs;

  /// Clears webview cookies, HTTP cache and web storage.
  final Future<void> Function()? clearWebview;

  static const keepPrefix = 'a11y.';

  Future<void> clear({bool keepRemembered = false}) async {
    String? remembered;
    if (keepRemembered) remembered = await RememberedLogin(_kv).studentId();

    try {
      await _kv.deleteAll();
    } catch (_) {
      // Corrupted secure storage must not block logout.
    }
    try {
      await _kv.write(LegacyMigration.doneKey, 'true');
      if (remembered != null) await RememberedLogin(_kv).remember(remembered);
    } catch (_) {}

    try {
      final p = await _prefs();
      for (final k in p.getKeys().toList()) {
        if (!k.startsWith(keepPrefix)) await p.remove(k);
      }
    } catch (_) {}

    try {
      await clearWebview?.call();
    } catch (_) {}
  }
}
