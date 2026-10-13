import 'package:shared_preferences/shared_preferences.dart';

import 'remembered_login.dart';
import 'token_store.dart';
import 'user_profile_store.dart';

/// One-time clean-up of what older versions (up to 1.2.8) stored. Runs on
/// first launch of this version, is idempotent, never throws and never logs
/// values.
///
/// - Passwords (`saved_password`, `parent_saved_password`) are deleted from
///   secure storage and from SharedPreferences. Nothing replaces them.
/// - Tokens move to the single `access_token` key.
/// - "Remember me" keeps only the Student ID, in secure storage.
/// - Display name and avatar URL move to secure storage; email, Student ID
///   copies and the avatar cache key are deleted from SharedPreferences.
class LegacyMigration {
  LegacyMigration({required SecureKv kv, required SharedPreferences prefs})
      : _kv = kv,
        _prefs = prefs;

  final SecureKv _kv;
  final SharedPreferences _prefs;

  static const doneKey = 'migration_v1_done';

  /// SharedPreferences keys that held personal data or credentials.
  static const prefsKeysToDelete = [
    'saved_password',
    'saved_email',
    'saved_student_id',
    'remember_me',
    'parent_remember_me',
    'user_name',
    'user_email',
    'loho_id',
    'profile_image_url',
    'user_avatar',
    'profile_image_cache_key',
  ];

  /// Secure-storage keys deleted outright.
  static const secureKeysToDelete = [
    'saved_password',
    'parent_saved_password',
    'parent_saved_email',
    'saved_student_id',
    'auth_email',
  ];

  Future<void> run() async {
    try {
      if (await _kv.read(doneKey) == 'true') return;
      await _migrate();
      await _kv.write(doneKey, 'true');
    } catch (_) {
      // Leave the flag unset: the next launch tries again. Never block start.
    }
  }

  Future<void> _migrate() async {
    // Opt-in remember me: keep only the Student ID.
    final remember = _prefs.getBool('remember_me') ?? false;
    final savedId = (await _read('saved_student_id')) ??
        _prefs.getString('saved_student_id');
    if (remember && savedId != null && savedId.trim().isNotEmpty) {
      await _kv.write(RememberedLogin.studentIdKey, savedId.trim().toUpperCase());
    }

    // Display data to secure storage.
    final name = _prefs.getString('user_name');
    final avatar =
        _prefs.getString('profile_image_url') ?? _prefs.getString('user_avatar');
    if (name != null && name.trim().isNotEmpty) {
      await _kv.write(UserProfileStore.nameKey, name.trim());
    }
    if (avatar != null && avatar.isNotEmpty) {
      await _kv.write(UserProfileStore.avatarKey, avatar);
    }

    // Tokens: one key.
    if ((await _read(TokenStore.accessKey)) == null) {
      final legacy = (await _read('passport_token')) ?? (await _read('auth_token'));
      if (legacy != null && legacy.isNotEmpty) {
        await _kv.write(TokenStore.accessKey, legacy);
      }
    }
    await _kv.delete('passport_token');
    await _kv.delete('auth_token');

    for (final k in secureKeysToDelete) {
      await _kv.delete(k);
    }
    for (final k in prefsKeysToDelete) {
      await _prefs.remove(k);
    }
  }

  Future<String?> _read(String key) async {
    final v = await _kv.read(key);
    return (v == null || v.isEmpty) ? null : v;
  }
}
